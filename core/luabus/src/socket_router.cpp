#include "stdafx.h"
#include "socket_router.h"

#include <ranges>
#include <algorithm>

uint32_t get_service_id(uint32_t node_id) { return  (node_id >> 16) & 0xff; }

uint32_t socket_router::map_token(uint32_t node_id, uint32_t token) {
    uint32_t service_id = get_service_id(node_id);
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), node_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == node_id) {
        if (token > 0) {
            it->token = token;
        } else {
            nodes.erase(it);
        }
        return choose_master(service_id);
    }
    service_node node;
    node.id = node_id;
    node.token = token;
    nodes.insert(it, node);
    return choose_master(service_id);
}

void socket_router::erase(uint32_t node_id) {
    uint32_t service_id = get_service_id(node_id);
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), node_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == node_id) {
        nodes.erase(it);
        choose_master(service_id);
    }
}

uint32_t socket_router::choose_master(uint32_t service_id){
    if (service_id < m_services.size()) {
        auto& services = m_services[service_id];
        if (services.nodes.empty()) {
            services.master = service_node {};
            return 0;
        }
        services.master = services.nodes.front();
        return services.master.id;
    }
    return 0;
}

bool socket_router::do_forward_target(router_header* header, char* data, size_t data_len) {
	uint32_t target_id = header->target_id;
	uint32_t service_id = get_service_id(target_id);

    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), target_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it == nodes.end() || it->id != target_id){
        return false;
    }
	uint8_t flag = header->context & 0xf;
	header->context = (uint8_t)rpc_type::remote_call << 4 | flag;
    sendv_item items[] = {{header, sizeof(router_header)}, {data, data_len}};
    m_mgr->sendv(it->token, items, _countof(items));
    m_route_count++;
    return true;
}

bool socket_router::do_forward_master(router_header* header, char* data, size_t data_len) {
	uint16_t service_id = (uint16_t)header->target_id;
    auto token = m_services[service_id].master.token;
    if (token == 0)
		return false;

	uint8_t flag = header->context & 0xf;
	header->context = (uint8_t)rpc_type::remote_call << 4 | flag;
	sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };
    m_mgr->sendv(token, items, _countof(items));
    m_route_count++;
    return true;
}

bool socket_router::do_forward_broadcast(router_header* header, int source, char* data, size_t data_len, size_t& broadcast_num) {
	uint8_t flag = header->context & 0xf;
    uint16_t service_id = (uint16_t)header->target_id;
	header->context = (uint8_t)rpc_type::remote_call << 4 | flag;
	sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };

    auto& nodes = m_services[service_id].nodes;
    auto actions = nodes | std::views::filter([source](const auto& target) {
        return target.token != 0 && target.token != source;
    }) | std::views::transform([](const auto& target) {
        return target.token;
    });
    std::ranges::for_each(actions, [&](uint32_t token) {
        m_mgr->sendv(token, items, _countof(items));
        m_route_count++;
        broadcast_num++;
    });
    return broadcast_num > 0;
}

bool socket_router::do_forward_hash(router_header* header, char* data, size_t data_len) {
	uint16_t hash = header->target_id & 0xffff;
    uint16_t service_id = get_service_id(header->target_id);

    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    int count = (int)nodes.size();
    if (count == 0) {
        return false;
    }
    auto& target = nodes[hash % count];
    if (target.token != 0) {
        uint8_t flag = header->context & 0xf;
        header->context = (uint8_t)rpc_type::remote_call << 4 | flag;
        sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };

        m_mgr->sendv(target.token, items, _countof(items));
        m_route_count++;
        return true;
    }
    return false;
}

uint32_t socket_router::get_route_count() {
    uint32_t old = m_route_count;
    m_route_count = 0;
    return old;
}