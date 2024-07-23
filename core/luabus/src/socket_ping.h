#pragma once
#include <chrono>
#include "socket_helper.h"

#ifdef WIN32
#define getpid _getpid
#endif

#define ICMP_ECHO 8

using namespace std::chrono;

struct icmp_header
{
    unsigned char type;
    unsigned char code;
    unsigned short cksum;
    unsigned short id;
    unsigned short seq;
    unsigned int choose;
};

uint16_t checksum(const uint16_t* data, size_t size) {
    long sum = 0;
    while (size > 1) {
        sum += *data++;
        size -= sizeof(unsigned short);
    }
    if (size)
        sum += *(unsigned char*)data;
    while (sum >> 16)
        sum = (sum & 0xffff) + (sum >> 16);
    return ~sum;
}

inline int socket_ping(lua_State* L, const char* ip, uint32_t times) {
    socket_t fd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
    if (fd <= 0) {
        lua_pushnumber(L, -1);
        return 1;
    }
    socklen_t addr_len = 0;
    sockaddr_storage addr;
    make_ip_addr(&addr, &addr_len, ip, 0);

    icmp_header icmp_header;;
    icmp_header.seq = 0;
    icmp_header.code = 0;
    icmp_header.cksum = 0;
    icmp_header.id = getpid();
    icmp_header.type = ICMP_ECHO;
    icmp_header.cksum = checksum((uint16_t*)&icmp_header, sizeof(icmp_header));

    int timeout = 1000;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    char buff[UCHAR_MAX];
    if (times == 0) times = 1;
    auto start_time = high_resolution_clock::now();
    for (uint32_t i = 0; i < times; ++i) {
        int send_len = sendto(fd, (const char*)&icmp_header, sizeof(icmp_header), 0, (sockaddr*)&addr, addr_len);
        if (send_len == SOCKET_ERROR) {
            lua_pushnumber(L, 0);
            closesocket(fd);
            return 1;
        }
        int recv_len = recvfrom(fd, buff, UCHAR_MAX, 0, (sockaddr*)&addr, &addr_len);
        if (recv_len == SOCKET_ERROR) {
            lua_pushnumber(L, 0);
            closesocket(fd);
            return 1;
        }
    }
    auto end_time = high_resolution_clock::now();
    auto elapsed = duration_cast<microseconds>(end_time - start_time).count();
    lua_pushnumber(L, elapsed / times / 1000);
    return 1;
}
