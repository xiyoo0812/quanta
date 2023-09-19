#include "stdafx.h"
#include "lua_socket_mgr.h"
#include "lua_socket_node.h"

bool lua_socket_mgr::setup(lua_State* L, int max_fd) {
    m_lvm = L;
    m_mgr = std::make_shared<socket_mgr>();
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

    eproto_type proto_type = (eproto_type)luaL_optinteger(L, 3, (int)eproto_type::proto_rpc);
    auto listener = new lua_socket_node(token, L, m_mgr, m_router, proto_type);
    if (proto_type == eproto_type::proto_rpc) {
        listener->create_codec();
    }
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

    eproto_type proto_type = (eproto_type)luaL_optinteger(L, 4, (int)eproto_type::proto_rpc);
    auto socket_node = new lua_socket_node(token, L, m_mgr, m_router, proto_type);
    if (proto_type == eproto_type::proto_rpc) {
        socket_node->create_codec();
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

int lua_socket_mgr::map_token(uint32_t node_id, uint32_t token) {
    return m_router->map_token(node_id, token);
}

int lua_socket_mgr::broadcast(lua_State* L, codec_base* codec, uint32_t kind) {
    size_t data_len = 0;
    char* data = (char*)codec->encode(L, 3, &data_len);
    socket_header* header = (socket_header*)data;
    if (data_len <= USHRT_MAX) {
        //组装数据
        header->len = data_len;
        header->session_id = 0;
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
    std::vector<uint32_t> groups;
    if (!lua_to_native(L, 2, groups)) {
        lua_pushboolean(L, false);
        return 1;
    }
    char* data = (char*)codec->encode(L, 3, &data_len);
    socket_header* header = (socket_header*)data;
    if (data_len <= USHRT_MAX) {
        //组装数据
        header->len = data_len;
        header->session_id = 0;
        //发送数据
        m_mgr->broadgroup(groups, data, data_len);
        lua_pushboolean(L, true);
        return 1;
    }
    lua_pushboolean(L, false);
    return 1;
}
