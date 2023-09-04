#include "stdafx.h"
#include "socket_dns.h"
#include "socket_udp.h"
#include "socket_tcp.h"
#include "lua_socket_mgr.h"
#include "lua_socket_node.h"

namespace luabus {
    static lua_socket_mgr* create_socket_mgr(lua_State* L, int max_fd) {
        lua_socket_mgr* mgr = new lua_socket_mgr();
        if (!mgr->setup(L, max_fd)) {
            delete mgr;
            return nullptr;
        }
        return mgr;
    }

    static socket_udp* create_udp() {
        socket_udp* udp = new socket_udp();
        if (!udp->setup()) {
            delete udp;
            return nullptr;
        }
        return udp;
    }

    static socket_tcp* create_tcp() {
        socket_tcp* tcp = new socket_tcp();
        if (!tcp->setup()) {
            delete tcp;
            return nullptr;
        }
        return tcp;
    }

    luakit::lua_table open_luabus(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto lluabus = kit_state.new_table();
        
        lluabus.set_function("udp", create_udp);
        lluabus.set_function("tcp", create_tcp);
        lluabus.set_function("dns", gethostbydomain);
        lluabus.set_function("create_socket_mgr", create_socket_mgr);
        lluabus.new_enum("eproto_type",
            "rpc", eproto_type::proto_rpc,
            "head", eproto_type::proto_head,
            "text", eproto_type::proto_text,
            "mongo", eproto_type::proto_mongo,
            "mysql", eproto_type::proto_mysql
        );
        kit_state.new_class<socket_udp>(
            "send", &socket_udp::send,
            "recv", &socket_udp::recv,
            "close", &socket_udp::close,
            "listen", &socket_udp::listen
            );
        kit_state.new_class<socket_tcp>(
            "send", &socket_tcp::send,
            "recv", &socket_tcp::recv,
            "close", &socket_tcp::close,
            "accept", &socket_tcp::accept,
            "listen", &socket_tcp::listen,
            "invalid", &socket_tcp::invalid,
            "connect", &socket_tcp::connect
            );
        kit_state.new_class<lua_socket_mgr>(
            "wait", &lua_socket_mgr::wait,
            "listen", &lua_socket_mgr::listen,
            "connect", &lua_socket_mgr::connect,
            "map_token", &lua_socket_mgr::map_token,
            "get_sendbuf_size", &lua_socket_mgr::get_sendbuf_size,
            "get_recvbuf_size", &lua_socket_mgr::get_recvbuf_size
            );
        kit_state.new_class<lua_socket_node>(
            "ip", &lua_socket_node::m_ip,
            "token", &lua_socket_node::m_token,
            "call", &lua_socket_node::call,
            "close", &lua_socket_node::close,
            "set_codec", &lua_socket_node::set_codec,
            "call_head", &lua_socket_node::call_head,
            "call_data", &lua_socket_node::call_data,
            "set_nodelay", &lua_socket_node::set_nodelay,
            "set_timeout", &lua_socket_node::set_timeout,
            "forward_hash", &lua_socket_node::forward_hash,
            "transfer_call", &lua_socket_node::transfer_call,
            "transfer_hash", &lua_socket_node::transfer_hash,
            "forward_target", &lua_socket_node::forward_target,
            "get_route_count", &lua_socket_node::get_route_count,
            "build_session_id", &lua_socket_node::build_session_id,
            "forward_transfer", &lua_socket_node::forward_transfer,
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


