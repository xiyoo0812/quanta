﻿/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2016-11-01, trumanzhao@foxmail.com
*/

#pragma once

#include "socket_helper.h"
#include "socket_mgr.h"

struct socket_listener : public socket_object
{
#ifdef IO_IOCP
    socket_listener(socket_mgr* mgr, LPFN_ACCEPTEX accept_func, LPFN_GETACCEPTEXSOCKADDRS addrs_func);
#else
    socket_listener(socket_mgr* mgr);
#endif

    ~socket_listener();
    bool setup(socket_t fd);
    bool get_remote_ip(std::string& ip) override { return false; }
    bool update(int64_t now) override;
    void set_accept_callback(const std::function<void(int)> cb) override { m_accept_cb = cb; }
    void set_error_callback(const std::function<void(const char*)> cb) override { m_error_cb = cb; }

#ifdef IO_IOCP
    void on_complete(WSAOVERLAPPED* ovl);
    void queue_accept(WSAOVERLAPPED* ovl);
#else
    void on_can_recv(size_t max_len, bool is_eof) override;
#endif

private:
    socket_mgr* m_mgr = nullptr;
    socket_t m_socket = INVALID_SOCKET;
    std::function<void(int)> m_accept_cb;
    std::function<void(const char*)> m_error_cb;

#ifdef IO_IOCP
    struct listen_node
    {
        WSAOVERLAPPED ovl;
        socket_t fd;
        sockaddr_storage buffer[2];
    };
    listen_node m_nodes[16];
    LPFN_ACCEPTEX m_accept_func = nullptr;
    LPFN_GETACCEPTEXSOCKADDRS m_addrs_func = nullptr;
    int m_ovl_ref = 0;
#endif
};
