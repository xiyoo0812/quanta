﻿/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2016-11-01, trumanzhao@foxmail.com
*/

#pragma once

#include "socket_helper.h"
#include "io_buffer.h"
#include "socket_mgr_impl.h"

struct socket_stream : public socket_object
{
#ifdef _MSC_VER
    socket_stream(socket_mgr_impl* mgr, LPFN_CONNECTEX connect_func, eproto_type proto_type = eproto_type::proto_rpc);
#endif
    socket_stream(socket_mgr_impl* mgr, eproto_type proto_type = eproto_type::proto_rpc);

    ~socket_stream();
    bool get_remote_ip(std::string& ip) override;
    bool accept_socket(socket_t fd, const char ip[]);
    void connect(const char node_name[], const char service_name[], int timeout);
    bool update(int64_t now) override;
    bool do_connect();
    void try_connect();
    void close(bool immediately = true) override;
    void set_accept_callback(const std::function<void(int, eproto_type)>& cb) override { m_accept_cb = cb; }
    void set_package_callback(const std::function<void(char*, size_t)>& cb) override { m_package_cb = cb; }
    void set_error_callback(const std::function<void(const char*)>& cb) override { m_error_cb = cb; }
    void set_connect_callback(const std::function<void(bool, const char*)>& cb) override { m_connect_cb = cb; }
    void set_send_buffer_size(size_t size) override { m_send_buffer->resize(size); }
    void set_recv_buffer_size(size_t size) override { m_recv_buffer->resize(size); }
    void set_timeout(int duration) override { m_timeout = duration; }
    void set_nodelay(int flag) override { set_no_delay(m_socket, flag); }

    /**
     * @brief: 发送数据
     *  luabus协议：[len][data]
     *  DxClient协议：[data] -> [DxHead][DxBody] data中已经包含有了上层打包好的head
     */
    void send(const void* data, size_t data_len) override;

    /**
     * @brief: 多块buffer合并为一个buffer发送（利用stream的概念节省一次内存中的多块buffer合并操作）
     */
    void sendv(const sendv_item items[], int count) override;

    /**
     * @brief: raw发送
     */
    void stream_send(const char* data, size_t data_len);

#ifdef _MSC_VER
    void on_complete(WSAOVERLAPPED* ovl) override;
#endif

#if defined(__linux) || defined(__APPLE__)
    void on_can_recv(size_t max_len, bool is_eof) override { do_recv(max_len, is_eof); }
    void on_can_send(size_t max_len, bool is_eof) override;
#endif

    void do_send(size_t max_len, bool is_eof);
    void do_recv(size_t max_len, bool is_eof);

    void dispatch_package();
    void on_error(const char err[]);
    void on_connect(bool ok, const char reason[]);

    int token = 0;
    socket_mgr_impl* m_mgr = nullptr;
    eproto_type     m_proto_type = eproto_type::proto_rpc;
    socket_t m_socket = INVALID_SOCKET;
    std::shared_ptr<io_buffer> m_recv_buffer = std::make_shared<io_buffer>();
    std::shared_ptr<io_buffer> m_send_buffer = std::make_shared<io_buffer>();

    std::string m_node_name;
    std::string m_service_name;
    struct addrinfo* m_addr = nullptr;
    struct addrinfo* m_next = nullptr;
    char m_ip[INET6_ADDRSTRLEN];
    int m_timeout = -1;

    int64_t m_last_recv_time = 0;
    int64_t m_connecting_time = 0;

#ifdef _MSC_VER
    LPFN_CONNECTEX m_connect_func = nullptr;
    WSAOVERLAPPED m_send_ovl;
    WSAOVERLAPPED m_recv_ovl;
    int m_ovl_ref = 0;
#endif

    std::function<void(int, eproto_type)> m_accept_cb = nullptr;
    std::function<void(const char*)> m_error_cb = nullptr;
    std::function<void(char*, size_t)> m_package_cb = nullptr;
    std::function<void(bool, const char*)> m_connect_cb = nullptr;
};
