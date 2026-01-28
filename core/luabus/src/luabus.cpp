#include "stdafx.h"
#include "socket_dns.h"
#include "socket_udp.h"
#include "socket_tcp.h"
#include "socket_ping.h"
#include "socket_region.h"
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

    static socket_udp* create_udp(bool noblock, bool broadcast, bool reuse) {
        socket_udp* udp = new socket_udp();
        if (!udp->setup(noblock, broadcast, reuse)) {
            delete udp;
            return nullptr;
        }
        return udp;
    }

    static socket_tcp* create_tcp(bool noblock, bool reuse) {
        socket_tcp* tcp = new socket_tcp();
        if (!tcp->setup(noblock, reuse)) {
            delete tcp;
            return nullptr;
        }
        return tcp;
    }

    static socket_region* create_region(cpchar dbpath) {
        socket_region* region = new socket_region();
        if (!region->load(dbpath)) {
            delete region;
            return nullptr;
        }
        return region;
    }

    luakit::lua_table open_luabus(lua_State* L) {
        luakit::kit_state kit_state(L, true);
        auto lluabus = kit_state.new_table("luabus");
        lluabus.set_function("udp", create_udp);
        lluabus.set_function("tcp", create_tcp);
        lluabus.set_function("host", gethostip);
        lluabus.set_function("ping", socket_ping);
        lluabus.set_function("dns", gethostbydomain);
        lluabus.set_function("ipconfig", get_ipconfig);
        lluabus.set_function("ip2region", create_region);
        lluabus.set_function("derive_port", derive_port);
        lluabus.set_function("create_socket_mgr", create_socket_mgr);
        lluabus.new_enum("proto_type",
            "PB", PROTO_PB,
            "RPC", PROTO_RPC,
            "TEXT", PROTO_TEXT
        );
        lluabus.new_enum("proto_flag",
            "RES", FLAG_RES,
            "REQ", FLAG_REQ,
            "ZIP", FLAG_ZIP,
            "CRYPT", FLAG_CRYPT,
            "UNREACH", FLAG_UNREACH,
            "BAD", FLAG_BAD
        );
        lluabus.new_enum("relay_type",
            "SELF", RELAY_SELF,
            "GROUP", RELAY_GROUP,
            "CLIENT", RELAY_CLIENT,
            "SERVICE", RELAY_SERVICE,
            "BROADCAST", RELAY_BROADCAST
        );
        kit_state.new_class<socket_udp>(
            "send", &socket_udp::send,
            "recv", &socket_udp::recv,
            "bind", &socket_udp::bind,
            "close", &socket_udp::close,
            "add_group", &socket_udp::add_group,
            "set_buff_size", &socket_udp::set_buff_size
        );
        kit_state.new_class<socket_region>(
            "search", &socket_region::search
        );
        kit_state.new_class<socket_tcp>(
            "send", &socket_tcp::send,
            "recv", &socket_tcp::recv,
            "close", &socket_tcp::close,
            "accept", &socket_tcp::accept,
            "listen", &socket_tcp::listen,
            "invalid", &socket_tcp::invalid,
            "connect", &socket_tcp::connect,
            "set_buff_size", &socket_udp::set_buff_size
        );
        kit_state.new_class<lua_socket_mgr>(
            "wait", &lua_socket_mgr::wait,
            "listen", &lua_socket_mgr::listen,
            "connect", &lua_socket_mgr::connect,
            "broadcast", &lua_socket_mgr::broadcast,
            "map_group", &lua_socket_mgr::map_group,
            "broadgroup", &lua_socket_mgr::broadgroup,
            "map_router", &lua_socket_mgr::map_router,
            "map_client", &lua_socket_mgr::map_client,
            "map_server", &lua_socket_mgr::map_server,
            "query_servers", &lua_socket_mgr::query_servers,
            "check_service", &lua_socket_mgr::check_service,
            "get_sendbuf_size", &lua_socket_mgr::get_sendbuf_size,
            "get_recvbuf_size", &lua_socket_mgr::get_recvbuf_size,
            "set_relay_service", &lua_socket_mgr::set_relay_service
        );
        kit_state.new_class<lua_socket_node>(
            "ip", &lua_socket_node::m_ip,
            "token", &lua_socket_node::m_token,
            "node_id", &lua_socket_node::m_node_id,
            "close", &lua_socket_node::close,
            "call_pb", &lua_socket_node::call_pb,
            "call_text", &lua_socket_node::call_text,
            "set_codec", &lua_socket_node::set_codec,
            "set_nodelay", &lua_socket_node::set_nodelay,
            "set_timeout", &lua_socket_node::set_timeout,
            "get_route_count", &lua_socket_node::get_route_count,
            "forward_self", &lua_socket_node::forward_by_method<FORWARD_SELF>,
            "forward_hash", &lua_socket_node::forward_by_method<FORWARD_HASH>,
            "forward_relay", &lua_socket_node::forward_by_method<FORWARD_RELAY>,
            "forward_target", &lua_socket_node::forward_by_method<FORWARD_TARGET>,
            "forward_master", &lua_socket_node::forward_by_method<FORWARD_MASTER>,
            "forward_broadcast", &lua_socket_node::forward_by_method<FORWARD_BROADCAST>
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


