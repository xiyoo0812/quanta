#pragma once
#include <array>
#include "socket_mgr.h"
#include "socket_helper.h"

enum class rpc_type : uint32_t {
    FORWARD_SELF,
    FORWARD_RELAY,
    FORWARD_TARGET,
    FORWARD_MASTER,
    FORWARD_BROADCAST,
    FORWARD_HASH,
};
using enum rpc_type;

struct service_node {
    uint32_t id = 0;
    uint32_t token = 0;
};

#pragma pack(1)
struct router_header {
    union {
        uint32_t length;
        struct {
            rpc_type type : 4;  //rpc_type 4bit
            uint32_t flag : 4;  //flag 4bit
            uint32_t len : 24;  //24bit(16M)
        };
    };
    uint32_t target_id = 0;
    uint32_t session_id = 0;
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
    socket_router(stdsptr<socket_mgr>& mgr, codec_base* codec) : m_codec(codec), m_mgr(mgr) { }

    uint32_t get_route_count();
    uint32_t choose_master(uint32_t service_id);
    uint32_t map_router(uint32_t node_id, int32_t token);
    void do_forward_hash(uint32_t token, router_header* header, pbyte data, size_t data_len);
    void do_forward_target(uint32_t token, router_header* header, pbyte data, size_t data_len);
    void do_forward_master(uint32_t token, router_header* header, pbyte data, size_t data_len);
    void do_forward_broadcast(uint32_t token, router_header* header, pbyte data, size_t data_len);
    void do_forward_relay(uint8_t service_id, uint32_t token, router_header* header, pbyte data, size_t data_len);

private:
    void on_forward_broadcast(uint32_t token, router_header* header, size_t target_size);
    void on_forward_error(uint32_t token, router_header* header, pbyte data, size_t data_len);

private:
    size_t m_route_count = 0;
    codec_base* m_codec = nullptr;
    stdsptr<socket_mgr> m_mgr = nullptr;
    std::array<service_list, UCHAR_MAX> m_services;
};

