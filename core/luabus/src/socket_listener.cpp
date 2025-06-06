#include "stdafx.h"
#include "socket_mgr.h"
#include "socket_listener.h"

#ifdef IO_IOCP
socket_listener::socket_listener(socket_mgr* mgr, LPFN_ACCEPTEX accept_func, LPFN_GETACCEPTEXSOCKADDRS addrs_func) {
    mgr->increase_count();
    m_mgr = mgr;
    m_accept_func = accept_func;
    m_addrs_func = addrs_func;
    memset(m_nodes, 0, sizeof(m_nodes));
    for (auto& node : m_nodes) {
        node.fd = INVALID_SOCKET;
    }
}
#else
socket_listener::socket_listener(socket_mgr* mgr) {
    mgr->increase_count();
    m_mgr = mgr;
}
#endif

socket_listener::~socket_listener() {
#ifdef IO_IOCP
    for (auto& node : m_nodes) {
        if (node.fd != INVALID_SOCKET) {
            closesocket(node.fd);
            node.fd = INVALID_SOCKET;
        }
    }
#endif

    if (m_socket != INVALID_SOCKET) {
        closesocket(m_socket);
        m_socket = INVALID_SOCKET;
    }
    m_mgr->decrease_count();
}

bool socket_listener::setup(socket_t fd) {
    m_socket = fd;
    m_link_status = elink_status::link_connected;
    return true;
}

bool socket_listener::update(int64_t) {
    if (m_link_status == elink_status::link_closed && m_socket != INVALID_SOCKET) {
        closesocket(m_socket);
        m_socket = INVALID_SOCKET;
    }

#ifdef IO_IOCP
    if (m_ovl_ref == 0 && m_link_status == elink_status::link_connected) {
        for (auto& node : m_nodes) {
            if (node.fd == INVALID_SOCKET) {
                queue_accept(&node.ovl);
            }
        }
    }
#endif

    if (m_link_status == elink_status::link_closed) {
#ifdef IO_IOCP
        return m_ovl_ref != 0;
#else
        return false;
#endif
    }
    return true;
}

#ifdef IO_IOCP
void socket_listener::on_complete(WSAOVERLAPPED* ovl) {
    m_ovl_ref--;
    if (m_link_status != elink_status::link_connected)
        return;

    listen_node* node = CONTAINING_RECORD(ovl, listen_node, ovl);
    assert(node >= m_nodes && node < m_nodes + _countof(m_nodes));
    assert(node->fd != INVALID_SOCKET);

    if (m_mgr->is_full()) {
        closesocket(node->fd);
        node->fd = INVALID_SOCKET;
        queue_accept(ovl);
        return;
    }

    sockaddr* local_addr = nullptr;
    sockaddr* remote_addr = nullptr;
    int local_addr_len = 0;
    int remote_addr_len = 0;
    char ip[INET6_ADDRSTRLEN];

    (*m_addrs_func)(node->buffer, 0, sizeof(node->buffer[0]), sizeof(node->buffer[2]), &local_addr, &local_addr_len, &remote_addr, &remote_addr_len);
    get_ip_string(ip, sizeof(ip), remote_addr);

    set_no_block(node->fd);

    int token = m_mgr->accept_stream(m_token, node->fd, ip);
    m_accept_cb(token);
    node->fd = INVALID_SOCKET;
    queue_accept(ovl);
}

void socket_listener::queue_accept(WSAOVERLAPPED* ovl) {
    listen_node* node = CONTAINING_RECORD(ovl, listen_node, ovl);

    assert(node >= m_nodes && node < m_nodes + _countof(m_nodes));
    assert(node->fd == INVALID_SOCKET);

    sockaddr_storage listen_addr;
    socklen_t listen_addr_len = sizeof(listen_addr);
    getsockname(m_socket, (sockaddr*)&listen_addr, &listen_addr_len);

    while (m_link_status == elink_status::link_connected) {
        memset(ovl, 0, sizeof(*ovl));
        // 注,AF_INET6本身是可以支持ipv4的,但是...需要win10以上版本,win7不支持, 所以这里取listen_addr
        node->fd = socket(listen_addr.ss_family, SOCK_STREAM, IPPROTO_IP);
        if (node->fd == INVALID_SOCKET) {
            m_link_status = elink_status::link_closed;
            m_error_cb("new-socket-failed");
            return;
        }

        set_no_block(node->fd);

        DWORD bytes = 0;
        static_assert(sizeof(sockaddr_storage) >= sizeof(sockaddr_in6) + 16, "buffer too small");
        auto ret = (*m_accept_func)(m_socket, node->fd, node->buffer, 0, sizeof(node->buffer[0]), sizeof(node->buffer[1]), &bytes, ovl);
        if (!ret) {
            int err = get_socket_error();
            if (err != ERROR_IO_PENDING) {
                char txt[MAX_ERROR_TXT];
                get_error_string(txt, sizeof(txt), err);
                closesocket(node->fd);
                node->fd = INVALID_SOCKET;
                m_link_status = elink_status::link_closed;
                m_error_cb(txt);
                return;
            }
            m_ovl_ref++;
            return;
        }

        sockaddr* local_addr = nullptr;
        sockaddr* remote_addr = nullptr;
        int local_addr_len = 0;
        int remote_addr_len = 0;
        char ip[INET6_ADDRSTRLEN];

        (*m_addrs_func)(node->buffer, 0, sizeof(node->buffer[0]), sizeof(node->buffer[2]), &local_addr, &local_addr_len, &remote_addr, &remote_addr_len);
        get_ip_string(ip, sizeof(ip), remote_addr);

        m_mgr->accept_stream(m_token, node->fd, ip);
        m_accept_cb(node->fd);
        node->fd = INVALID_SOCKET;
    }
}
#endif

#ifndef IO_IOCP
void socket_listener::on_can_recv(size_t max_len, bool is_eof) {
    size_t total_accept = 0;
    while (total_accept < max_len && m_link_status == elink_status::link_connected) {
        sockaddr_storage addr;
        socklen_t addr_len = (socklen_t)sizeof(addr);
        char ip[INET_ADDRSTRLEN];

        socket_t fd = accept(m_socket, (sockaddr*)&addr, &addr_len);
        if (fd == INVALID_SOCKET)
            break;

        total_accept++;
        if (m_mgr->is_full()) {
            closesocket(fd);
            continue;
        }

        get_ip_string(ip, sizeof(ip), &addr);
        set_no_block(fd);
        set_no_delay(fd, 1);
        set_close_on_exec(fd);

        m_mgr->accept_stream(m_token, fd, ip);
        m_accept_cb(fd);
    }
}
#endif

