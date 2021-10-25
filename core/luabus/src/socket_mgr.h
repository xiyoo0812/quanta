/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2016-11-01, trumanzhao@foxmail.com
*/

#pragma once

#include <memory>
#include <functional>

// 协议类型
enum class eproto_type : int
{
    proto_rpc       = 0,  // rpc协议
    proto_pack      = 1,  // pack协议
    proto_text      = 2,  // text协议
    proto_max       = 3,  // max 
};

struct sendv_item
{
    const void* data;
    size_t len;
};

class socket_mgr
{
public:
    socket_mgr();
    socket_mgr(socket_mgr& other);
    socket_mgr(socket_mgr&& other);
    ~socket_mgr();

    bool setup(int max_connection);
    int wait(int timeout);
    int listen(std::string& err, const char ip[], int port, eproto_type proto_type);
    // 注意: connect总是异步的,需要通过回调函数确认连接成功后,才能发送数据
    int connect(std::string& err, const char node_name[], const char service_name[], int timeout, eproto_type proto_type = eproto_type::proto_rpc);

    void set_send_buffer_size(uint32_t token, size_t size);
    void set_recv_buffer_size(uint32_t token, size_t size);
    void set_timeout(uint32_t token, int duration); // 设置超时时间,默认-1,即永不超时
    void set_nodelay(uint32_t token, int flag); 
    void send(uint32_t token, const void* data, size_t data_len);
    void sendv(uint32_t token, const sendv_item items[], int count);
    void close(uint32_t token);
    bool get_remote_ip(uint32_t token, std::string& ip);

    void set_accept_callback(uint32_t token, const std::function<void(uint32_t, eproto_type)>& cb);
    void set_connect_callback(uint32_t token, const std::function<void(bool, const char*)>& cb);
    void set_package_callback(uint32_t token, const std::function<void(char*, size_t)>& cb);
    void set_error_callback(uint32_t token, const std::function<void(const char*)>& cb);
private:
    std::shared_ptr<class socket_mgr_impl> m_impl;
};

