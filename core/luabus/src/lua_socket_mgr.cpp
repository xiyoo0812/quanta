#include "stdafx.h"
#include "lua_socket_mgr.h"

bool lua_socket_mgr::setup(lua_State* L, int max_fd) {
    m_lvm = L;
    m_codec.set_buff(&m_buf);
    m_mgr = std::make_shared<socket_mgr>();
    m_relay = std::make_shared<socket_relay>(m_mgr);
    m_router = std::make_shared<socket_router>(m_mgr, &m_codec);
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
    proto_type ptype = (proto_type)luaL_optinteger(L, 3, (int)PROTO_RPC);
    auto listener = new lua_socket_node(token, m_lvm, m_mgr, ptype);
    if (ptype == PROTO_RPC) {
        listener->set_codec(&m_codec);
    }
    listener->set_relay(m_relay);
    listener->set_router(m_router);
    return luakit::variadic_return(L, listener, "ok");
}

int lua_socket_mgr::connect(lua_State* L, const char* ip, int port, int timeout) {
    if (ip == nullptr) {
        return luakit::variadic_return(L, nullptr, "invalid param");
    }
    std::string err;
    int token = m_mgr->connect(err, ip, port, timeout);
    if (token == 0) {
        return luakit::variadic_return(L, nullptr, err);
    }
    proto_type ptype = (proto_type)luaL_optinteger(L, 4, (int)PROTO_RPC);
    auto socket_node = new lua_socket_node(token, m_lvm, m_mgr, ptype);
    if (ptype == PROTO_RPC) {
        socket_node->set_codec(&m_codec);
    }
    return luakit::variadic_return(L, socket_node, "ok");
}

int lua_socket_mgr::get_sendbuf_size(uint32_t token) {
    return m_mgr->get_recvbuf_size(token);
}

int lua_socket_mgr::get_recvbuf_size(uint32_t token) {
    return m_mgr->get_recvbuf_size(token);
}

void lua_socket_mgr::set_codec(uint32_t token, codec_base* codec) {
    return m_mgr->set_codec(token, codec);
}

int lua_socket_mgr::map_router(uint32_t node_id, int32_t token) {
    return m_router->map_router(node_id, token);
}

void lua_socket_mgr::map_client(uint32_t client_id, int32_t token) {
    m_relay->map_client(client_id, token);
}

std::vector<uint32_t> lua_socket_mgr::query_servers(uint32_t client_id){
    return m_relay->query_servers(client_id);
}

void lua_socket_mgr::map_group(uint32_t group_id, uint32_t client_id, bool enter) {
    m_relay->map_group(group_id, client_id, enter);
}

void lua_socket_mgr::map_server(uint32_t client_id, uint32_t server_id, uint32_t token) {
    m_relay->map_server(client_id, server_id, token);
}

bool lua_socket_mgr::check_service(uint32_t server_id, uint32_t client_id){
    return m_relay->check_service(server_id, client_id);
}

void lua_socket_mgr::set_relay_service(uint8_t id) {
    m_relay->set_relay_service(id);
}

int lua_socket_mgr::broadcast(lua_State* L, codec_base* codec, uint32_t kind) {
    size_t data_len = 0;
    char* data = (char*)codec->encode(L, 3, &data_len);
    if (data_len <= USHRT_MAX) {
        //发送数据
        m_mgr->broadcast(kind, data, data_len);
        lua_pushboolean(L, true);
        return 1;
    }
    lua_pushboolean(L, false);
    return 1;
}

int lua_socket_mgr::broadgroup(lua_State* L, codec_base* codec) {
    size_t data_len = 0;
    auto groups = lua_to_native<std::vector<uint32_t>>(L, 2);
    char* data = (char*)codec->encode(L, 3, &data_len);
    if (data_len <= USHRT_MAX) {
        //发送数据
        m_mgr->broadgroup(groups, data, data_len);
        lua_pushboolean(L, true);
        return 1;
    }
    lua_pushboolean(L, false);
    return 1;
}
