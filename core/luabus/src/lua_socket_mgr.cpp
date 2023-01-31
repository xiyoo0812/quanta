#include "stdafx.h"
#include "lua_socket_mgr.h"
#include "lua_socket_node.h"

bool lua_socket_mgr::setup(int max_fd) {
    m_mgr = std::make_shared<socket_mgr>();
    m_router = std::make_shared<socket_router>(m_mgr);
    return m_mgr->setup(max_fd);
}

luakit::variadic_results lua_socket_mgr::listen(lua_State* L, const char* ip, int port) {
    luakit::kit_state kit_state(L);
    if (ip == nullptr || port <= 0) {
        return kit_state.as_return(nullptr, "invalid param");
    }

    std::string err;
    eproto_type proto_type = (eproto_type)luaL_optinteger(L, 3, 0);
    int token = m_mgr->listen(err, ip, port, proto_type);
    if (token == 0) {
        return kit_state.as_return(nullptr, err);
    }

    auto listener = new lua_socket_node(token, L, m_mgr, m_router, true, proto_type);
    return kit_state.as_return(listener, "ok");
}

luakit::variadic_results lua_socket_mgr::connect(lua_State* L, const char* ip, const char* port, int timeout) {
    luakit::kit_state kit_state(L);
    if (ip == nullptr || port == nullptr) {
        return kit_state.as_return(nullptr, "invalid param");
    }

    std::string err;
    eproto_type proto_type = (eproto_type)luaL_optinteger(L, 4, 0);
    int token = m_mgr->connect(err, ip, port, timeout, proto_type);
    if (token == 0) {
        return kit_state.as_return(nullptr, err);
    }

    auto stream = new lua_socket_node(token, L, m_mgr, m_router, false, proto_type);
    return kit_state.as_return(stream, "ok");
}

uint32_t lua_socket_mgr::map_token(uint32_t node_id, uint32_t token) {
    return m_router->map_token(node_id, token);
}
