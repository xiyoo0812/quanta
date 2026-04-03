#include "stdafx.h"
#include "socket_dns.h"
#include "socket_mgr.h"
#include "socket_stream.h"
#include "socket_router.h"

#ifdef IO_IOCP
socket_stream::socket_stream(socket_mgr* mgr, socket_t fd, LPFN_CONNECTEX connect_func) {
    mgr->increase_count();
    m_mgr = mgr;
    m_fd = fd;
    m_token = mgr->new_token();
    m_connect_func = connect_func;
    m_ip[0] = 0;
}
#endif

socket_stream::socket_stream(socket_mgr* mgr, socket_t fd) {
    mgr->increase_count();
    m_token = mgr->new_token();
    m_fd = fd;
    m_mgr = mgr;
    m_ip[0] = 0;
}

socket_stream::~socket_stream() {
    if (m_fd != INVALID_SOCKET) {
        closesocket(m_fd);
        m_fd = INVALID_SOCKET;
    }
    if (m_codec) {
        m_codec = nullptr;
    }
    m_mgr->decrease_count();
}

bool socket_stream::get_remote_ip(std::string& ip) {
    ip = m_ip;
    return true;
}

bool socket_stream::accept_socket(socket_t fd, const char ip[]) {
#ifdef IO_IOCP
    if (!wsa_recv_empty(fd, m_recv_ovl))
        return false;
    m_ovl_ref++;
#endif
    strncpy(m_ip, ip, INET_ADDRSTRLEN - 1);
    m_fd = fd;
    m_link_status = LINK_CONNECTED;
    m_last_recv_time = luakit::steady_ms();
    return true;
}

void socket_stream::connect(const char ip[], int port, int timeout) {
    if (resolver_ip(&m_addr, ip, port)) {
        m_connecting_time = luakit::steady_ms() + timeout;
    }
}

void socket_stream::close() {
    if (m_link_status == LINK_CLOSED) {
        return;
    }
    if (m_fd == INVALID_SOCKET) {
        m_link_status = LINK_CLOSED;
        return;
    }
    shutdown(m_fd, SD_RECEIVE);
#ifdef IO_IOCP
    if (wsa_io_cancel(m_fd, m_recv_ovl)) {
        m_ovl_ref--;
    }
#endif
    m_link_status = LINK_CLOSING;
}

bool socket_stream::update(int64_t now) {
    switch (m_link_status) {
        case LINK_CLOSED: {
#ifdef IO_IOCP
            if (m_ovl_ref > 0) return true;
#endif
            return false;
        }
        case LINK_CLOSING: {
#ifdef IO_IOCP
            if (m_ovl_ref > 0) return true;
#endif
            if (!m_send_buffer->empty()) return true;
            m_link_status = LINK_CLOSED;
            return true;
        }
        case LINK_INIT: {
            if (m_connecting_time == 0) {
                on_connect(false, "resolver failed");
                return true;
            }
            try_connect();
            return true;
        }
        case LINK_CONNECTING:{
            if (now > m_connecting_time) {
                on_connect(false, "timeout");
                return true;
            }
            return true;
        }
        default: {
            if (m_timeout > 0 && now - m_last_recv_time > m_timeout) {
                on_error("timeout");
                return true;
            }
            dispatch_package();
        }
    }
    return true;
}

#ifdef IO_IOCP
static bool bind_any(socket_t s) {
    struct sockaddr_in v4addr = {
        .sin_family = AF_INET, 
        .sin_port = 0,
        .sin_addr = {}
    };
    int ret = ::bind(s, (sockaddr*)&v4addr, (int)sizeof(v4addr));
    return ret != SOCKET_ERROR;
}

bool socket_stream::do_connect() {
    if (!bind_any(m_fd)) {
        on_connect(false, "bind-failed");
        return false;
    }

    if (!m_mgr->watch_connecting(m_fd, this)) {
        on_connect(false, "watch-failed");
        return false;
    }

    memset(&m_send_ovl, 0, sizeof(m_send_ovl));
    auto ret = (*m_connect_func)(m_fd, &m_addr, sizeof(sockaddr), nullptr, 0, nullptr, &m_send_ovl);
    if (!ret) {
        int err = get_socket_error();
        if (err == ERROR_IO_PENDING) {
            m_ovl_ref++;
            return true;
        }
        on_connect(false, "connect-failed");
        return false;
    }

    if (!wsa_recv_empty(m_fd, m_recv_ovl)) {
        on_connect(false, "connect-failed");
        return false;
    }

    m_ovl_ref++;
    on_connect(true, "ok");
    return true;
}
#endif

#ifndef IO_IOCP
bool socket_stream::do_connect() {
    auto ret = ::connect(m_fd, &m_addr, sizeof(sockaddr));
    if (ret != SOCKET_ERROR) {
        on_connect(true, "ok");
        return true;
    }

    if (get_socket_error() != EINPROGRESS)
        return false;

    if (!m_mgr->watch_connecting(m_fd, this)) {
        on_connect(false, "watch-failed");
        return false;
    }
    return true;
}
#endif

void socket_stream::try_connect() {
    if (m_fd == INVALID_SOCKET) {
        on_connect(false, "connect-failed");
        return;
    }
    set_no_block(m_fd);
    set_no_delay(m_fd, 1);
    set_close_on_exec(m_fd);
    get_ip_string(m_ip, sizeof(m_ip), &m_addr);
    m_link_status = LINK_CONNECTING;
    if (!do_connect()){
        on_connect(false, "connect-failed");
    }
}

bool socket_stream::send(const void* data, size_t data_len) {
    if (m_link_status != LINK_CONNECTED)
        return false;

    if (data_len > 0) stream_send((char*)data, data_len);
    return true;
}

bool socket_stream::sendv(const sendv_item items[], int count) {
    if (m_link_status != LINK_CONNECTED)
        return false;

    for (int i = 0; i < count; i++) {
        auto item = items[i];
        if (item.len > 0) stream_send((char*)item.data, item.len);
    }
    return true;
}

void socket_stream::stream_send(const char* data, size_t data_len) {
    if (m_send_buffer->empty()) {
        while (data_len > 0) {
            int send_len = ::send(m_fd, data, (int)data_len, 0);
            if (send_len == 0) {
                on_error("connection-send-lost");
                return;
            }
            if (send_len == SOCKET_ERROR) {
                break;
            }
            data += send_len;
            data_len -= send_len;
        }
        if (data_len == 0) {
            return;
        }
    }
    if (0 == m_send_buffer->push_data((const uint8_t*)data, data_len)) {
        on_error("send-failed");
        return;
    }
#ifdef IO_IOCP
    if (!wsa_send_empty(m_fd, m_send_ovl)) {
        on_error("send-failed");
        return;
    }
    m_ovl_ref++;
#else
    if (!m_mgr->watch_send(m_fd, this, true)) {
        on_error("watch-error");
        return;
    }
#endif
}

#ifdef IO_IOCP
void socket_stream::on_complete(WSAOVERLAPPED* ovl) {
    m_ovl_ref--;
    if (m_link_status == LINK_CONNECTED){
        if (ovl == &m_recv_ovl) {
            do_recv(UINT_MAX, false);
        } else {
            do_send(UINT_MAX, false);
        }
        return;
    }
    if (m_link_status == LINK_CLOSING) {
        if (ovl == &m_recv_ovl) {
            do_recv(UINT_MAX, false);
        }
        return;
    }

    if (m_link_status == LINK_CONNECTING) {
        int seconds = 0;
        socklen_t sock_len = (socklen_t)sizeof(seconds);
        auto ret = getsockopt(m_fd, SOL_SOCKET, SO_CONNECT_TIME, (char*)&seconds, &sock_len);
        if (ret == 0 && seconds != 0xffffffff) {
            if (!wsa_recv_empty(m_fd, m_recv_ovl)) {
                on_connect(false, "connect-failed");
                return;
            }
            m_ovl_ref++;
            on_connect(true, "ok");
            return;
        }
        on_connect(false, "connect-failed");
    }
}
#endif

#ifndef IO_IOCP
void socket_stream::on_can_send(size_t max_len, bool is_eof) {
    if (m_link_status == LINK_CONNECTED || m_link_status == LINK_CLOSING) {
        do_send(max_len, is_eof);
        return;
    }
    if (m_link_status == LINK_CONNECTING) {
        int err = 0;
        socklen_t sock_len = sizeof(err);
        auto ret = getsockopt(m_fd, SOL_SOCKET, SO_ERROR, (char*)&err, &sock_len);
        if (ret == 0 && err == 0 && !is_eof) {
            if (!m_mgr->watch_connected(m_fd, this)) {
                on_connect(false, "watch-error");
                return;
            }
            on_connect(true, "ok");
            return;
        }
        on_connect(false, "connect-failed");
    }
}
#endif

void socket_stream::do_send(size_t max_len, bool is_eof) {
    size_t total_send = 0;
    while (total_send < max_len) {
        size_t data_len = 0;
        auto data = m_send_buffer->data(&data_len);
        if (data_len == 0) {
            if (!m_mgr->watch_send(m_fd, this, false)) {
                on_error("watch-error");
                return;
            }
            break;
        }

        size_t try_len = std::min<size_t>(data_len, max_len - total_send);
        int send_len = ::send(m_fd, (char*)data, (int)try_len, 0);
        if (send_len == SOCKET_ERROR) {
            int err = get_socket_error();
#ifdef IO_IOCP
            if (err == WSAEWOULDBLOCK) {
                if (!wsa_send_empty(m_fd, m_send_ovl)) {
                    on_error("send-failed");
                    return;
                }
                m_ovl_ref++;
                break;
            }
#else
            if (err == EINTR)
                continue;
            if (err == EAGAIN)
                break;
#endif
            on_error("send-failed");
            return;
        }
        if (send_len == 0) {
            on_error("connection-send-lost");
            return;
        }
        total_send += send_len;
        m_send_buffer->pop_size((size_t)send_len);
    }
    if (is_eof || max_len == 0) {
        on_error("connection-lost");
    }
}

void socket_stream::do_recv(size_t max_len, bool is_eof) {
    size_t total_recv = 0;
    while (total_recv < max_len && m_link_status == LINK_CONNECTED) {
        auto* space = m_recv_buffer->peek_space(SOCKET_TCP_RECV_LEN);
        if (space == nullptr) {
            on_error("recv-buffer-full");
            return;
        }
        int recv_len = ::recv(m_fd, (char*)space, SOCKET_TCP_RECV_LEN, 0);
        if (recv_len < 0) {
            int err = get_socket_error();
#ifdef IO_IOCP
            if (err == WSAEWOULDBLOCK) {
                if (!wsa_recv_empty(m_fd, m_recv_ovl)) {
                    on_error("recv-failed");
                    return;
                }
                m_ovl_ref++;
                break;
            }
#else
            if (err == EINTR)
                continue;
            if (err == EAGAIN)
                break;
#endif
            on_error("recv-failed");
            return;
        }
        if (recv_len == 0) {
            if (!m_recv_buffer->empty()) {
                dispatch_package();
            }
            on_error("connection-recv-lost");
            return;
        }
        total_recv += recv_len;
        m_recv_buffer->pop_space(recv_len);
    }

    if (is_eof || max_len == 0) {
        on_error("connection-lost");
    }
}

void socket_stream::dispatch_package() {
    int64_t now = luakit::steady_ms();
    while (m_link_status == LINK_CONNECTED) {
        if (!m_codec){
            on_error("codec-is-null");
            break;
        }
        size_t data_len;
        auto* data = m_recv_buffer->data(&data_len);
        if (data_len == 0) break;
        slice* slice = m_recv_buffer->get_slice();
        m_codec->set_slice(slice);
        //解析数据包头长度
        int32_t package_size = m_codec->load_packet(data_len);
        //当前包头长度解析失败, 关闭连接
        if (package_size < 0){
            on_error("package-length-err");
            break;
        }
        // 数据包还没有收完整
        if (package_size == 0) break;
        // 数据回调
        slice->attach(data, package_size);
        try {
            m_package_cb(slice);
        } catch(const std::length_error&) {
            m_recv_buffer->pop_size(m_codec->get_packet_len());
            break;
        } catch(const std::exception& e) {
            on_error(e.what());
            break;
        }
        // 接收缓冲读游标调整
        m_recv_buffer->pop_size(m_codec->get_packet_len());
        m_last_recv_time = luakit::steady_ms();
        // 防止单个连接处理太久，不能大于100ms
        if (m_last_recv_time - now > 100) break;
    }
}

void socket_stream::on_error(const char err[]) {
    if (m_link_status == LINK_CONNECTED) {
        // kqueue实现下,如果eof时不及时关闭或unwatch,则会触发很多次eof
        m_link_status = LINK_CLOSED;
        m_error_cb(err);
    }
}

void socket_stream::on_connect(bool ok, const char reason[]) {
    if (!ok) {
        m_link_status = LINK_CLOSED;
    } else {
        m_link_status = LINK_CONNECTED;
        m_last_recv_time = luakit::steady_ms();
    }
    m_connect_cb(ok, reason);
}
