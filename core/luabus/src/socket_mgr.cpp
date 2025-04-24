#include "stdafx.h"
#include "socket_helper.h"
#include "socket_mgr.h"
#include "socket_stream.h"
#include "socket_listener.h"

#ifdef IO_IOCP
#pragma comment(lib, "Ws2_32.lib")
#endif

socket_mgr::socket_mgr() {
#ifdef IO_IOCP
    WORD    wVersion = MAKEWORD(2, 2);
    WSADATA wsaData;
    WSAStartup(wVersion, &wsaData);
#endif
}

socket_mgr::~socket_mgr() {
    m_events.clear();
    for (auto& node : m_objects) {
        delete node.second;
    }

#ifdef IO_IOCP
    if (m_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(m_handle);
        m_handle = INVALID_HANDLE_VALUE;
    }
    WSACleanup();
#endif

#if defined(IO_EPOLL) || defined(IO_KQUEUE)
    if (m_handle != -1) {
        ::close(m_handle);
        m_handle = -1;
    }
#endif
}

bool socket_mgr::setup(int max_connection) {
#ifdef IO_IOCP
    m_handle = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
    if (m_handle == INVALID_HANDLE_VALUE)
        return false;

    if (!get_socket_funcs())
        return false;
#endif

#ifdef IO_EPOLL
    m_handle = epoll_create(max_connection);
    if (m_handle == -1)
        return false;
#endif

#ifdef IO_KQUEUE
    m_handle = kqueue();
    if (m_handle == -1)
        return false;
#endif

    m_max_count = max_connection;
    m_events.resize(max_connection);

    return true;
}

#ifdef IO_IOCP
bool socket_mgr::get_socket_funcs() {
    bool result = false;
    int ret = 0;
    socket_t fd = INVALID_SOCKET;
    DWORD bytes = 0;
    GUID func_guid = WSAID_ACCEPTEX;

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if(fd == INVALID_SOCKET) goto Exit0;

    bytes = 0;
    func_guid = WSAID_ACCEPTEX;
    ret = WSAIoctl(fd, SIO_GET_EXTENSION_FUNCTION_POINTER, &func_guid, sizeof(func_guid), &m_accept_func, sizeof(m_accept_func), &bytes, nullptr, nullptr);
    if (ret == SOCKET_ERROR) goto Exit0;

    bytes = 0;
    func_guid = WSAID_CONNECTEX;
    ret = WSAIoctl(fd, SIO_GET_EXTENSION_FUNCTION_POINTER, &func_guid, sizeof(func_guid), &m_connect_func, sizeof(m_connect_func), &bytes, nullptr, nullptr);
    if (ret == SOCKET_ERROR) goto Exit0;

    bytes = 0;
    func_guid = WSAID_GETACCEPTEXSOCKADDRS;
    ret = WSAIoctl(fd, SIO_GET_EXTENSION_FUNCTION_POINTER, &func_guid, sizeof(func_guid), &m_addrs_func, sizeof(m_addrs_func), &bytes, nullptr, nullptr);
    if (ret == SOCKET_ERROR) goto Exit0;

    result = true;
Exit0:
    if (fd != INVALID_SOCKET) {
        closesocket(fd);
        fd = INVALID_SOCKET;
    }
    return result;
}
#endif

int socket_mgr::wait(int64_t now, int timeout) {
    auto it = m_objects.begin(), end = m_objects.end();
    while (it != end) {
        socket_object* object = it->second;
        if (!object->update(now)) {
#ifdef IO_POLL
            poll_event_ctl(it->first, 0);
#endif
            it = m_objects.erase(it);
            delete object;
            continue;
        }
        ++it;
    }
    int escape = luakit::steady_ms() - now;
    timeout = escape >= timeout ? 0 : timeout - escape;
#ifdef IO_IOCP
    ULONG event_count = 0;
    int ret = GetQueuedCompletionStatusEx(m_handle, &m_events[0], (ULONG)m_events.size(), &event_count, (DWORD)timeout, false);
    if (ret) {
        for (ULONG i = 0; i < event_count; i++) {
            OVERLAPPED_ENTRY& oe = m_events[i];
            auto object = (socket_object*)oe.lpCompletionKey;
            object->on_complete(oe.lpOverlapped);
        }
    }
#endif

#ifdef IO_POLL
    int event_count = 0;
    int ret = ::poll(&m_events[0], (int)m_events.size(), timeout);
    if (ret == SOCKET_ERROR) return event_count;
    for (auto& pfd : m_events) {
        if (pfd.revents != 0) {
            event_count++;
            auto object = get_object(pfd.fd);
            if (object) {
                if (pfd.revents & POLLIN) object->on_can_recv();
                if (pfd.revents & POLLOUT) object->on_can_send();
            }
        }
    }
#endif

#ifdef IO_EPOLL
    int event_count = ::epoll_wait(m_handle, &m_events[0], (int)m_events.size(), timeout);
    for (int i = 0; i < event_count; i++) {
        epoll_event& ev = m_events[i];
        auto object = (socket_object*)ev.data.ptr;
        if (ev.events & EPOLLIN) object->on_can_recv();
        if (ev.events & EPOLLOUT) object->on_can_send();
    }
#endif

#ifdef IO_KQUEUE
    timespec time_wait;
    time_wait.tv_sec = timeout / 1000;
    time_wait.tv_nsec = (timeout % 1000) * 1000000;
    int event_count = kevent(m_handle, nullptr, 0, &m_events[0], (int)m_events.size(), timeout >= 0 ? &time_wait : nullptr);
    for (int i = 0; i < event_count; i++) {
        struct kevent& ev = m_events[i];
        auto object = (socket_object*)ev.udata;
        if (ev.filter == EVFILT_READ) object->on_can_recv((size_t)ev.data, (ev.flags & EV_EOF) != 0);
        else if (ev.filter == EVFILT_WRITE) object->on_can_send((size_t)ev.data, (ev.flags & EV_EOF) != 0);
    }
#endif

    return (int)event_count;
}

int socket_mgr::listen(std::string& err, const char ip[], int port) {
    socket_t fd = INVALID_SOCKET;
#ifdef IO_IOCP
    auto* listener = new socket_listener(this, m_accept_func, m_addrs_func);
#else
    auto* listener = new socket_listener(this);
#endif
    socklen_t addr_len = 0;
    sockaddr_storage addr;
    int ret = make_ip_addr(&addr, &addr_len, ip, port);
    if(!ret) goto Exit0;

    fd = socket(addr.ss_family, SOCK_STREAM, IPPROTO_IP);
    if(fd == INVALID_SOCKET) goto Exit0;

    set_no_block(fd);
    set_reuseaddr(fd);
    set_close_on_exec(fd);

    // macOSX require addr_len to be the real len (ipv4/ipv6)
    ret = ::bind(fd, (sockaddr*)&addr, (int)addr_len);
    if(ret == SOCKET_ERROR) goto Exit0;

    ret = ::listen(fd, 200);
    if(ret == SOCKET_ERROR) goto Exit0;

    if (watch_listen(fd, listener) && listener->setup(fd)) {
        int token = new_token();
        listener->set_kind(token);
        listener->set_token(token);
        m_objects[token] = listener;
        return token;
    }

Exit0:
    get_error_string(err, get_socket_error());
    delete listener;
    if (fd != INVALID_SOCKET) {
        closesocket(fd);
        fd = INVALID_SOCKET;
    }
    return 0;
}

int socket_mgr::connect(std::string& err, const char ip[], int port, int timeout) {
    if (is_full()) {
        err = "too-many-connection";
        return 0;
    }
    socket_t fd = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
    if(fd == INVALID_SOCKET) {
        err = "socket-create-failed";
        return 0;
    }
#ifdef IO_IOCP
    socket_stream* stm = new socket_stream(this, fd, m_connect_func);
#else
    socket_stream* stm = new socket_stream(this, fd);
#endif
    uint32_t token = new_token();
    stm->connect(ip, port, timeout);
    stm->set_token(token);
    m_objects[token] = stm;
    return token;
}

void socket_mgr::set_timeout(uint32_t token, int duration) {
    auto node = get_object(token);
    if (node) {
        node->set_timeout(duration);
    }
}

void socket_mgr::set_nodelay(uint32_t token, int flag) {
    auto node = get_object(token);
    if (node) {
        node->set_nodelay(flag);
    }
}

void socket_mgr::set_codec(uint32_t token, codec_base* codec) {
    auto node = get_object(token);
    if (node) {
        node->set_codec(codec);
    }
}

void socket_mgr::send(uint32_t token, const void* data, size_t data_len) {
    auto node = get_object(token);
    if (node) {
        node->send(data, data_len);
    }
}

void socket_mgr::sendv(uint32_t token, const sendv_item items[], int count) {
    auto node = get_object(token);
    if (node) {
        node->sendv(items, count);
    }
}

void socket_mgr::broadcast(size_t kind, const void* data, size_t data_len) {
    for(auto node : m_objects) {
        if (node.second->is_same_kind(kind)) {
            node.second->send(data, data_len);
        }
    }
}

void socket_mgr::broadgroup(std::vector<uint32_t>& groups, const void* data, size_t data_len) {
    for(auto token : groups) {
        send(token, data, data_len);
    }
}

void socket_mgr::close(uint32_t token) {
    auto node = get_object(token);
    if (node) {
        node->close();
    }
}

bool socket_mgr::get_remote_ip(uint32_t token, std::string& ip) {
    auto node = get_object(token);
    if (node) {
        return node->get_remote_ip(ip);
    }
    return false;
}

int socket_mgr::get_sendbuf_size(uint32_t token){
    auto node = get_object(token);
    if (node) {
        return node->get_sendbuf_size();
    }
    return 0;
}

int socket_mgr::get_recvbuf_size(uint32_t token){
    auto node = get_object(token);
    if (node) {
        return node->get_recvbuf_size();
    }
    return 0;
}

void socket_mgr::set_accept_callback(uint32_t token, const std::function<void(int)> cb) {
    auto node = get_object(token);
    if (node) {
        node->set_accept_callback(cb);
    }
}

void socket_mgr::set_connect_callback(uint32_t token, const std::function<void(bool, const char*)> cb) {
    auto node = get_object(token);
    if (node) {
        node->set_connect_callback(cb);
    }
}

void socket_mgr::set_package_callback(uint32_t token, const std::function<void(slice*)> cb) {
    auto node = get_object(token);
    if (node) {
        node->set_package_callback(cb);
    }
}

void socket_mgr::set_error_callback(uint32_t token, const std::function<void(const char*)> cb) {
    auto node = get_object(token);
    if (node) {
        node->set_error_callback(cb);
    }
}

#ifdef IO_POLL
bool socket_mgr::poll_event_ctl(socket_t fd, short fevts) {
    if (fevts == 0) {
        m_event_map.erase(fd);
    } else {
        m_event_map[fd] = fevts;
    }
    m_events.clear();
    for (const auto [efd, evts] : m_event_map) {
        m_events.emplace_back(pollfd{ efd, evts });
    }
    return true;
}
#endif

bool socket_mgr::watch_listen(socket_t fd, socket_object* object) {
#ifdef IO_IOCP
    return CreateIoCompletionPort((HANDLE)fd, m_handle, (ULONG_PTR)object, 0) == m_handle;
#endif

#ifdef IO_POLL
    return poll_event_ctl(fd, POLLIN);
#endif

#ifdef IO_EPOLL
    epoll_event ev;
    ev.data.ptr = object;
    ev.events = EPOLLIN | EPOLLET;
    return epoll_ctl(m_handle, EPOLL_CTL_ADD, fd, &ev) == 0;
#endif

#ifdef IO_KQUEUE
    struct kevent evt;
    EV_SET(&evt, fd, EVFILT_READ, EV_ADD, 0, 0, object);
    return kevent(m_handle, &evt, 1, nullptr, 0, nullptr) == 0;
#endif
}

bool socket_mgr::watch_accepted(socket_t fd, socket_object* object) {
#ifdef IO_IOCP
    return CreateIoCompletionPort((HANDLE)fd, m_handle, (ULONG_PTR)object, 0) == m_handle;
#endif

#ifdef IO_POLL
    return poll_event_ctl(fd, POLLIN);
#endif

#ifdef IO_EPOLL
    epoll_event ev;
    ev.data.ptr = object;
    ev.events = EPOLLIN | EPOLLET;
    return epoll_ctl(m_handle, EPOLL_CTL_ADD, fd, &ev) == 0;
#endif

#ifdef IO_KQUEUE
    struct kevent evt[2];
    EV_SET(&evt[0], fd, EVFILT_READ, EV_ADD, 0, 0, object);
    EV_SET(&evt[1], fd, EVFILT_WRITE, EV_ADD | EV_DISABLE, 0, 0, object);
    return kevent(m_handle, evt, _countof(evt), nullptr, 0, nullptr) == 0;
#endif
}

bool socket_mgr::watch_connecting(socket_t fd, socket_object* object) {
#ifdef IO_IOCP
    return CreateIoCompletionPort((HANDLE)fd, m_handle, (ULONG_PTR)object, 0) == m_handle;
#endif

#ifdef IO_POLL
    return poll_event_ctl(fd, POLLOUT);
#endif

#ifdef IO_EPOLL
    epoll_event ev;
    ev.data.ptr = object;
    ev.events = EPOLLOUT | EPOLLET;
    return epoll_ctl(m_handle, EPOLL_CTL_ADD, fd, &ev) == 0;
#endif

#ifdef IO_KQUEUE
    struct kevent evt;
    EV_SET(&evt, fd, EVFILT_WRITE, EV_ADD, 0, 0, object);
    return kevent(m_handle, &evt, 1, nullptr, 0, nullptr) == 0;
#endif
}

bool socket_mgr::watch_connected(socket_t fd, socket_object* object) {
#ifdef IO_IOCP
    return true;
#endif

#ifdef IO_POLL
    return poll_event_ctl(fd, POLLIN);
#endif

#ifdef IO_EPOLL
    epoll_event ev;
    ev.data.ptr = object;
    ev.events = EPOLLIN | EPOLLET;
    return epoll_ctl(m_handle, EPOLL_CTL_MOD, fd, &ev) == 0;
#endif

#ifdef IO_KQUEUE
    struct kevent evt[2];
    EV_SET(&evt[0], fd, EVFILT_READ, EV_ADD, 0, 0, object);
    EV_SET(&evt[1], fd, EVFILT_WRITE, EV_ADD | EV_DISABLE, 0, 0, object);
    return kevent(m_handle, evt, _countof(evt), nullptr, 0, nullptr) == 0;
#endif
}

bool socket_mgr::watch_send(socket_t fd, socket_object* object, bool enable) {
#ifdef IO_IOCP
    return true;
#endif

#ifdef IO_POLL
    return poll_event_ctl(fd, POLLIN | (enable ? POLLOUT : 0));
#endif

#ifdef IO_EPOLL
    epoll_event ev;
    ev.data.ptr = object;
    ev.events = EPOLLIN | (enable ? EPOLLOUT : 0) | EPOLLET;
    return epoll_ctl(m_handle, EPOLL_CTL_MOD, fd, &ev) == 0;
#endif

#ifdef IO_KQUEUE
    struct kevent evt;
    EV_SET(&evt, fd, EVFILT_WRITE, EV_ADD | (enable ? 0 : EV_DISABLE), 0, 0, object);
    return kevent(m_handle, &evt, 1, nullptr, 0, nullptr) == 0;
#endif
}

int socket_mgr::accept_stream(uint32_t ltoken, socket_t fd, const char ip[]) {
    auto* stm = new socket_stream(this, fd);
    if (watch_accepted(fd, stm) && stm->accept_socket(fd, ip)) {
        uint32_t token = new_token();
        stm->set_kind(ltoken);
        stm->set_token(token);
        m_objects[token] = stm;
        return token;
    }
    delete stm;
    return 0;
}
