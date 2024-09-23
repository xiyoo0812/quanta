#define LUA_LIB

#include <list>
#include "lua_kit.h"

#define TIME_NEAR_SHIFT     8
#define TIME_LEVEL_SHIFT    6
#define TIME_NEAR           (1 << TIME_NEAR_SHIFT)
#define TIME_LEVEL          (1 << TIME_LEVEL_SHIFT)
#define TIME_NEAR_MASK      (TIME_NEAR-1)
#define TIME_LEVEL_MASK     (TIME_LEVEL-1)

namespace ltimer {

    struct timer_node {
        size_t expire;
        uint64_t timer_id;
    };

    using timer_list = std::list<timer_node>;
    using integer_vector = std::vector<uint64_t>;

    class lua_timer {
    public:
        integer_vector update(size_t elapse);
        void insert(uint64_t timer_id, size_t escape);

    protected:
        void shift();
        void add_node(timer_node& node);
        void execute(integer_vector& timers);
        void move_list(uint32_t level, uint32_t idx);

    protected:
        size_t time = 0;
        timer_list near[TIME_NEAR];
        timer_list t[4][TIME_LEVEL];
    };

    void lua_timer::add_node(timer_node& node) {
        size_t expire = node.expire;
        if ((expire | TIME_NEAR_MASK) == (time | TIME_NEAR_MASK)) {
            near[expire & TIME_NEAR_MASK].push_back(node);
            return;
        }
        uint32_t i;
        uint32_t mask = TIME_NEAR << TIME_LEVEL_SHIFT;
        for (i = 0; i < 3; i++) {
            if ((expire | (mask - 1)) == (time | (mask - 1))) {
                break;
            }
            mask <<= TIME_LEVEL_SHIFT;
        }
        t[i][((expire >> (TIME_NEAR_SHIFT + i * TIME_LEVEL_SHIFT)) & TIME_LEVEL_MASK)].push_back(node);
    }

    void lua_timer::insert(uint64_t timer_id, size_t escape) {
        timer_node node{ time + escape, timer_id };
        add_node(node);
    }

    void lua_timer::move_list(uint32_t level, uint32_t idx) {
        timer_list& list = t[level][idx];
        for (auto node : t[level][idx]) {
            add_node(node);
        }
        list.clear();
    }

    void lua_timer::shift() {
        size_t ct = ++time;
        if (ct == 0) {
            move_list(3, 0);
            return;
        }
        uint32_t i = 0;
        int mask = TIME_NEAR;
        size_t time = ct >> TIME_NEAR_SHIFT;
        while ((ct & (mask - 1)) == 0) {
            uint32_t idx = time & TIME_LEVEL_MASK;
            if (idx != 0) {
                move_list(i, idx);
                break;
            }
            mask <<= TIME_LEVEL_SHIFT;
            time >>= TIME_LEVEL_SHIFT;
            ++i;
        }
    }

    void lua_timer::execute(integer_vector& timers) {
        uint32_t idx = time & TIME_NEAR_MASK;
        for (auto node : near[idx]) {
            timers.push_back(node.timer_id);
        }
        near[idx].clear();
    }

    integer_vector lua_timer::update(size_t elapse) {
        integer_vector timers;
        execute(timers);
        for (size_t i = 0; i < elapse; i++) {
            shift();
            execute(timers);
        }
        return timers;
    }

    thread_local lua_timer thread_timer;
    static void timer_insert(uint64_t timer_id, size_t escape){
        thread_timer.insert(timer_id, escape);
    }

    static integer_vector timer_update(size_t elapse) {
        return thread_timer.update(elapse);
    }

    static int timer_time(lua_State* L) {
        return luakit::variadic_return(L, luakit::now_ms(), luakit::steady_ms());
    }

    luakit::lua_table open_ltimer(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto luatimer = kit_state.new_table("timer");
        luatimer.set_function("time", timer_time);
        luatimer.set_function("insert", timer_insert);
        luatimer.set_function("update", timer_update);
        luatimer.set_function("now", []() { return luakit::now(); });
        luatimer.set_function("clock", []() { return luakit::steady(); });
        luatimer.set_function("now_ms", []() { return luakit::now_ms(); });
        luatimer.set_function("now_ns", []() { return luakit::now_ns(); });
        luatimer.set_function("clock_ms", []() { return luakit::steady_ms(); });
        luatimer.set_function("sleep", [](uint64_t ms) { return luakit::sleep(ms); });
        return luatimer;
    }
}

extern "C" {
    LUALIB_API int luaopen_ltimer(lua_State* L) {
        auto luatimer = ltimer::open_ltimer(L);
        return luatimer.push_stack();
    }
}
