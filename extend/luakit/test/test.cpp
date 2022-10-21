#include "lua_kit.h"
#include <array>
#include <unordered_map>

using namespace std;

enum class log_level {
    LOG_LEVEL_DEBUG = 1,
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_DUMP,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_FATAL,
};

class luatest {
public:
    int a = 1;
    int b = 2;
    void fn1() {
        printf("luatest::fn1\n");
    }

    int fn2(int i) {
        b = i;
        printf("luatest::fn2: %d\n", b);
        return a + b;
    }
};

luakit::variadic_results test_lua_func(lua_State* L, int a, int b) {
    auto kit_state = luakit::kit_state(L);
    printf("call test_lua_func: %d, %d\n", a, b);
    return kit_state.as_return(true, a + b, "sssss");
}

int main()
{
    auto kit_state = luakit::kit_state();

    kit_state.set<uint32_t>("test_value", 12345);

    uint32_t lv = 100;
    std::function<void(int k)> func = [&](int k) {
        lv = k;
    };
    kit_state.set_function("test_func", func);

    kit_state.set_function("test_lua_func", test_lua_func);

    uint32_t lv2 = 100;
    kit_state.set_function("test_func2", [&](int k) {
        lv2 = k;
        return k;
        });

    uint32_t lv3 = 100;
    auto tab = kit_state.new_table("testtb");
    tab.set("key", 3);
    tab.set_function("tbf", [&](int k) {
        lv3 = k;
        return k;
        });
    printf("test table: %d\n", tab.get<uint32_t, string>("key"));

    auto enu = kit_state.new_enum("LOG_LEVEL",
        "INFO", log_level::LOG_LEVEL_INFO,
        "WARN", log_level::LOG_LEVEL_WARN,
        "DUMP", log_level::LOG_LEVEL_DUMP,
        "DEBUG", log_level::LOG_LEVEL_DEBUG,
        "ERROR", log_level::LOG_LEVEL_ERROR,
        "FATAL", log_level::LOG_LEVEL_FATAL
    );
    printf("test enum: %d\n", enu.get<uint32_t, string>("WARN"));

    kit_state.new_class<luatest>(
        "a", &luatest::a,
        "b", &luatest::b,
        "fn1", &luatest::fn1,
        "fn2", &luatest::fn2
        );

    kit_state.set("ltest", new luatest());

    auto lvec = std::array<int, 3> {1, 2, 3};
    kit_state.set("lvec", lvec);

    auto lmap = unordered_map<int, string>{ {1, "s"},{2, "a"}, {3, "v"}};
    kit_state.set("lmap", lmap);

    kit_state.run_file("test.lua", [](std::string err) {
        printf("run_file failed: %s\n", err.c_str());
        });

    printf("view test_func: %d\n", lv);
    printf("view test_func2: %d\n", lv2);
    printf("view tb_func: %d\n", lv3);

    uint32_t tv = kit_state.get<uint32_t>("test_value");
    printf("view test_value: %d\n", tv);

    int ir;
    kit_state.call("lua_gcall", nullptr, std::tie(ir), 1, 2, "lua string");
    printf("call lua_gcall: %d\n", ir);
    
    int ar, br;
    tab.call("lua_tcall", nullptr, std::tie(ar, br), 1, 2, "lua string");
    printf("call lua_tcall: %d, %d\n", ar, br);

    bool r = kit_state.table_call("testtb", "lua_tcall2", nullptr, std::tie(ar, br), 3, 4, "lua string");
    printf("call lua_tcall2: %d, %d\n", ar, br);

    kit_state.run_script("print(test_value)", [](std::string err) {
        printf("run_script failed: %s\n", err.c_str());
        });

    list<int> lvec2 = kit_state.get<luakit::reference>("lvec2").to_sequence<list<int>, int>();
    for (auto it : lvec2) {
        printf("view vector: %d\n", it);
    }

    getchar();
    return 0;
}