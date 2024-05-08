#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_helper.h"

enum class rpc_type : char {
    remote_call,
    transfer_call,
    forward_target,
    forward_master,
    forward_broadcast,
    forward_hash,
};

const int MAX_SERVICE_GROUP = UCHAR_MAX + 1;

struct service_node {
    uint32_t id = 0;
    uint32_t token = 0;
    uint16_t group = 0;
    uint16_t region = 0;
};

#pragma pack(1)
struct router_header {
    uint32_t len = 0;
    uint8_t  context = 0;       //高4位为msg_id，低4位为flag
    uint32_t session_id = 0;
    uint32_t target_id = 0;
};
struct transfer_header {
    uint32_t len = 0;
    uint8_t  context = 0;       //高4位为msg_id，低4位为flag
    uint32_t session_id = 0;
    uint32_t target_id = 0;
    uint8_t  service_id = 0;
};
#pragma pack()

struct service_list {
    service_node master;
    std::vector<service_node> nodes;
};

class socket_router
{
public:
    socket_router(std::shared_ptr<socket_mgr>& mgr) : m_mgr(mgr){ }

    uint32_t get_route_count();
    void erase(uint32_t node_id);
    uint32_t choose_master(uint32_t service_id);
    uint32_t map_token(uint32_t node_id, uint32_t token);
    bool do_forward_hash(router_header* header, char* data, size_t data_len);
    bool do_forward_target(router_header* header, char* data, size_t data_len);
    bool do_forward_master(router_header* header, char* data, size_t data_len);
    bool do_forward_broadcast(router_header* header, uint32_t source, char* data, size_t data_len, size_t& broadcast_num);

private:
    size_t m_route_count = 0;
    std::shared_ptr<socket_mgr> m_mgr;
    std::array<service_list, MAX_SERVICE_GROUP> m_services;
};

