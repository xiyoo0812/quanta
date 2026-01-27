#pragma once

#include "socket_helper.h"

using namespace luakit;

enum class link_status : uint8_t {
    LINK_INIT       = 0,
    LINK_CONNECTING = 1,
    LINK_CONNECTED  = 2,
    LINK_CLOSING    = 3,
    LINK_CLOSED     = 4,
};

// 协议类型
enum class proto_type : uint8_t {
    PROTO_PB        = 0,    // pb协议，pb
    PROTO_RPC       = 1,    // rpc协议，rpc
    PROTO_TEXT      = 2,    // text协议，mysql/mongo/http/wss/redis
    PROTO_MAX       = 4,    // max
};

// 协议掩码
enum class proto_flag : uint32_t {
    FLAG_REQ        = 1,    // 协议请求标记
    FLAG_RES        = 2,    // 协议回执/通知标记
    FLAG_ERR        = 3,    // 协议转发错误标记
    FLAG_CRYPT      = 4,    // 协议加密标记
    FLAG_ZIP        = 8,    // 协议压缩标记
};

using enum link_status;
using enum proto_type;
using enum proto_flag;

struct sendv_item {
    const void* data;
    size_t len;
};

struct socket_object {
    virtual ~socket_object() {};
    virtual bool update(int64_t now) = 0;
    virtual int get_sendbuf_size() { return 0; }
    virtual int get_recvbuf_size() { return 0; }
    virtual void close() { m_link_status = LINK_CLOSED; };
    virtual bool get_remote_ip(std::string& ip) = 0;
    virtual void connect(const char ip[], int port, int timeout) { }
    virtual void set_timeout(int duration) { }
    virtual void set_nodelay(int flag) { }
    virtual bool send(const void* data, size_t data_len) { return false; }
    virtual bool sendv(const sendv_item items[], int count) { return false; };
    virtual void set_kind(uint32_t kind) { m_kind = kind; }
    virtual void set_token(uint32_t token) { m_token = token; }
    virtual void set_codec(codec_base* codec) { m_codec = codec; }
    virtual void set_accept_callback(const std::function<void(uint32_t)> cb) { }
    virtual void set_connect_callback(const std::function<void(bool, const char*)> cb) { }
    virtual void set_error_callback(const std::function<void(const char*)> cb) { }
    virtual void set_package_callback(const std::function<void(slice*)> cb) { }
    virtual bool is_same_kind(uint32_t kind) { return m_kind == kind; }

#ifdef IO_IOCP
    virtual void on_complete(WSAOVERLAPPED* ovl) = 0;
#else
    virtual void on_can_recv(size_t data_len = UINT_MAX, bool is_eof = false) {};
    virtual void on_can_send(size_t data_len = UINT_MAX, bool is_eof = false) {};
#endif

protected:
    uint32_t m_kind = 0;
    uint32_t m_token = 0;
    codec_base* m_codec = nullptr;
    link_status m_link_status = LINK_INIT;
};

class socket_mgr {
public:
    socket_mgr();
    ~socket_mgr();

    bool setup(int max_connection);

#ifdef IO_IOCP
    bool get_socket_funcs();
#endif

    int wait(int64_t now, int timeout);

    int listen(std::string& err, const char ip[], int port);
    int connect(std::string& err, const char ip[], int port, int timeout);

    int get_sendbuf_size(uint32_t token);
    int get_recvbuf_size(uint32_t token);
    void set_timeout(uint32_t token, int duration);
    void set_nodelay(uint32_t token, int flag);
    bool send(uint32_t token, const void* data, size_t data_len);
    bool sendv(uint32_t token, const sendv_item items[], int count);
    void broadcast(size_t kind, const void* data, size_t data_len);
    void broadgroup(std::vector<uint32_t>& groups, const void* data, size_t data_len);
    void close(uint32_t token);
    void set_codec(uint32_t token, codec_base* codec);
    bool get_remote_ip(uint32_t token, std::string& ip);
    void set_accept_callback(uint32_t token, const std::function<void(uint32_t)> cb);
    void set_error_callback(uint32_t token, const std::function<void(const char*)> cb);
    void set_connect_callback(uint32_t token, const std::function<void(bool, const char*)> cb);
    void set_package_callback(uint32_t token, const std::function<void(slice*)> cb);

    bool watch_listen(socket_t fd, socket_object* object);
    bool watch_accepted(socket_t fd, socket_object* object);
    bool watch_connecting(socket_t fd, socket_object* object);
    bool watch_connected(socket_t fd, socket_object* object);
    bool watch_send(socket_t fd, socket_object* object, bool enable);
    uint32_t accept_stream(uint32_t ltoken, socket_t fd, const char ip[]);

    void increase_count() { m_count++; }
    void decrease_count() { m_count--; }
    bool is_full() { return m_count >= m_max_count; }

private:
#ifdef IO_IOCP
    LPFN_ACCEPTEX m_accept_func = nullptr;
    LPFN_CONNECTEX m_connect_func = nullptr;
    LPFN_GETACCEPTEXSOCKADDRS m_addrs_func = nullptr;
    HANDLE m_handle = INVALID_HANDLE_VALUE;
    std::vector<OVERLAPPED_ENTRY> m_events;
#endif

#ifdef IO_EPOLL
    int m_handle = -1;
    std::vector<epoll_event> m_events;
#endif

#ifdef IO_KQUEUE
    int m_handle = -1;
    std::vector<struct kevent> m_events;
#endif

#ifdef IO_POLL
    std::vector<struct pollfd> m_events;
    std::unordered_map<socket_t, short> m_event_map;
    bool poll_event_ctl(socket_t fd, short fevts);
#endif

    socket_object* get_object(uint32_t token) {
        auto it = m_objects.find(token);
        if (it != m_objects.end()) {
            return it->second;
        }
        return nullptr;
    }

    uint32_t new_token() {
        while (++m_token == 0 || m_objects.contains(m_token)) {}
        return m_token;
    }

    uint32_t m_count = 0;
    uint32_t m_token = 0;
    uint32_t m_max_count = 0;
    std::unordered_map<uint32_t, socket_object*> m_objects;
};
