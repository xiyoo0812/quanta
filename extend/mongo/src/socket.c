#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <string.h>

#include <errno.h>

#if defined(_WIN32) || defined(_WIN64)

#define _WIN32_WINNT 0x0501

#include <winsock2.h>
#include <ws2tcpip.h>

static void	
init_winsock() {
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2,2), &wsaData);
}

#define close(fd) closesocket(fd)

#else

#include <netdb.h>
#include <unistd.h>
#define INVALID_SOCKET (-1)

static void	
init_winsock() {
}

#endif

#ifndef MSG_WAITALL
#define MSG_WAITALL 0
#endif

#define LOCALBUFFER 65535

static int
lopen(lua_State *L) {
    const char * host = luaL_checkstring(L,1);
    int port = luaL_checkinteger(L,2);

    char port_str[32];
    int status;

    struct addrinfo ai_hints;
    struct addrinfo *ai_list = NULL;
    struct addrinfo *ai_ptr = NULL;

    sprintf( port_str, "%d", port );

    memset( &ai_hints, 0, sizeof( ai_hints ) );
    ai_hints.ai_family = AF_UNSPEC;
    ai_hints.ai_socktype = SOCK_STREAM;
    ai_hints.ai_protocol = IPPROTO_TCP;

    status = getaddrinfo( host, port_str, &ai_hints, &ai_list );
    if ( status != 0 ) {
        return 0;
    }
    int sock=INVALID_SOCKET;
    for	( ai_ptr = ai_list;	ai_ptr != NULL;	ai_ptr = ai_ptr->ai_next ) {
        sock = socket( ai_ptr->ai_family, ai_ptr->ai_socktype, ai_ptr->ai_protocol );
        if ( sock == INVALID_SOCKET	) {
            continue;
        }
        
        status = connect( sock,	ai_ptr->ai_addr, ai_ptr->ai_addrlen	);
        if ( status	!= 0 ) {
            close(sock);
            sock = INVALID_SOCKET;
            continue;
        }
        break;
    }

    freeaddrinfo( ai_list );

    if (sock != INVALID_SOCKET) {
        lua_pushinteger(L, sock);
        return 1;
    }

    return 0;
}

static int
lclose(lua_State *L) {
    int sock = luaL_checkinteger(L, 1);
    close(sock);

    return 0;
}

static int
lread(lua_State *L) {
    int fd = luaL_checkinteger(L,1);
    int sz = luaL_checkinteger(L,2);
    char tmp[LOCALBUFFER];
    void * buffer = tmp;
    if (sz > LOCALBUFFER) {
        buffer = lua_newuserdata(L, sz);
    }
    char * ptr   = buffer;
    int read_sz  = sz;
    int sock_err = 0;
    for (;;) {
        int bytes = recv(fd, ptr, read_sz, MSG_WAITALL);
        // 本轮循环发送失败
        if (bytes < 0) {
            sock_err = errno;
            switch (sock_err) {
            case EAGAIN:
            case EINTR:
                continue;
            }

            lua_pushinteger(L, sock_err);
            return 1;
        }

        // 本轮循环没有发送任何数据（大概率是网络端了）
        if (bytes == 0) {
            sock_err = errno;

            lua_pushinteger(L, sock_err);
            return 1;
        }

        // 还有数据需要发送
        if (bytes < read_sz) {
            ptr += bytes;
            read_sz -= bytes;
            continue;
        }

        // 全部数据发送完成
        lua_pushinteger(L, sock_err);
        lua_pushlstring(L, buffer, sz);
        return 2;
    }
}

static int
lwrite(lua_State *L) {
    int sock = luaL_checkinteger(L,1);
    size_t sz  = 0;
    int    sock_err = 0;
    const char *buffer = luaL_checklstring(L, 2, &sz);
    for (;;) {
        int bytes = send(sock, buffer, sz, 0);
        
        // 发送出错
        if (bytes < 0) {
            sock_err = errno;
            switch (sock_err) {
            case EAGAIN:
            case EINTR:
                continue;
            }
        }

        // 发送失败（未能完整发送）
        if (bytes != sz) {
            sock_err = errno;

            lua_pushinteger(L,sock_err);
            return 1;
        }
        break;
    }

    lua_pushinteger(L,sock_err);
    return 1;
}

#ifdef _MSC_VER
#define LUAMSOCKET_API _declspec(dllexport)
#else
#define LUAMSOCKET_API 
#endif

LUAMSOCKET_API int
luaopen_msocket(lua_State *L) {
    init_winsock();
    luaL_checkversion(L);
    luaL_Reg l[] ={
        { "open", lopen },
        { "close", lclose },
        { "read", lread },
        { "write", lwrite },
        { NULL, NULL },
    };

    luaL_newlib(L,l);

    return 1;
}
