#pragma once
#include "socket_relay.h"

class lua_socket_node
{
public:
    lua_socket_node(uint32_t token, lua_State* L, stdsptr<socket_mgr> mgr, proto_type type);
    ~lua_socket_node();

    void close();

    uint32_t get_route_count() {
        return m_router->get_route_count();
    }
    void set_timeout(int ms) {
        m_mgr->set_timeout(m_token, ms);
    }
    void set_nodelay(bool flag) {
        m_mgr->set_nodelay(m_token, flag);
    }
    void set_codec(codec_base* codec) {
        m_codec = codec;
        m_mgr->set_codec(m_token, codec);
    }
    void set_relay(stdsptr<socket_relay> relay) {
        m_relay = relay;
    }
    void set_router(stdsptr<socket_router> router) {
        m_router = router;
    }

    int call_pb(lua_State* L);
    int call_text(lua_State* L);

    template <rpc_type RT>
    int forward_by_method(lua_State* L, uint32_t session_id, uint32_t target_id, uint8_t service_id, uint8_t flag) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 5, &data_len);
        uint32_t length = data_len + sizeof(router_header);
        if (length <= USHRT_MAX) {
            router_header header;
            header.type = RT;
            header.len = length;
            header.flag = (proto_flag)flag;
            header.target_id = target_id;
            header.session_id = session_id;
            header.service_id = service_id;
            sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
            m_mgr->sendv(m_token, items, _countof(items));
            lua_pushinteger(L, length);
            return 1;
        }
        lua_pushinteger(L, 0);
        return 1;
    }

public:
    std::string m_ip;
    uint32_t m_token = 0;
    uint32_t m_node_id = 0;

private:
    void on_recv(slice* slice);
    void on_call_pb(slice* slice);
    void on_call_rpc(slice* slice);
    void on_call_text(slice* slice);
    void on_rpc_reply(router_header* header, slice* slice);

    proto_type m_type;
    codec_base* m_codec = nullptr;
    stdsptr<kit_state> m_lvm = nullptr;
    stdsptr<socket_mgr> m_mgr = nullptr;
    stdsptr<socket_relay> m_relay = nullptr;
    stdsptr<socket_router> m_router = nullptr;
};
