#pragma once

#include "socket_mgr.h"

struct socket_stream : public socket_object
{
#ifdef _MSC_VER
    socket_stream(socket_mgr* mgr, LPFN_CONNECTEX connect_func);
#endif
    socket_stream(socket_mgr* mgr);

    ~socket_stream();
    bool get_remote_ip(std::string& ip) override;
    bool accept_socket(socket_t fd, const char ip[]);
    void connect(const char ip[], int port, int timeout);
    bool update(int64_t now) override;
    bool do_connect();
    void try_connect();
    void close() override;
    void set_error_callback(const std::function<void(const char*)> cb) override { m_error_cb = cb; }
    void set_connect_callback(const std::function<void(bool, const char*)> cb) override { m_connect_cb = cb; }
    void set_package_callback(const std::function<void(slice*)> cb) override { m_package_cb = cb; }
    void set_timeout(int duration) override { m_timeout = duration; }
    void set_nodelay(int flag) override { set_no_delay(m_socket, flag); }

    int get_sendbuf_size() { return m_send_buffer->size(); }
    int get_recvbuf_size() { return m_recv_buffer->size(); }

    void send(const void* data, size_t data_len) override;
    void sendv(const sendv_item items[], int count) override;
    void stream_send(const char* data, size_t data_len);

#ifdef _MSC_VER
    void on_complete(WSAOVERLAPPED* ovl) override;
#endif

#if defined(__linux) || defined(__APPLE__) || defined(__ORBIS__) || defined(__PROSPERO__)
    void on_can_recv(size_t max_len, bool is_eof) override { do_recv(max_len, is_eof); }
    void on_can_send(size_t max_len, bool is_eof) override;
#endif

    void do_send(size_t max_len, bool is_eof);
    void do_recv(size_t max_len, bool is_eof);

    void dispatch_package();
    void on_error(const char err[]);
    void on_connect(bool ok, const char reason[]);

    socket_mgr* m_mgr = nullptr;
    socket_t m_socket = INVALID_SOCKET;
    std::shared_ptr<luabuf> m_recv_buffer = std::make_shared<luabuf>();
    std::shared_ptr<luabuf> m_send_buffer = std::make_shared<luabuf>();

    sockaddr m_addr;
    char m_ip[INET_ADDRSTRLEN];
    int m_timeout = -1;

    int64_t m_last_recv_time = 0;
    int64_t m_connecting_time = 0;

#ifdef _MSC_VER
    LPFN_CONNECTEX m_connect_func = nullptr;
    WSAOVERLAPPED m_send_ovl;
    WSAOVERLAPPED m_recv_ovl;
    int m_ovl_ref = 0;
#endif

    std::function<void(const char*)> m_error_cb = nullptr;
    std::function<void(bool, const char*)> m_connect_cb = nullptr;
    std::function<void(slice*)> m_package_cb = nullptr;
};
