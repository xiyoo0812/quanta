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
    struct sockaddr_in local_addr;
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