#pragma once

#include "socket_helper.h"

class socket_udp {
public:
    ~socket_udp();

    void close();

    bool setup(bool noblock, bool broadcast, bool reuse);

    int bind(lua_State* L, const char* ip, int port);

    int add_group(lua_State* L, const char* ip, bool loop);

    int send(lua_State* L, const char* buf, size_t len, const char* ip, int port);

    int recv(lua_State* L);

protected:
    socket_t m_fd;
    ip_mreq* m_mreq = nullptr;
    char m_recv_buf[SOCKET_RECV_LEN];
};
