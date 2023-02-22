#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_router.h"

struct lua_socket_mgr final
{
public:
    ~lua_socket_mgr(){}
    bool setup(lua_State* L, int max_fd);
    int wait(int ms) { return m_mgr->wait(ms); }
    uint32_t map_token(uint32_t node_id, uint32_t token);
    int listen(lua_State* L, const char* ip, int port);
    int connect(lua_State* L, const char* ip, const char* port, int timeout);

private:
    lua_State* m_lvm = nullptr;
    std::shared_ptr<socket_mgr> m_mgr;
    std::shared_ptr<socket_router> m_router;
};

