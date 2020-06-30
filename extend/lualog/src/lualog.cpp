#include "logger.h"
#include "lua.hpp"

#ifdef _MSC_VER
#define LLOG_API _declspec(dllexport)
#else
#define LLOG_API 
#endif

int init(lua_State* L)
{
	size_t max_line = 10000;
	rolling_type roll_type = rolling_type::HOURLY;
	auto service = log_service::default_instance();
	std::string log_path = lua_tostring(L, 1);
	std::string log_name = lua_tostring(L, 2);
	if (lua_gettop(L) > 3)
	{
		roll_type = (rolling_type)lua_tointeger(L, 3);
		max_line = lua_tointeger(L, 4);
	}
	service->start(log_path, log_name, roll_type, max_line);
	if (lua_gettop(L) > 4)
	{
		bool is_daemon = lua_toboolean(L, 5);
		service->daemon(is_daemon);
	}
	lua_pushboolean(L, true);
	return 1;
}

int close(lua_State* L)
{
	auto service = log_service::default_instance();
	service->stop();
	return 0;
}

int filter(lua_State* L)
{
	auto log_filter = log_service::default_instance()->get_filter();
	log_filter->filter((log_level)lua_tointeger(L, 1), lua_toboolean(L, 2));
	return 0;
}

int daemon(lua_State* L)
{
	auto service = log_service::default_instance();
	service->daemon(lua_toboolean(L, 1));
	return 0;
}

int is_filter(lua_State* L)
{
	auto log_filter = log_service::default_instance()->get_filter();
	lua_pushboolean(L, log_filter->is_filter((log_level)lua_tointeger(L, 1)));
	return 1;
}

int add_dest(lua_State* L)
{
	size_t max_line = 10000;
	rolling_type roll_type = rolling_type::HOURLY;
	auto service = log_service::default_instance();
	std::string log_path = lua_tostring(L, 1);
	std::string log_name = lua_tostring(L, 2);
	if (lua_gettop(L) > 3)
	{
		roll_type = (rolling_type)lua_tointeger(L, 3);
		max_line = lua_tointeger(L, 4);
	}
	bool res = service->add_dest(log_path, log_name, roll_type, max_line);
	lua_pushboolean(L, res);
	return 1;
}

int del_dest(lua_State* L)
{
	auto service = log_service::default_instance();
	std::string log_name = lua_tostring(L, 1);
	service->del_dest(log_name);
	return 0;
}

int del_lvl_dest(lua_State* L)
{
	auto service = log_service::default_instance();
	log_level log_lvl = (log_level)lua_tointeger(L, 1);
	service->del_lvl_dest(log_lvl);
	return 0;
}

int add_lvl_dest(lua_State* L)
{
	size_t max_line = 10000;
	rolling_type roll_type = rolling_type::HOURLY;
	auto service = log_service::default_instance();
	std::string log_path = lua_tostring(L, 1);
	std::string log_name = lua_tostring(L, 2);
	log_level log_lvl = (log_level)lua_tointeger(L, 3);
	if (lua_gettop(L) > 4)
	{
		roll_type = (rolling_type)lua_tointeger(L, 4);
		max_line = lua_tointeger(L, 5);
	}
	bool res = service->add_level_dest(log_path, log_name, log_lvl, roll_type, max_line);
	lua_pushboolean(L, res);
	return 1;
}

template<log_level level>
int log(lua_State* L)
{
	int line = 0;
	std::string source = "";
	std::string log_msg = lua_tostring(L, 1);
	if (lua_gettop(L) > 2)
	{
		source = lua_tostring(L, 2);
		line = (int)lua_tointeger(L, 3);
	}
	auto service = log_service::default_instance();
	log_ctx<level> ctx(service, source, line);
	ctx << log_msg;
	return 0;
}

void lua_register_function(lua_State* L, const char name[], lua_CFunction func)
{
	lua_pushcfunction(L, func);
	lua_setfield(L, -2, name);
}

extern "C" LLOG_API int luaopen_lualog(lua_State* L)
{
	lua_newtable(L);
	lua_register_function(L, "init", init);
	lua_register_function(L, "close", close);
	lua_register_function(L, "filter", filter);
	lua_register_function(L, "daemon", daemon);
	lua_register_function(L, "is_filter", is_filter);
	lua_register_function(L, "add_dest", add_dest);
	lua_register_function(L, "del_dest", del_dest);
	lua_register_function(L, "add_lvl_dest", add_lvl_dest);
	lua_register_function(L, "del_lvl_dest", del_lvl_dest);
	lua_register_function(L, "debug", log<log_level::LOG_LEVEL_DEBUG>);
	lua_register_function(L, "info", log<log_level::LOG_LEVEL_INFO>);
	lua_register_function(L, "warn", log<log_level::LOG_LEVEL_WARN>);
	lua_register_function(L, "dump", log<log_level::LOG_LEVEL_DUMP>);
	lua_register_function(L, "error", log<log_level::LOG_LEVEL_ERROR>);
	return 1;
}