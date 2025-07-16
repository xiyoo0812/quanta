#pragma once
#include "socket_helper.h"

inline bool resolver_ip(sockaddr* addr, std::string domain, int port) {
    struct addrinfo hints;
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_UNSPEC;
    hints.ai_flags = AI_CANONNAME;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;  /* any protocol */
    struct addrinfo* result, * result_pointer;
    if (getaddrinfo(domain.c_str(), std::to_string(port).c_str(), &hints, &result) == 0) {
        for (result_pointer = result; result_pointer != NULL; result_pointer = result_pointer->ai_next) {
            if (AF_INET == result_pointer->ai_family) {
                memcpy(addr, result_pointer->ai_addr, result_pointer->ai_addrlen);
                freeaddrinfo(result);
                return true;
            }
        }
        freeaddrinfo(result);
    }
    return false;
}

inline int gethostip(lua_State* L) {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    struct sockaddr remote_addr;
    struct sockaddr_in local_addr = {};
    if (!resolver_ip(&remote_addr, "1.1.1.1", 53)) {
        lua_pushstring(L, "127.0.0.1");
        lua_pushlstring(L, (char*)&local_addr.sin_addr.s_addr, 4);
        return 2;
    }
    if (connect(sock_fd, &remote_addr, sizeof(struct sockaddr_in)) != 0) {
        lua_pushstring(L, "127.0.0.1");
        lua_pushlstring(L, (char*)&local_addr.sin_addr.s_addr, 4);
        closesocket(sock_fd);
        return 2;
    }
    socklen_t len = sizeof(struct sockaddr_in);
    getsockname(sock_fd, (struct sockaddr*)&local_addr, &len);
    char* local_ip = inet_ntoa(local_addr.sin_addr);
    lua_pushstring(L, local_ip ? local_ip : "127.0.0.1");
    lua_pushlstring(L, (char*)&local_addr.sin_addr.s_addr, 4);
    closesocket(sock_fd);
    return 2;
}

inline int gethostbydomain(lua_State* L, std::string domain) {
    struct addrinfo hints;
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_UNSPEC;
    hints.ai_flags = AI_CANONNAME;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;  /* any protocol */
    struct addrinfo* result, * result_pointer;
    if (getaddrinfo(domain.c_str(), NULL, &hints, &result) == 0) {
        std::vector<std::string> addrs;
        for (result_pointer = result; result_pointer != NULL; result_pointer = result_pointer->ai_next) {
            if (AF_INET == result_pointer->ai_family) {
                char ipaddr[32] = {0};
                if (getnameinfo(result_pointer->ai_addr, result_pointer->ai_addrlen, ipaddr, sizeof(ipaddr), nullptr, 0, NI_NUMERICHOST) == 0) {
                    addrs.push_back(ipaddr);
                }
            }
        }
        freeaddrinfo(result);
        return luakit::variadic_return(L, addrs);
    }
    return 0;
}

inline int get_ipconfig(lua_State* L) {
#ifdef WIN32
    ULONG len = 0;
    GetAdaptersInfo(nullptr, &len);
    PIP_ADAPTER_INFO adapter = (PIP_ADAPTER_INFO)::GlobalAlloc(GPTR, len);
    if (GetAdaptersInfo(adapter, &len) == ERROR_SUCCESS) {
        if (adapter) {
            in_addr addr;
            addr.S_un.S_addr = ::inet_addr(adapter->IpAddressList.IpAddress.String);
            lua_pushstring(L, ::inet_ntoa(addr));
            addr.S_un.S_addr = ::inet_addr(adapter->IpAddressList.IpMask.String);
            lua_pushstring(L, ::inet_ntoa(addr));
            return 2;
        }
    }
    return 0;
#else
    struct ifaddrs* ifaddr;
    if (getifaddrs(&ifaddr) != -1) {
        for (auto* ifa = ifaddr; ifa; ifa = ifa->ifa_next) {
            if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
            sockaddr_in* ip = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
            lua_pushstring(L, ip ? ::inet_ntoa(ip->sin_addr) : "127.0.0.1");
            sockaddr_in* mask = reinterpret_cast<sockaddr_in*>(ifa->ifa_netmask);
            lua_pushstring(L, mask ? ::inet_ntoa(mask->sin_addr) : "255.255.255.0");
            return 2;
        }
        freeifaddrs(ifaddr);
    }
    return 0;
#endif
}