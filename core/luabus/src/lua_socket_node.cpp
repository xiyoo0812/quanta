#include "stdafx.h"
#include "lua_socket_node.h"

lua_socket_node::lua_socket_node(uint32_t token, lua_State* L, std::shared_ptr<socket_mgr>& mgr,
    std::shared_ptr<socket_router> router, bool blisten, eproto_type proto_type)
    : m_token(token), m_lvm(L), m_mgr(mgr), m_router(router), m_proto_type(proto_type) {
    m_mgr->get_remote_ip(m_token, m_ip);
    m_stoken = (m_token & 0xffff) << 16;
    if (blisten) {
        m_mgr->set_accept_callback(token, [=](uint32_t steam_token, eproto_type proto_type) {
            luakit::kit_state kit_state(m_lvm);
            auto stream = new lua_socket_node(steam_token, m_lvm, m_mgr, m_router, false, proto_type);
            kit_state.object_call(this, "on_accept", nullptr, std::tie(), stream);
        });
    }
    m_mgr->set_connect_callback(token, [=](bool ok, const char* reason) {
        luakit::kit_state kit_state(m_lvm);
        kit_state.object_call(this, "on_connect", nullptr, std::tie(), ok ? "ok" : reason);
    });

    m_mgr->set_error_callback(token, [=](const char* err) {
        auto token = m_token;
        m_token = 0;
        luakit::kit_state kit_state(m_lvm);
        kit_state.object_call(this, "on_error", nullptr, std::tie(), token, err);
    });

    m_mgr->set_package_callback(token, [=](slice* data){
        on_recv(data);
    });
}

lua_socket_node::~lua_socket_node() {
    close();
}

int lua_socket_node::call_slice(slice* slice){
    return call_text((const char*)slice->head(), slice->size());
}

int lua_socket_node::call_text(const char* data, uint32_t data_len) {
    m_mgr->send(m_token, data, data_len);
    return data_len;
}

int lua_socket_node::call_head(uint16_t cmd_id, uint8_t flag, uint8_t type, uint32_t session_id, const char* data, uint32_t data_len){
    socket_header header;
    header.flag = flag;
    header.type = type;
    header.cmd_id = cmd_id;
    header.session_id = (session_id & 0xffff);
    header.len = data_len + sizeof(socket_header);

    sendv_item items[] = { { &header, sizeof(socket_header) }, {data, data_len} };
    m_mgr->sendv(m_token, items, _countof(items));
    return header.len;
}

int lua_socket_node::call(uint32_t session_id, uint8_t flag, slice* slice) {
    size_t data_len = 0;
    router_header header;
    char* data = (char*)slice->data(&data_len);
    header.len = data_len + sizeof(router_header);
    header.context = (uint8_t)rpc_type::remote_call << 4 | flag;
    header.session_id = session_id;
    header.target_id = 0;

    sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len}};
    m_mgr->sendv(m_token, items, _countof(items));
    return header.len;
}

int lua_socket_node::forward_target(uint32_t session_id, uint8_t flag, uint32_t target_id, slice* slice) {
    size_t data_len = 0;
    router_header header;
    char* data = (char*)slice->data(&data_len);
    header.len = data_len + sizeof(router_header);
    header.context = (uint8_t)rpc_type::forward_target << 4 | flag;
    header.session_id = session_id;
    header.target_id = target_id;

    sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
    m_mgr->sendv(m_token, items, _countof(items));
    return header.len;
}

int lua_socket_node::forward_hash(uint32_t session_id, uint8_t flag, uint16_t service_id, uint16_t hash, slice* slice) {
    size_t data_len = 0;
    router_header header;
    char* data = (char*)slice->data(&data_len);
    header.len = data_len + sizeof(router_header);
    header.context = (uint8_t)rpc_type::forward_hash << 4 | flag;
    header.session_id = session_id;
    header.target_id = service_id << 16 | hash;

    sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
    m_mgr->sendv(m_token, items, _countof(items));
    return header.len;
}

void lua_socket_node::close() {
    if (m_token != 0) {
        m_mgr->close(m_token);
        m_token = 0;
    }
}

void lua_socket_node::on_recv(slice* slice) {
    if (eproto_type::proto_head == m_proto_type) {
        on_call_head(slice);
        return;
    }
    if (eproto_type::proto_common == m_proto_type) {
        on_call_common(slice);
        return;
    }
    if (eproto_type::proto_text == m_proto_type) {
        on_call_text(slice);
        return;
    }

    size_t header_len = sizeof(router_header);
    auto hdata = slice->peek(header_len);
    router_header* header = (router_header*)hdata;

    size_t data_len;
    slice->erase(header_len);
    auto data = (char*)slice->data(&data_len);
    if (data_len == 0) {
        return;
    }

    rpc_type msg = (rpc_type)(header->context >> 4);
    switch (msg) {
    case rpc_type::remote_call:
        on_call(header, slice);
        break;
    case rpc_type::forward_target:
        if (!m_router->do_forward_target(header, data, data_len))
            on_forward_error(header);
        break;
    case rpc_type::forward_master:
        if (!m_router->do_forward_master(header, data, data_len))
            on_forward_error(header);
        break;
    case rpc_type::forward_hash:
        if (!m_router->do_forward_hash(header, data, data_len))
            on_forward_error(header);
        break;
    case rpc_type::forward_broadcast: {
        size_t broadcast_num = 0;
        if (m_router->do_forward_broadcast(header, m_token, data, data_len, broadcast_num))
            on_forward_broadcast(header, broadcast_num);
        else
            on_forward_error(header);
    }
    break;
    default:
        break;
    }
}

void lua_socket_node::on_forward_error(router_header* header) {
    if (header->session_id > 0) {
        luakit::kit_state kit_state(m_lvm);
        kit_state.object_call(this, "on_forward_error", nullptr, std::tie(), header->session_id);
    }
}

void lua_socket_node::on_forward_broadcast(router_header* header, size_t broadcast_num) {
    if (header->session_id > 0) {
        luakit::kit_state kit_state(m_lvm);
        kit_state.object_call(this, "on_forward_broadcast", nullptr, std::tie(), header->session_id, broadcast_num);
    }
}

void lua_socket_node::on_call(router_header* header, slice* slice) {
    luakit::kit_state kit_state(m_lvm);
    uint8_t flag = header->context & 0xff;
    uint32_t session_id = header->session_id;
    kit_state.object_call(this, "on_call", nullptr, std::tie(), header->len, session_id, flag, slice);
}

void lua_socket_node::on_call_head(slice* slice) {
    size_t header_len = sizeof(socket_header);
    auto data = slice->peek(header_len);
    socket_header* header = (socket_header*)data;
    uint8_t flag = header->flag;
    uint8_t type = header->type;
    uint16_t cmd_id = header->cmd_id;
    uint32_t session_id = header->session_id;
    if (session_id > 0) session_id |= m_stoken;
    slice->erase(header_len);
    luakit::kit_state kit_state(m_lvm);
    kit_state.object_call(this, "on_call_head", nullptr, std::tie(), header->len, cmd_id, flag, type, session_id, slice);
}

void lua_socket_node::on_call_text(slice* slice) {
    luakit::kit_state kit_state(m_lvm);
    kit_state.object_call(this, "on_call_text", nullptr, std::tie(), slice->size(), slice);
}

void lua_socket_node::on_call_common(slice* slice) {
    luakit::kit_state kit_state(m_lvm);
    kit_state.object_call(this, "on_call_common", nullptr, std::tie(), slice->size(), slice);
}

