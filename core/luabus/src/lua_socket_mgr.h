#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_router.h"

class luarpc_codec : public luacodec {
public:
    virtual int load_packet(size_t data_len) {
        if (!m_slice) return 0;
        uint32_t* packet_len = (uint32_t*)m_slice->peek(sizeof(uint32_t));
        if (!packet_len) return 0;
        if (*packet_len < sizeof(router_header)) return 0;
        m_packet_len = *packet_len;
        if (m_packet_len > 0xffffff) return -1;
        if (m_packet_len > data_len) return 0;
        if (!m_slice->peek(m_packet_len)) return 0;
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
    int map_token(uint32_t node_id, uint32_t token);
    int listen(lua_State* L, const char* ip, int port);
    int connect(lua_State* L, const char* ip, int port, int timeout);
    int wait(int64_t now, int timeout) { return m_mgr->wait(now, timeout); }
    int broadcast(lua_State* L, codec_base* codec, uint32_t kind);
    int broadgroup(lua_State* L, codec_base* codec);
    void set_codec(uint32_t token, codec_base* codec);

private:
    luabuf m_buf;
    lua_State* m_lvm;
    luarpc_codec m_codec;
    stdsptr<socket_mgr> m_mgr;
    stdsptr<socket_router> m_router;
};

