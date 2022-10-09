#include "stdafx.h"
#include "lua_socket_mgr.h"
#include "lua_socket_node.h"

namespace luabus {
    static lua_socket_mgr* create_socket_mgr(int max_fd) {
        lua_socket_mgr* mgr = new lua_socket_mgr();
        if (!mgr->setup(max_fd)) {
            delete mgr;
            return nullptr;
        }
        return mgr;
    }

    luakit::lua_table open_luabus(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto lluabus = kit_state.new_table();
        lluabus.set_function("create_socket_mgr", create_socket_mgr);
        lluabus.new_enum("eproto_type",
            "rpc", eproto_type::proto_rpc,
            "head", eproto_type::proto_head,
            "text", eproto_type::proto_text,
            "common", eproto_type::proto_common
        );
        kit_state.new_class<lua_socket_mgr>(
            "wait", &lua_socket_mgr::wait,
            "listen", &lua_socket_mgr::listen,
            "connect", &lua_socket_mgr::connect,
            "map_token", &lua_socket_mgr::map_token,
            "set_master", &lua_socket_mgr::set_master
            );
        kit_state.new_class<lua_socket_node>(
            "ip", &lua_socket_node::m_ip,
            "token", &lua_socket_node::m_token,
            "call", &lua_socket_node::call,
            "close", &lua_socket_node::close,
            "call_head", &lua_socket_node::call_head,
            "call_text", &lua_socket_node::call_text,
            "call_slice", &lua_socket_node::call_slice,
            "set_nodelay", &lua_socket_node::set_nodelay,
            "set_timeout", &lua_socket_node::set_timeout,
            "forward_hash", &lua_socket_node::forward_hash,
            "forward_target", &lua_socket_node::forward_target,
            "build_session_id", &lua_socket_node::build_session_id,
            "forward_master", &lua_socket_node::forward_by_group<rpc_type::forward_master>,
            "forward_broadcast", &lua_socket_node::forward_by_group<rpc_type::forward_broadcast>
            );
        return lluabus;
    }
}

extern "C" {
    LUALIB_API int luaopen_luabus(lua_State* L) {
        auto lluabus = luabus::open_luabus(L);
        return lluabus.push_stack();
    }
}


