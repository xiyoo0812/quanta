#include "stdafx.h"
#include "lua_socket_node.h"

lua_socket_node::lua_socket_node(uint32_t token, lua_State* L, stdsptr<socket_mgr> mgr, stdsptr<socket_router> router, eproto_type type)
        : m_token(token), m_type(type), m_mgr(mgr), m_router(router) {
    m_stoken = m_token << 16;
    m_lvm = std::make_shared<kit_state>(L);
    m_mgr->get_remote_ip(m_token, m_ip);
    m_mgr->set_connect_callback(token, [=](bool ok, const char* reason) {
        m_lvm->object_call(this, "on_connect", nullptr, std::tie(), ok ? "ok" : reason);
    });
    m_mgr->set_error_callback(token, [=](const char* err) {
        m_lvm->object_call(this, "on_error", nullptr, std::tie(), m_token, err);
    });
    m_mgr->set_package_callback(token, [=](slice* slice){
        return on_recv(slice);
    });
    m_mgr->set_accept_callback(token, [=](uint32_t steam_token) {
        auto node = new lua_socket_node(steam_token, L, m_mgr, m_router, m_type);
        m_lvm->object_call(this, "on_accept", nullptr, std::tie(), node);
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
    m_router = nullptr;
    m_codec = nullptr;
    m_mgr = nullptr;
}

int lua_socket_node::call_data(lua_State* L) {
    const char* data = nullptr;
    size_t data_len = 0;
    if (m_codec) {
        data = (const char*)m_codec->encode(L, 1, &data_len);
    } else {
        data = lua_tolstring(L, 1, &data_len);
    }
    if (data_len > 0 && data_len <= SOCKET_PACKET_MAX) {
        m_mgr->send(m_token, data, data_len);
        lua_pushinteger(L, data_len);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::call_pb(lua_State* L) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 1, &data_len);
        if (data_len <= USHRT_MAX) {
            //发送数据
            m_mgr->send(m_token, data, data_len);
            lua_pushinteger(L, data_len);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::call(lua_State* L, uint32_t session_id, uint8_t flag, uint64_t trace_id, uint32_t span_id) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 5, &data_len);
        uint32_t length = data_len + sizeof(router_header);
        if (length <= SOCKET_PACKET_MAX) {
            //组装数据
            router_header header = {
                .head = {
                    .type = REMOTE_CALL,
                    .flag = flag,
                    .len = length,
                },
                .session_id = session_id,
                .trace_id = trace_id,
                .span_id = span_id
            };
            //发送数据
            sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len}};
            m_mgr->sendv(m_token, items, _countof(items));
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_transfer(lua_State* L, uint32_t session_id, uint32_t target_id, uint8_t service_id, uint64_t trace_id, uint32_t span_id) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 6, &data_len);
        uint32_t length = data_len + sizeof(transfer_header);
        if (length <= SOCKET_PACKET_MAX) {
            //组装数据
            transfer_header header = {
                .head = {
                    .type = TRANSFER_CALL,
                    .flag = 0x01,
                    .len = length,
                },
                .session_id = session_id,
                .target_id = target_id,
                .trace_id = trace_id,
                .span_id = span_id,
                .service_id = service_id
            };
            //发送数据
            sendv_item items[] = { { &header, sizeof(transfer_header)}, {data, data_len}};
            m_mgr->sendv(m_token, items, _countof(items));
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_target(lua_State* L, uint32_t session_id, uint8_t flag, uint32_t target_id, uint64_t trace_id, uint32_t span_id) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 6, &data_len);
        uint32_t length = data_len + sizeof(router_header);
        if (length <= SOCKET_PACKET_MAX) {
            //组装数据
            router_header header = {
                .head = {
                    .type = FORWARD_TARGET,
                    .flag = flag,
                    .len = length,
                },
                .session_id = session_id,
                .target_id = target_id,
                .trace_id = trace_id,
                .span_id = span_id
            };
            //发送数据
            sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
            m_mgr->sendv(m_token, items, _countof(items));
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::forward_hash(lua_State* L, uint32_t session_id, uint8_t flag, uint32_t service_id, uint16_t hash, uint64_t trace_id, uint32_t span_id) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 7, &data_len);
        uint32_t length = data_len + sizeof(router_header);
        if (length <= SOCKET_PACKET_MAX) {
            //组装数据
            router_header header = {
                .head = {
                    .type = FORWARD_HASH,
                    .flag = flag,
                    .len = length,
                },
                .session_id = session_id,
                .target_id = service_id << 16 | hash,
                .trace_id = trace_id,
                .span_id = span_id
            };
            //发送数据
            sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
            m_mgr->sendv(m_token, items, _countof(items));
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::transfer_call(lua_State* L, uint32_t session_id, uint32_t target_id, uint64_t trace_id, uint32_t span_id) {
    char* data;
    size_t data_len = 0;
    if (lua_type(L, 5) == LUA_TTABLE) {
        slice* slice = lua_to_object<luakit::slice*>(L, 5);
        data = (char*)slice->data(&data_len);
    } else {
        data = (char*)lua_tolstring(L, 5, &data_len);
    }
    uint32_t length = data_len + sizeof(router_header);
    if (length <= SOCKET_PACKET_MAX) {
        //组装数据
        router_header header = {
            .head = {
                .type = REMOTE_CALL,
                .flag = 0x01,
                .len = length,
            },
            .session_id = session_id,
            .target_id = target_id,
            .trace_id = trace_id,
            .span_id = span_id
        };
        if (m_router->do_forward_target(&header, data, data_len)) {
            lua_pushinteger(L, length);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

int lua_socket_node::transfer_hash(lua_State* L, uint32_t session_id, uint32_t service_id, uint16_t hash, uint64_t trace_id, uint32_t span_id) {
    if (m_codec) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 6, &data_len);
        uint32_t length = data_len + sizeof(router_header);
        if (length <= SOCKET_PACKET_MAX) {
            //组装数据
            router_header header = {
                .head = {
                    .type = REMOTE_CALL,
                    .flag = 0x01,
                    .len = length,
                },
                .session_id = session_id,
                .target_id = service_id << 16 | hash,
                .trace_id = trace_id,
                .span_id = span_id
            };
            if (m_router->do_forward_hash(&header, data, data_len)) {
                lua_pushinteger(L, length);
                return 1;
            }
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

void lua_socket_node::on_recv(slice* slice) {
    if (m_type == eproto_type::proto_pb) {
        return on_call_pb(slice);
    }
    if (m_type == eproto_type::proto_text) {
        return on_call_data(slice);
    }
    size_t data_len;
    size_t header_len = sizeof(router_header);
    auto hdata = slice->peek(header_len);
    router_header* header = (router_header*)hdata;
    rpc_type msg = header->head.type;
    if (msg == TRANSFER_CALL) {
        header_len = sizeof(transfer_header);
    }
    slice->erase(header_len);
    switch (msg) {
    case REMOTE_CALL:
        on_call(header, slice);
        break;
    case TRANSFER_CALL:
        on_transfer((transfer_header*)header, slice);
        break;
    case FORWARD_TARGET:{
            auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_target(header, data, data_len)) {
                on_forward_error(header);
            }
        }
        break;
    case FORWARD_MASTER: {
            auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_master(header, data, data_len)) {
                on_forward_error(header);
            }
        }
        break;
    case FORWARD_HASH: {
             auto data = (char*)slice->data(&data_len);
            if (!m_router->do_forward_hash(header, data, data_len)) {
                on_forward_error(header);
            }
        }
        break;
    case FORWARD_BROADCAST: {
            size_t broadcast_num = 0;
            auto data = (char*)slice->data(&data_len);
            if (m_router->do_forward_broadcast(header, m_token, data, data_len, broadcast_num)) {
                on_forward_broadcast(header, broadcast_num);
            } else {
                on_forward_error(header);
            }
        }
        break;
    }
}

void lua_socket_node::on_forward_error(router_header* header) {
    if (header->session_id > 0) {
        m_lvm->object_call(this, "on_forward_error", nullptr, m_codec, std::tie(), header->session_id, header->target_id);
    }
}

void lua_socket_node::on_forward_broadcast(router_header* header, size_t broadcast_num) {
    if (header->session_id > 0) {
        m_lvm->object_call(this, "on_forward_broadcast", nullptr, std::tie(), header->session_id, broadcast_num);
    }
}

void lua_socket_node::on_transfer(transfer_header* header, slice* slice) {
    uint8_t service_id = header->service_id;
    uint32_t target_id = header->target_id;
    uint32_t session_id = header->session_id;
    uint64_t trace_id = header->trace_id;
    uint32_t span_id = header->span_id;
    m_lvm->object_call(this, "on_transfer", nullptr, std::tie(), header->head.len, session_id, service_id, target_id, trace_id, span_id, slice);
}

void lua_socket_node::on_call_pb(slice* slice) {
    m_lvm->object_call(this, "on_call_pb", nullptr, m_codec, std::tie());
}

void lua_socket_node::on_call(router_header* header, slice* slice) {
    uint8_t flag = header->head.flag;
    uint32_t session_id = header->session_id;
    uint64_t trace_id = header->trace_id;
    uint32_t span_id = header->span_id;
    m_lvm->object_call(this, "on_call", nullptr, m_codec, std::tie(), header->head.len, session_id, flag, trace_id, span_id);
}

void lua_socket_node::on_call_data(slice* slice) {
    m_lvm->object_call(this, "on_call_data", nullptr, m_codec, std::tie(), slice->size());
}
