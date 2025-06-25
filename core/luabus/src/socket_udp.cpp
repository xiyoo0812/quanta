#include "stdafx.h"
#include "socket_udp.h"

socket_udp::~socket_udp() {
    close();
}

void socket_udp::close() {
    if (m_fd > 0) {
        if (m_mreq) {
            setsockopt(m_fd, IPPROTO_IP, IP_DROP_MEMBERSHIP, (char*)m_mreq, sizeof(ip_mreq));
            delete m_mreq;
        }
        closesocket(m_fd);
        m_fd = INVALID_SOCKET;
    }
}

bool socket_udp::setup(bool noblock, bool broadcast, bool reuse) {
    socket_t fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd <= 0) {
        return false;
    }
    m_fd = fd;
    if (reuse) set_reuseaddr(fd);
    if (noblock) set_no_block(fd);
    if (broadcast) set_broadcast(fd);
    return true;
}

int socket_udp::bind(lua_State* L, const char* ip, int port) {
    socklen_t addr_len = 0;
    sockaddr_storage addr;
    make_ip_addr(&addr, &addr_len, ip, port);
    if (::bind(m_fd, (sockaddr*)&addr, (int)addr_len) == SOCKET_ERROR) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "udp bind failed!");
        return 2;
    }
    lua_pushboolean(L, true);
    return 1;
}

int socket_udp::add_group(lua_State* L, const char* ip, bool loop) {
    m_mreq = new ip_mreq;
    m_mreq->imr_interface.s_addr = INADDR_ANY;
    inet_pton(AF_INET, ip, &m_mreq->imr_multiaddr);
    if (setsockopt(m_fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, (char*)m_mreq, sizeof(ip_mreq)) < 0) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "udp add_group failed!");
        return 2;
    }
    setsockopt(m_fd, IPPROTO_IP, IP_MULTICAST_LOOP, (char*)&loop, sizeof(loop));
    lua_pushboolean(L, true);
    return 1;
}

int socket_udp::send(lua_State* L, const char* buf, size_t len, const char* ip, int port) {
    socklen_t addr_len = 0;
    sockaddr_storage addr;
    make_ip_addr(&addr, &addr_len, ip, port);
    int send_len = sendto(m_fd, buf, len, 0, (sockaddr*)&addr, sizeof(sockaddr));
    if (send_len == SOCKET_ERROR) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "send failed!");
        lua_pushinteger(L, get_socket_error());
        return 3;
    }
    lua_pushboolean(L, true);
    return 1;
}

int socket_udp::recv(lua_State* L) {
    sockaddr_in addr;
    socklen_t addr_len = (socklen_t)sizeof(addr);
    memset(&addr, 0, sizeof(addr));
    memset(m_recv_buf, 0, SOCKET_UDP_RECV_LEN);
    int recv_len = recvfrom(m_fd, m_recv_buf, SOCKET_UDP_RECV_LEN, 0, (sockaddr*)&addr, &addr_len);
    if (recv_len == SOCKET_ERROR) {
        lua_pushboolean(L, false);
        if (get_socket_error() == WSAEWOULDBLOCK) {
            lua_pushstring(L, "EWOULDBLOCK");
        } else {
            lua_pushstring(L, "recv failed");
        }
        return 2;
    }
    char ip[INET_ADDRSTRLEN];
    get_ip_string(ip, sizeof(ip), &addr);
    lua_pushboolean(L, true);
    lua_pushlstring(L, m_recv_buf, recv_len);
    lua_pushstring(L, ip);
    lua_pushinteger(L, ntohs(addr.sin_port));
    return 4;
}
