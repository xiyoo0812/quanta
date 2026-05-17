#pragma once
#include "socket_helper.h"

inline bool resolver_ip(sockaddr* addr, std::string domain, int port) {
    struct addrinfo hints = {
        .ai_flags = AI_CANONNAME,
        .ai_family = AF_UNSPEC,
        .ai_socktype = SOCK_STREAM,
        .ai_protocol = 0,  /* any protocol */
    };
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
        return 1;
    }
    if (connect(sock_fd, &remote_addr, sizeof(struct sockaddr_in)) != 0) {
        lua_pushstring(L, "127.0.0.1");
        closesocket(sock_fd);
        return 1;
    }
    socklen_t len = sizeof(struct sockaddr_in);
    getsockname(sock_fd, (struct sockaddr*)&local_addr, &len);
    char* local_ip = inet_ntoa(local_addr.sin_addr);
    lua_pushstring(L, local_ip ? local_ip : "127.0.0.1");
    closesocket(sock_fd);
    return 1;
}

inline int gethostbydomain(lua_State* L, std::string domain) {
    struct addrinfo hints = {
        .ai_flags = AI_CANONNAME,
        .ai_family = AF_UNSPEC,
        .ai_socktype = SOCK_STREAM,
        .ai_protocol = 0,  /* any protocol */
    };
    struct addrinfo *result, *result_pointer;
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
    size_t idx = 1;
#ifdef WIN32
    ULONG len = 0;
    GetAdaptersInfo(nullptr, &len);
    PIP_ADAPTER_INFO adapter = (PIP_ADAPTER_INFO)::GlobalAlloc(GPTR, len);
    if (!adapter) return 0;
    if (GetAdaptersInfo(adapter, &len) == ERROR_SUCCESS) {
        lua_createtable(L, 4, 0);
        for (PIP_ADAPTER_INFO cur = adapter; cur != nullptr; cur = cur->Next) {
            in_addr addr;
            lua_createtable(L, 0, 3);
            lua_pushstring(L, cur->AdapterName);
            lua_setfield(L, -2, "name");
            addr.S_un.S_addr = ::inet_addr(cur->IpAddressList.IpAddress.String);
            lua_pushstring(L, ::inet_ntoa(addr));
            lua_setfield(L, -2, "ip");
            addr.S_un.S_addr = ::inet_addr(cur->IpAddressList.IpMask.String);
            lua_pushstring(L, ::inet_ntoa(addr));
            lua_setfield(L, -2, "mask");
            lua_seti(L, -2, idx++);
        }
        ::GlobalFree(adapter);
        return 1;
    }
    ::GlobalFree(adapter);
    return 0;
#else
    struct ifaddrs* ifaddr;
    if (getifaddrs(&ifaddr) == -1) return 0;
    lua_createtable(L, 4, 0);
    for (auto* ifa = ifaddr; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
        lua_createtable(L, 0, 3);
        lua_pushstring(L, ifa->ifa_name);
        lua_setfield(L, -2, "name");
        sockaddr_in* ip = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
        lua_pushstring(L, ::inet_ntoa(ip->sin_addr));
        lua_setfield(L, -2, "ip");
        sockaddr_in* mask = reinterpret_cast<sockaddr_in*>(ifa->ifa_netmask);
        lua_pushstring(L, ::inet_ntoa(mask->sin_addr));
        lua_setfield(L, -2, "mask");
        lua_seti(L, -2, idx++);
    }
    freeifaddrs(ifaddr);
    return 1;
#endif
}