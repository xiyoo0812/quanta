#pragma once

#include "socket_helper.h"

class socket_tcp {
public:
    socket_tcp() {}
    socket_tcp(socket_t fd) : m_fd(fd) {};

    ~socket_tcp();

    void close();

    bool invalid();

    bool setup(bool noblock, bool reuse);

    void set_buff_size(int rcv_size, int snd_size = 0);

    int accept(lua_State* L, int timeout, bool noblock);

    int listen(lua_State* L, const char* ip, int port);

    int connect(lua_State* L, const char* ip, int port, int timeout);

    int send(lua_State* L, const char* buf, size_t len, int timeout);

    int recv(lua_State* L, int timeout);

protected:
    int socket_waitfd(socket_t fd, int sw, size_t tm);

protected:
    socket_t m_fd;
    char m_recv_buf[SOCKET_TCP_RECV_LEN];
};
