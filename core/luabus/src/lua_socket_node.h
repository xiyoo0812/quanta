#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_router.h"

class lua_socket_node
{
public:
    lua_socket_node(uint32_t token, lua_State* L, std::shared_ptr<socket_mgr>& mgr, std::shared_ptr<socket_router>& router
        , bool blisten = false, eproto_type proto_type = eproto_type::proto_rpc);
    ~lua_socket_node();

    void close();

    uint32_t build_session_id() { return m_stoken | m_sindex++; }
    uint32_t get_route_count() { return m_router->get_route_count(); }
    void set_timeout(int ms) { m_mgr->set_timeout(m_token, ms); }
    void set_nodelay(bool flag) { m_mgr->set_nodelay(m_token, flag); }
    void set_codec(codec_base* codec) { m_codec = codec; }

    int call_data(lua_State* L);
    int call_text(const char* data, uint32_t data_len);
    int call(lua_State* L, uint32_t session_id, uint8_t flag);
    int call_head(uint16_t cmd_id, uint8_t flag, uint8_t type, uint8_t crc8, uint32_t session_id, const char* data, uint32_t data_len);
    int forward_target(lua_State* L, uint32_t session_id, uint8_t flag, uint32_t target_id);

    int forward_hash(lua_State* L, uint32_t session_id, uint8_t flag, uint16_t service_id, uint16_t hash);

    int forward_transfer(lua_State* L, uint32_t session_id, uint32_t target_id, uint8_t service_id);

    int transfer_call(lua_State* L, uint32_t session_id, uint32_t target_id);
    int transfer_hash(lua_State* L, uint32_t session_id, uint16_t service_id, uint16_t hash);

    template <rpc_type forward_method>
    int forward_by_group(lua_State* L, uint32_t session_id, uint8_t flag, uint16_t service_id) {
        size_t data_len = 0;
        char* data = (char*)m_codec->encode(L, 4, &data_len);
        size_t length = data_len + sizeof(router_header);
        if (length <= USHRT_MAX) {
            router_header header;
            header.len = length;
            header.target_id = service_id;
            header.session_id = session_id;
            header.context = (uint8_t)forward_method << 4 | flag;
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
    uint32_t m_stoken = 0;
    uint16_t m_sindex = 1;

private:
    void on_recv(slice* slice);
    void on_call_head(slice* slice);
    void on_call_text(slice* slice);
    void on_call_common(slice* slice);
    void on_call(router_header* header, slice* slice);
    void on_transfer(transfer_header* header, slice* slice);
    void on_forward_broadcast(router_header* header, size_t target_size);
    void on_forward_error(router_header* header, slice* slice);

    codec_base* m_codec = nullptr;
    std::shared_ptr<socket_mgr> m_mgr;
    std::shared_ptr<kit_state> m_luakit;
    std::shared_ptr<socket_router> m_router;
    eproto_type m_proto_type;
};
