#include "stdafx.h"
#include "socket_router.h"

uint32_t get_service_id(uint32_t node_id) { return  (node_id >> 16) & 0xff; }
uint32_t build_node_id(uint16_t service_id, uint16_t index) { return (service_id & 0xff) << 16 | index; }

void socket_router::map_token(uint32_t node_id, uint32_t token) {
    uint32_t service_id = get_service_id(node_id);
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), node_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == node_id) {
        if (token > 0) {
            it->token = token;
            return;
        }
        nodes.erase(it);
        return;
    }
    service_node node;
    node.id = node_id;
    node.token = token;
    nodes.insert(it, node);
}

void socket_router::erase(uint32_t node_id) {
    uint32_t service_id = get_service_id(node_id);
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), node_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == node_id) {
        nodes.erase(it);
    }
}

void socket_router::set_master(uint32_t service_id, uint32_t token) {
    if (service_id < m_services.size()) {
        m_services[service_id].master = token;
    }
}

bool socket_router::do_forward_target(router_header* header, char* data, size_t data_len) {
	uint32_t target_id = header->target_id;
	uint32_t service_id = get_service_id(target_id);

    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), target_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it == nodes.end() || it->id != target_id)
        return false;

	uint8_t flag = header->context & 0xff;
	header->context = (uint8_t)msg_id::remote_call << 4 | flag;
    sendv_item items[] = {{header, sizeof(router_header)}, {data, data_len}};
    m_mgr->sendv(it->token, items, _countof(items));
    return true;
}

bool socket_router::do_forward_master(router_header* header, char* data, size_t data_len) {
	uint16_t service_id = (uint16_t)header->target_id;
    auto token = m_services[service_id].master;
    if (token == 0)
		return false;

	uint8_t flag = header->context & 0xff;
	header->context = (uint8_t)msg_id::remote_call << 4 | flag;
	sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };
    m_mgr->sendv(token, items, _countof(items));
    return true;
}

bool socket_router::do_forward_broadcast(router_header* header, int source, char* data, size_t data_len, size_t& broadcast_num) {
	uint16_t service_id = (uint16_t)header->target_id;

	uint8_t flag = header->context & 0xff;
	header->context = (uint8_t)msg_id::remote_call << 4 | flag;
	sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };

    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    int count = (int)nodes.size();
    for (auto& target : nodes) {
        if (target.token != 0 && target.token != source) {
            m_mgr->sendv(target.token, items, _countof(items));
            broadcast_num++;
        }
    }
    return broadcast_num > 0;
}

bool socket_router::do_forward_hash(router_header* header, char* data, size_t data_len) {
	uint16_t hash = header->target_id & 0xffff;
    uint16_t service_id = header->target_id >> 16 & 0xffff;

    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    int count = (int)nodes.size();
    if (count == 0)
        return false;

	uint8_t flag = header->context & 0xff;
	header->context = (uint8_t)msg_id::remote_call << 4 | flag;
	sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };

    auto& target = nodes[hash % count];
    if (target.token != 0) {
        m_mgr->sendv(target.token, items, _countof(items));
        return true;
    }
    return false;
}
