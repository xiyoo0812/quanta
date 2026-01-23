#pragma once
#include "lua_socket_node.h"

class luarpc_codec : public codec_base {
public:
    virtual int load_packet(size_t data_len) {
        if (!m_slice) return 0;
        router_header* header = (router_header*)m_slice->peek(sizeof(router_header));
        if (!header) return 0;
        uint32_t len = header->len;
        if (len < sizeof(router_header)) return -1;
        if (len > data_len) return 0;
        if (!m_slice->peek(len)) return 0;
        m_packet_len = len;
        return m_packet_len;
    }
};

class lua_socket_mgr final
{
public:
    ~lua_socket_mgr(){}
    bool setup(lua_State* L, int max_fd);
    int get_sendbuf_size(uint32_t token);
    int get_recvbuf_size(uint32_t token);
    void set_relay_service(uint8_t id);
    void map_client(uint32_t client_id, int32_t token);
    void map_group(uint32_t group_id, uint32_t client_id, bool enter);
    void map_server(uint32_t client_id, uint32_t server_id, uint32_t token);
    int map_router(uint32_t node_id, int32_t token);
    bool check_service(uint32_t server_id, uint32_t client_id);
    int listen(lua_State* L, const char* ip, int port);
    int connect(lua_State* L, const char* ip, int port, int timeout);
    int wait(int64_t now, int timeout) { return m_mgr->wait(now, timeout); }
    int broadcast(lua_State* L, codec_base* codec, uint32_t kind);
    int broadgroup(lua_State* L, codec_base* codec);
    void set_codec(uint32_t token, codec_base* codec);

    std::vector<uint32_t> query_servers(uint32_t client_id);

private:
    luabuf m_buf;
    lua_State* m_lvm;
    luarpc_codec m_codec;
    stdsptr<socket_mgr> m_mgr;
    stdsptr<socket_relay> m_relay;
    stdsptr<socket_router> m_router;
};

