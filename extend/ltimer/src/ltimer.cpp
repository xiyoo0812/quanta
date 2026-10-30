#define LUA_LIB

#include "lua_kit.h"

#define TIME_NEAR_SHIFT     8
#define TIME_LEVEL_SHIFT    6
#define TIME_NEAR           (1 << TIME_NEAR_SHIFT)
#define TIME_LEVEL          (1 << TIME_LEVEL_SHIFT)
#define TIME_NEAR_MASK      (TIME_NEAR-1)
#define TIME_LEVEL_MASK     (TIME_LEVEL-1)

namespace ltimer {

    struct timer_node {
        size_t expire = 0;
        size_t period = 0;
        size_t timer_id = 0;
        int64_t times = 0;
        bool invalid = false;
    };

    using integer_vector = std::vector<size_t>;
    using timer_node_spr = std::shared_ptr<timer_node>;
    using sched_map = std::unordered_map<size_t, timer_node_spr>;
    using timer_vector = std::vector<timer_node_spr>;

    class lua_timer {
    public:
        void remove(size_t timer_id);
        integer_vector update(size_t elapse);
        void change(size_t timer_id, size_t period);
        void insert(size_t timer_id, size_t escape, size_t period, int64_t times);

    protected:
        void shift();
        void add_node(timer_node_spr node);
        void execute(integer_vector& result);
        void move_list(uint32_t level, uint32_t idx);

    protected:
        size_t time = 0;
        sched_map handles;
        timer_vector nears[TIME_NEAR];
        timer_vector t[4][TIME_LEVEL];
    };

    void lua_timer::change(size_t timer_id, size_t period) {
        if (auto it = handles.find(timer_id); it != handles.end()) {
            auto old = it->second;
            if (old->times >= 0) return;
            old->invalid = true;
            handles.erase(it);
            auto node = std::make_shared<timer_node>(time + period, period, timer_id, -1);
            handles.emplace(timer_id, node);
            add_node(node);
        }
    }

    void lua_timer::insert(size_t timer_id, size_t escape, size_t period, int64_t times) {
        remove(timer_id);
        auto node = std::make_shared<timer_node>(time + escape, period, timer_id, times);
        if (times != 1 && times != 0) {
            handles.emplace(timer_id, node);
        }
        add_node(node);
    }

    void lua_timer::remove(size_t timer_id) {
        if (auto it = handles.find(timer_id); it != handles.end()) {
            it->second->invalid = true;
            handles.erase(it);
        }
    }

    void lua_timer::add_node(timer_node_spr node) {
        size_t expire = node->expire;
        if ((expire | TIME_NEAR_MASK) == (time | TIME_NEAR_MASK)) {
            nears[expire & TIME_NEAR_MASK].push_back(node);
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

    void lua_timer::move_list(uint32_t level, uint32_t idx) {
        timer_vector& list = t[level][idx];
        for (auto node : list) {
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
        size_t stime = ct >> TIME_NEAR_SHIFT;
        while ((ct & (mask - 1)) == 0) {
            if (auto idx = stime & TIME_LEVEL_MASK; idx != 0) {
                move_list(i, idx);
                break;
            }
            mask <<= TIME_LEVEL_SHIFT;
            stime >>= TIME_LEVEL_SHIFT;
            ++i;
        }
    }

    void lua_timer::execute(integer_vector& result) {
        uint32_t idx = time & TIME_NEAR_MASK;
        timer_vector expired;
        expired.swap(nears[idx]);
        for (auto node : expired) {
            if (node->invalid) continue;
            if (node->times > 0) node->times--;
            result.push_back(node->timer_id);
            result.push_back(node->times == 0 ? 0 : 1);
            if (node->times != 0) {
                node->expire += node->period;
                add_node(node);
            } else {
                remove(node->timer_id);
            }
        }
    }

    integer_vector lua_timer::update(size_t elapse) {
        integer_vector result;
        for (size_t i = 0; i < elapse; i++) {
            execute(result);
            shift();
        }
        return result;
    }

    thread_local lua_timer thread_timer;

    static void timer_insert(size_t timer_id, size_t escape, size_t period, int64_t times) {
        thread_timer.insert(timer_id, escape, period, times == 0 ? 1 : times);
    }

    static integer_vector timer_update(size_t elapse) {
        return thread_timer.update(elapse);
    }

    static void timer_remove(size_t timer_id) {
        thread_timer.remove(timer_id);
    }

    static void timer_change(size_t timer_id, size_t period) {
        thread_timer.change(timer_id, period);
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
        luatimer.set_function("remove", timer_remove);
        luatimer.set_function("change", timer_change);
        luatimer.set_function("now", []() { return luakit::now(); });
        luatimer.set_function("clock", []() { return luakit::steady(); });
        luatimer.set_function("now_ms", []() { return luakit::now_ms(); });
        luatimer.set_function("now_ns", []() { return luakit::now_ns(); });
        luatimer.set_function("now_cs", []() { return luakit::now_cs(); });
        luatimer.set_function("clock_ms", []() { return luakit::steady_ms(); });
        luatimer.set_function("sleep", [](size_t ms) { return luakit::sleep(ms); });
        return luatimer;
    }
}

extern "C" {
    LUALIB_API int luaopen_ltimer(lua_State* L) {
        auto luatimer = ltimer::open_ltimer(L);
        return luatimer.push_stack();
    }
}
