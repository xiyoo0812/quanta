#include "stdafx.h"
#include "socket_tcp.h"
#include "socket_dns.h"

#define WAITFD_R        1
#define WAITFD_W        2
#define WAITFD_E        4
#define WAITFD_C        (WAITFD_E|WAITFD_W)

enum {
    IO_DONE = 0,        /* operation completed successfully */
    IO_TIMEOUT = -1,    /* operation timed out */
    IO_CLOSED = -2,     /* the connection has been closed */
    IO_UNKNOWN = -3
};

socket_tcp::~socket_tcp() {
    close();
}

void socket_tcp::close() {
    if (m_fd > 0) {
        closesocket(m_fd);
        m_fd = INVALID_SOCKET;
    }
}

bool socket_tcp::setup() {
    socket_t fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd == INVALID_SOCKET) {
        return false;
    }
    m_fd = fd;
    set_no_block(fd);
    return true;
}

bool socket_tcp::invalid() {
    return m_fd == INVALID_SOCKET;
}

int socket_tcp::socket_waitfd(socket_t fd, int sw, size_t tm) {
    fd_set rfds, wfds, efds, *rp = nullptr, *wp = nullptr, *ep = nullptr;
    if (sw & WAITFD_R) { FD_ZERO(&rfds); FD_SET(fd, &rfds); rp = &rfds;}
    if (sw & WAITFD_W) { FD_ZERO(&wfds); FD_SET(fd, &wfds); wp = &wfds;}
    if (sw & WAITFD_C) { FD_ZERO(&efds); FD_SET(fd, &efds); ep = &efds;}
    struct timeval tv;
    tv.tv_sec = tm / 1000;
    tv.tv_usec = (tm % 1000) * 1000;
    int ret = select(1024, rp, wp, ep, &tv);
    if (ret == -1) return get_socket_error();
    if (ret == 0) return IO_TIMEOUT;
    if (sw == WAITFD_C && FD_ISSET(fd, &efds)) return IO_CLOSED;
    return IO_DONE;
}

int socket_tcp::listen(lua_State* L, const char* ip, int port) {
    //set status
    set_no_block(m_fd);
    set_reuseaddr(m_fd);
    set_close_on_exec(m_fd);
    //bind && listen
    socklen_t addr_len = 0;
    sockaddr_storage addr;
    make_ip_addr(&addr, &addr_len, ip, port);
    if (::bind(m_fd, (sockaddr*)&addr, (int)addr_len) != SOCKET_ERROR) {
        if (::listen(m_fd, 200) != SOCKET_ERROR) {
            lua_pushboolean(L, true);
            return 1;
        }
    }
    lua_pushboolean(L, false);
    lua_pushstring(L, "listen failed");
    return 2;
}

int socket_tcp::connect(lua_State* L, const char* ip, int port, int timeout) {
    sockaddr addr;
    if (!resolver_ip(&addr, ip, port)) {
        close();
        lua_pushboolean(L, false);
        lua_pushstring(L, "resolver ip failed");
    }
    if(::connect(m_fd, &addr, sizeof(sockaddr)) == 0){
        lua_pushboolean(L, true);
        return 1;
    }
    int err = get_socket_error();
    if (err != WSAEINPROGRESS && err != WSAEWOULDBLOCK) {
        close();
        lua_pushboolean(L, false);
        lua_pushstring(L, "connect failed");
        return 2;
    }
    err = socket_waitfd(m_fd, WAITFD_C, timeout);
    if (err == IO_DONE) {
        lua_pushboolean(L, true);
        return 1;
    }
    lua_pushboolean(L, false);
    lua_pushstring(L, err == IO_TIMEOUT ? "timeout" : "select failed");
    if (err != IO_TIMEOUT) close();
    return 2;
}

int socket_tcp::accept(lua_State* L, int timeout) {
    if (m_fd == INVALID_SOCKET) {
        lua_pushnil(L);
        lua_pushstring(L, "socket invalid");
        return 2;
    }
    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    socklen_t addr_len = (socklen_t)sizeof(addr);
    while (true) {
        socket_t new_fd = ::accept(m_fd, (sockaddr*)&addr, &addr_len);
        if (new_fd != INVALID_SOCKET) {
            luakit::native_to_lua(L, new socket_tcp(new_fd));
            return 1;
        }
        int err = get_socket_error();
        if (err != WSAEINPROGRESS && err != WSAEWOULDBLOCK) {
            lua_pushnil(L);
            lua_pushstring(L, "accept failed");
            return 2;
        }
        err = socket_waitfd(m_fd, WAITFD_R, timeout);
        if (err != IO_DONE) {
            lua_pushnil(L);
            lua_pushstring(L, err == IO_TIMEOUT ? "timeout": "select failed");
            return 2;
        }
    }
}

int socket_tcp::send(lua_State* L, const char* buf, size_t len, int timeout) {
    if (m_fd == INVALID_SOCKET) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "socket invalid");
        return 2;
    }
    while (true) {
        int send_len = ::send(m_fd, buf, len, 0);
        if (send_len > 0) {
            lua_pushboolean(L, true);
            lua_pushinteger(L, send_len);
            return 1;
        }
        int err = get_socket_error();
        if (err != WSAEINPROGRESS && err != WSAEWOULDBLOCK) {
            close();
            lua_pushboolean(L, false);
            lua_pushstring(L, "send failed");
            return 2;
        }
        err = socket_waitfd(m_fd, WAITFD_W, timeout);
        if (err != IO_DONE) {
            lua_pushboolean(L, false);
            lua_pushstring(L, err == IO_TIMEOUT ? "timeout" : "select failed!");
            if (err != IO_TIMEOUT) close();
            return 2;
        }
    }
}

int socket_tcp::recv(lua_State* L, int timeout) {
    if (m_fd == INVALID_SOCKET) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "socket invalid");
        return 2;
    }
    while (true) {
        int recv_len = ::recv(m_fd, m_recv_buf, SOCKET_RECV_LEN, 0);
        if (recv_len > 0) {
            lua_pushboolean(L, true);
            lua_pushlstring(L, m_recv_buf, recv_len);
            return 2;
        }
        if (recv_len == 0) {
            close();
            lua_pushboolean(L, false);
            lua_pushstring(L, "connect lost");
            return 2;
        }
        int err = get_socket_error();
        if (err != WSAEINPROGRESS && err != WSAEWOULDBLOCK) {
            close();
            lua_pushboolean(L, false);
            lua_pushstring(L, "recv failed");
            return 2;
        }
        err = socket_waitfd(m_fd, WAITFD_R, timeout);
        if (err != IO_DONE) {
            lua_pushboolean(L, false);
            lua_pushstring(L, err == IO_TIMEOUT ? "timeout" : "select failed");
            if (err != IO_TIMEOUT) close();
            return 2;
        }
    }
}
