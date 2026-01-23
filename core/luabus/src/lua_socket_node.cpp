#include "stdafx.h"
#include "lua_socket_node.h"

lua_socket_node::lua_socket_node(uint32_t token, lua_State* L, stdsptr<socket_mgr> mgr, proto_type type)
        : m_token(token), m_type(type), m_mgr(mgr) {
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
        auto node = new lua_socket_node(steam_token, L, m_mgr, m_type);
        node->set_codec(m_codec);
        node->set_relay(m_relay);
        node->set_router(m_router);
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

int lua_socket_node::call_text(lua_State* L) {
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
        if (data_len > 0) {
            m_mgr->send(m_token, data, data_len);
            lua_pushinteger(L, data_len);
            return 1;
        }
    }
    lua_pushinteger(L, 0);
    return 1;
}

void lua_socket_node::on_recv(slice* slice) {
    switch (m_type) {
        case PROTO_PB: on_call_pb(slice); break;
        case PROTO_TEXT: on_call_text(slice); break;
        default: on_call_rpc(slice); break;
    }
}

void lua_socket_node::on_call_text(slice* slice) {
    m_lvm->object_call(this, "on_call_text", nullptr, m_codec, std::tie(), slice->size());
}

void lua_socket_node::on_call_pb(slice* slice) {
    relay_header* header = (relay_header*)slice->peek(sizeof(relay_header));
    if (m_relay) {
        switch (header->type) {
        case RELAY_SELF:
            m_lvm->object_call(this, "on_call_pb", nullptr, m_codec, std::tie());
            break;
        case RELAY_BROADCAST:
            m_relay->do_forward_broadcast(header, slice->head(), slice->size());
            break;
        case RELAY_GROUP:
            m_relay->do_forward_group(header, slice->head(), slice->size());
            break;
        case RELAY_CLIENT:
            m_relay->do_forward_client(header, slice->head(), slice->size());
            break;
        case RELAY_SERVICE:
            m_relay->do_forward_service(header, m_node_id, slice->head(), slice->size());
            break;
        }
    } else {
        m_lvm->object_call(this, "on_call_pb", nullptr, m_codec, std::tie());
    }
}

void lua_socket_node::on_rpc_reply(router_header* h, slice* slice) {
    if (m_relay) {
        auto service_id = m_relay->do_forward_relay(h, slice->head(), slice->size());
        if (service_id) {
            m_router->do_forward_relay(service_id, m_token, h, slice->head(), slice->size());
        }
    } else {
        m_lvm->object_call(this, "on_relay_rpc", nullptr, m_codec, std::tie(), h->len, h->session_id, h->target_id, h->service_id);
    }
}

void lua_socket_node::on_call_rpc(slice* slice) {
    router_header* header = (router_header*)slice->erase(sizeof(router_header));
    switch (header->type) {
    case FORWARD_SELF:
        m_lvm->object_call(this, "on_call_rpc", nullptr, m_codec, std::tie(), header->len, header->session_id, header->flag);
        break;
    case FORWARD_RELAY:
        on_rpc_reply(header, slice);
        break;
    case FORWARD_TARGET:
        m_router->do_forward_target(m_token, header, slice->head(), slice->size());
        break;
    case FORWARD_MASTER:
        m_router->do_forward_master(m_token, header, slice->head(), slice->size());
        break;
    case FORWARD_HASH:
        m_router->do_forward_hash(m_token, header, slice->head(), slice->size());
        break;
    case FORWARD_BROADCAST:
        m_router->do_forward_broadcast(m_token, header, slice->head(), slice->size());
        break;
    }
}
