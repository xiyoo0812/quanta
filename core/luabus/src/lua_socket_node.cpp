#include "stdafx.h"
#include "lua_socket_node.h"

lua_socket_node::lua_socket_node(uint32_t token, lua_State* L, std::shared_ptr<socket_mgr>& mgr, std::shared_ptr<socket_router>& router
    , bool blisten, eproto_type proto_type) : m_token(token), m_mgr(mgr), m_router(router), m_proto_type(proto_type) {
    m_stoken = (m_token & 0xffff) << 16;
    m_luakit = std::make_shared<luakit::kit_state>(L);
    m_mgr->get_remote_ip(m_token, m_ip);
    if (blisten) {
        m_mgr->set_accept_callback(token, [=](uint32_t steam_token, eproto_type proto_type) {
            auto node = new lua_socket_node(steam_token, m_luakit->L(), m_mgr, m_router, false, proto_type);
            node->set_codec(m_codec);
            m_luakit->object_call(this, "on_accept", nullptr, std::tie(), node);
        });
    }
    m_mgr->set_connect_callback(token, [=](bool ok, const char* reason) {
        m_luakit->object_call(this, "on_connect", nullptr, std::tie(), ok ? "ok" : reason);
    });

    m_mgr->set_error_callback(token, [=](const char* err) {
        auto token = m_token;
        m_token = 0;
        m_luakit->object_call(this, "on_error", nullptr, std::tie(), token, err);
    });

    m_mgr->set_package_callback(token, [=](slice* data){
        return on_recv(data);
    });
}

lua_socket_node::~lua_socket_node() {
    close();
}

void lua_socket_node::close() {
    if (m_token != 0) {
        m_mgr->close(m_token);
        m_token = 0;
    }
}

int lua_socket_node::call_data(lua_State* L) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 1, &data_len);
    if (data_len > SOCKET_PACKET_MAX) return 0;
    m_mgr->send(m_token, data, data_len);
    lua_pushinteger(L, data_len);
    return 1;
}

int lua_socket_node::call_head(uint16_t cmd_id, uint8_t flag, uint8_t type, uint8_t crc8, uint32_t session_id, const char* data, uint32_t data_len) {
    size_t length = data_len + sizeof(socket_header);
    if (length <= USHRT_MAX) {
        //组装数据
        socket_header header;
        header.flag = flag;
        header.type = type;
        header.len = length;
        header.crc8 = crc8;
        header.cmd_id = cmd_id;
        header.session_id = (session_id & 0xffff);
        //发送数据
        sendv_item items[] = { { &header, sizeof(socket_header) }, {data, data_len} };
        m_mgr->sendv(m_token, items, _countof(items));
        return length;
    }
    return 0;
}

int lua_socket_node::call(lua_State* L, uint32_t session_id, uint8_t flag) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 3, &data_len);
    size_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header;
        header.len = length;
        header.target_id = 0;
        header.session_id = session_id;
        header.context = (uint8_t)rpc_type::remote_call << 4 | flag;
        //发送数据
        sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len}};
        m_mgr->sendv(m_token, items, _countof(items));
        lua_pushinteger(L, length);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_transfer(lua_State* L, uint32_t session_id, uint32_t target_id, uint8_t service_id) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 4, &data_len);
    size_t length = data_len + sizeof(transfer_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        transfer_header header;
        header.len = length;
        header.target_id = target_id;
        header.service_id = service_id;
        header.session_id = session_id;
        header.context = (uint8_t)rpc_type::transfer_call << 4;
        //发送数据
        sendv_item items[] = { { &header, sizeof(transfer_header)}, {data, data_len}};
        m_mgr->sendv(m_token, items, _countof(items));
        lua_pushinteger(L, length);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_target(lua_State* L, uint32_t session_id, uint8_t flag, uint32_t target_id) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 4, &data_len);
    size_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header;
        header.len = length;
        header.target_id = target_id;
        header.session_id = session_id;
        header.context = (uint8_t)rpc_type::forward_target << 4 | flag;
        //发送数据
        sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
        m_mgr->sendv(m_token, items, _countof(items));
        lua_pushinteger(L, length);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_hash(lua_State* L, uint32_t session_id, uint8_t flag, uint16_t service_id, uint16_t hash) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 5, &data_len);
    size_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header;
        header.len = length;
        header.session_id = session_id;
        header.target_id = service_id << 16 | hash;
        header.context = (uint8_t)rpc_type::forward_hash << 4 | flag;
        //发送数据
        sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
        m_mgr->sendv(m_token, items, _countof(items));
        lua_pushinteger(L, length);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::transfer_call(lua_State* L, uint32_t session_id, uint32_t target_id) {
    char* data;
    size_t data_len = 0;
    if (lua_type(L, 3) == LUA_TTABLE) {
        slice* slice = lua_to_object<luakit::slice*>(L, 3);
        data = (char*)slice->data(&data_len);
    }
    else {
        data = (char*)lua_tolstring(L, 4, &data_len);
    }
    size_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header;
        header.len = length;
        header.session_id = session_id;
        header.context = (uint8_t)rpc_type::remote_call << 4 | 0x01;
        header.target_id = target_id;
        if (m_router->do_forward_target(&header, data, data_len)) {
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 0;
}

int lua_socket_node::transfer_hash(lua_State* L, uint32_t session_id, uint16_t service_id, uint16_t hash) {
    size_t data_len = 0;
    char* data = (char*)m_codec->encode(L, 4, &data_len);
    size_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header;
        header.len = length;
        header.session_id = session_id;
        header.context = (uint8_t)rpc_type::remote_call << 4 | 0x01;
        header.target_id = service_id << 16 | hash;
        if (m_router->do_forward_hash(&header, data, data_len)) {
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 0;
}

int lua_socket_node::on_recv(slice* slice) {
    if (eproto_type::proto_head == m_proto_type) {
        return on_call_head(slice);
    }
    if (eproto_type::proto_text == m_proto_type) {
        return on_call_text(slice);
    }
    if (eproto_type::proto_rpc != m_proto_type) {
        return on_call_data(slice);
    }

    size_t data_len;
    size_t header_len = sizeof(router_header);
    auto hdata = slice->peek(header_len);
    router_header* header = (router_header*)hdata;
    rpc_type msg = (rpc_type)(header->context >> 4);
    if (msg == rpc_type::transfer_call) {
        header_len = sizeof(transfer_header);
    }
    slice->erase(header_len);
    switch (msg) {
    case rpc_type::remote_call:
        on_call(header, slice);
        break;
    case rpc_type::transfer_call:
        on_transfer((transfer_header*)header, slice);
        break;
    case rpc_type::forward_target:{
            auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_target(header, data, data_len)) {
                on_forward_error(header, slice);
            }
        }
        break;
    case rpc_type::forward_master: {
            auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_master(header, data, data_len)) {
                on_forward_error(header, slice);
            }
        }
        break;
    case rpc_type::forward_hash: {
             auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_hash(header, data, data_len)) {
                on_forward_error(header, slice);
            }
        }
        break;
    case rpc_type::forward_broadcast: {
            size_t broadcast_num = 0;
            auto data = (char*)slice->data(&data_len);
            if (m_router->do_forward_broadcast(header, m_token, data, data_len, broadcast_num)) {
                on_forward_broadcast(header, broadcast_num);
            } else {
                on_forward_error(header, slice);
            }
        }
        break;
    }
    return header->len;
}

void lua_socket_node::on_forward_error(router_header* header, slice* slice) {
    if (header->session_id > 0) {
        m_codec->set_slice(slice);
        m_luakit->object_call(this, "on_forward_error", nullptr, m_codec, std::tie(), header->session_id, header->target_id);
    }
}

void lua_socket_node::on_forward_broadcast(router_header* header, size_t broadcast_num) {
    if (header->session_id > 0) {
        m_luakit->object_call(this, "on_forward_broadcast", nullptr, std::tie(), header->session_id, broadcast_num);
    }
}

void lua_socket_node::on_transfer(transfer_header* header, slice* slice) {
    uint8_t service_id = header->service_id;
    uint32_t target_id = header->target_id;
    uint32_t session_id = header->session_id;
    m_luakit->object_call(this, "on_transfer", nullptr, std::tie(), header->len, session_id, service_id, target_id, slice);
}

int lua_socket_node::on_call_head(slice* slice) {
    size_t header_len = sizeof(socket_header);
    auto data = slice->peek(header_len);
    socket_header* header = (socket_header*)data;
    uint8_t crc8 = header->crc8;
    uint8_t flag = header->flag;
    uint8_t type = header->type;
    uint16_t cmd_id = header->cmd_id;
    uint32_t session_id = header->session_id;
    if (session_id > 0) session_id |= m_stoken;
    slice->erase(header_len);
    std::string body((char*)slice->head(), slice->size());
    m_luakit->object_call(this, "on_call_head", nullptr, std::tie(), header->len, cmd_id, flag, type, crc8, session_id, body);
    return header->len;
}

void lua_socket_node::on_call(router_header* header, slice* slice) {
    m_codec->set_slice(slice);
    uint8_t flag = header->context & 0xff;
    uint32_t session_id = header->session_id;
    m_luakit->object_call(this, "on_call", nullptr, m_codec, std::tie(), header->len, session_id, flag);
}

int lua_socket_node::on_call_data(slice* slice) {
    m_codec->set_slice(slice);
    size_t buf_size = slice->size();
    m_luakit->object_call(this, "on_call_data", nullptr, m_codec, std::tie(), buf_size);
    return buf_size;
}

int lua_socket_node::on_call_text(slice* slice) {
    bool success = true;
    m_codec->set_slice(slice);
    size_t buf_size = slice->size();
    m_luakit->object_call(this, "on_call_data", [&](std::string_view) { success = false; }, m_codec, std::tie(), buf_size);
    return success ? (buf_size - slice->size()) : -1;
}
