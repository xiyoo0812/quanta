#pragma once
#include "socket_helper.h"

inline bool resolver_ip(sockaddr* addr, std::string domain, int port) {
#ifdef SCE_API
    int memid = sceNetPoolCreate(__FUNCTION__, 4 * 1024, 0);
    if (memid < 0) return false;
    int rid = sceNetResolverCreate("resolver", memid, 0);
    if (rid < 0) return false;
    sockaddr_in* sin = (sockaddr_in*)addr;
    memset(sin, 0, sizeof(sockaddr_in));
    sin->sin_family = SCE_NET_AF_INET;
    sin->sin_port = htons(port);
    sin->sin_len = sizeof(sockaddr_in);
    if (sceNetResolverStartNtoa(rid, domain.c_str(), &sin->sin_addr, 0, 0, 0) < 0) return 0;
    sceNetResolverDestroy(rid);
    sceNetPoolDestroy(memid);
    return true;
#else
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
#endif
}

inline int gethostip(lua_State* L) {
#ifdef SCE_API
    SceNetCtlInfo i;
    if (sceNetCtlGetInfo(SCE_NET_CTL_INFO_IP_ADDRESS, &i) < 0) {
        return 0;
    }
    lua_pushstring(L, i.ip_address);
    return 1;
#else
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    struct sockaddr remote_addr;
    struct sockaddr_in local_addr;
    if (!resolver_ip(&remote_addr, "1.1.1.1", 53)) {
        return 0;
    }
    if (connect(sock_fd, &remote_addr, sizeof(struct sockaddr_in)) != 0) {
        closesocket(sock_fd);
        return 0;
    }
    socklen_t len = sizeof(struct sockaddr_in);
    getsockname(sock_fd, (struct sockaddr*)&local_addr, &len);
    char* local_ip = inet_ntoa(local_addr.sin_addr);
    closesocket(sock_fd);
    if (local_ip) {
        lua_pushstring(L, local_ip);
        return 1;
    }
    return 0;
#endif
}

inline int gethostbydomain(lua_State* L, std::string domain) {
#ifdef SCE_API
    int memid = sceNetPoolCreate(__FUNCTION__, 4 * 1024, 0);
    if (memid < 0) return 0;
    int rid = sceNetResolverCreate("resolver", memid, 0);
    if (rid < 0 ) return 0;
    SceNetResolverInfo rinfo;
    std::vector<std::string> addrs;
    char tmp[SCE_NET_INET_ADDRSTRLEN];
    if (sceNetResolverStartNtoaMultipleRecords(rid, domain.c_str(), &rinfo, 0, 0, 0) < 0) return 0;
    for (int i = 0; i < rinfo.records; i++) {
        if (AF_INET == rinfo.addrs[i].af) {
            addrs.push_back(sceNetInetNtop(SCE_NET_AF_INET, &rinfo.addrs[i].un.addr, tmp, sizeof(tmp)));
        }
    }
    sceNetResolverDestroy(rid);
    sceNetPoolDestroy(memid);
    return luakit::variadic_return(L, addrs);
#else
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
#endif
}