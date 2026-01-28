#pragma once
#include <set>
#include "socket_mgr.h"
#include "socket_helper.h"
#include "socket_router.h"

enum class relay_type : uint32_t {
    RELAY_SELF,
    RELAY_GROUP,
    RELAY_CLIENT,
    RELAY_SERVICE,
    RELAY_BROADCAST,
};
using enum relay_type;

#pragma pack(1)
struct relay_header {
    union {
        uint32_t length;
        struct {
            relay_type type : 4;    //消息类型4bit
            proto_flag flag : 5;    //flag 5bit(proto_flag)
            uint32_t len : 23;      //23bit(8M)
        };
    };
    uint32_t    target_id;  // target_id
    uint16_t    cmd_id;     // 协议ID
    uint16_t    session_id; // sessionId
    uint8_t     crc8;       // crc8
};
#pragma pack()

struct relay_service {
    uint32_t server_id = 0;
    uint32_t token = 0;
};

struct relay_unit {
    uint8_t crc8 = 0;
    uint32_t token = 0;
    std::unordered_map<uint8_t, relay_service> m_services;
};

class socket_relay
{
public:
    socket_relay(stdsptr<socket_mgr>& mgr) : m_mgr(mgr) {}

    void map_client(uint32_t client_id, uint32_t token);
    void map_group(uint32_t group_id, uint32_t client_id, bool enter);
    void map_server(uint32_t client_id, uint32_t server_id, uint32_t token);
    void do_forward_group(relay_header* header, pbyte data, size_t data_len);
    void do_forward_client(relay_header* header, pbyte data, size_t data_len);
    void do_forward_broadcast(relay_header* header, pbyte data, size_t data_len);
    void do_forward_service(relay_header* header, uint32_t client_id, pbyte data, size_t data_len);
    uint8_t do_forward_relay(router_header* header, pbyte data, size_t data_len);

    std::vector<uint32_t> query_servers(uint32_t client_id);
    bool check_service(uint32_t server_id, uint32_t client_id);
    void set_relay_service(uint8_t id) { m_relay_service_id = id; }

private:
    stdsptr<socket_mgr> m_mgr;
    uint8_t m_relay_service_id = 0;
    std::unordered_map<uint32_t, relay_unit> m_clients;
    std::unordered_map<uint32_t, std::set<uint32_t>> m_groups;
};

