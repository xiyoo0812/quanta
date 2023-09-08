#include "stdafx.h"
#include "lua_socket_mgr.h"
#include "lua_socket_node.h"

bool lua_socket_mgr::setup(lua_State* L, int max_fd) {
    m_lvm = L;
    m_mgr = std::make_shared<socket_mgr>();
    m_codec = std::make_shared<luacodec>();
    m_router = std::make_shared<socket_router>(m_mgr);
    return m_mgr->setup(max_fd);
}

int lua_socket_mgr::listen(lua_State* L, const char* ip, int port) {
    if (ip == nullptr || port <= 0) {
        return luakit::variadic_return(L, nullptr, "invalid param");
    }

    std::string err;
    int token = m_mgr->listen(err, ip, port);
    if (token == 0) {
        return luakit::variadic_return(L, nullptr, err);
    }

    auto listener = new lua_socket_node(token, L, m_mgr, m_router, true);
    listener->set_codec(m_codec.get());
    return luakit::variadic_return(L, listener, "ok");
}

int lua_socket_mgr::connect(lua_State* L, const char* ip, const char* port, int timeout) {
    if (ip == nullptr || port == nullptr) {
        return luakit::variadic_return(L, nullptr, "invalid param");
    }

    std::string err;
    int token = m_mgr->connect(err, ip, port, timeout);
    if (token == 0) {
        return luakit::variadic_return(L, nullptr, err);
    }

    auto socket_node = new lua_socket_node(token, L, m_mgr, m_router, false);
    socket_node->set_codec(m_codec.get());
    return luakit::variadic_return(L, socket_node, "ok");
}

int lua_socket_mgr::get_sendbuf_size(uint32_t token) {
    return m_mgr->get_recvbuf_size(token);
}

int lua_socket_mgr::get_recvbuf_size(uint32_t token) {
    return m_mgr->get_recvbuf_size(token);
}

void lua_socket_mgr::set_proto_type(uint32_t token, eproto_type type) {
    return m_mgr->set_proto_type(token, type);
}

int lua_socket_mgr::map_token(uint32_t node_id, uint32_t token) {
    return m_router->map_token(node_id, token);
}
