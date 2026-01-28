#include "stdafx.h"
#include "socket_router.h"

#include <ranges>
#include <algorithm>

uint32_t socket_router::map_router(uint32_t node_id, int32_t token) {
    uint32_t service_id = (node_id >> 16) & 0xff;
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), node_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == node_id) {
        if (token >= 0) {
            it->token = token;
        } else {
            nodes.erase(it);
        }
        return choose_master(service_id);
    }
    if (token >= 0) {
        service_node node;
        node.id = node_id;
        node.token = token;
        nodes.insert(it, node);
    }
    return choose_master(service_id);
}

uint32_t socket_router::choose_master(uint32_t service_id){
    if (service_id < m_services.size()) {
        auto& services = m_services[service_id];
        for (auto& node : services.nodes) {
            if (node.token > 0) {
                services.master = node;
                return node.id;
            }
        }
        services.master.token = 0;
    }
    return 0;
}

void socket_router::do_forward_target(uint32_t token, router_header* header, pbyte data, size_t data_len) {
    uint32_t target_id = header->target_id;
    uint8_t service_id = (target_id >> 16) & 0xff;
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), target_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == target_id && it->token > 0) {
        header->type = FORWARD_SELF;
        sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };
        m_mgr->sendv(it->token, items, _countof(items));
        m_route_count++;
        return;
    }
    on_forward_error(token, header, data, data_len);
}

void socket_router::do_forward_master(uint32_t token, router_header* header, pbyte data, size_t data_len) {
    auto stoken = m_services[header->service_id].master.token;
    if (stoken > 0) {
        header->type = FORWARD_SELF;
        sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };
        m_mgr->sendv(stoken, items, _countof(items));
        m_route_count++;
        return;
    }
    on_forward_error(token, header, data, data_len);
}

void socket_router::do_forward_broadcast(uint32_t token, router_header* header, pbyte data, size_t data_len) {
    header->type = FORWARD_SELF;
    sendv_item items[] = { {header, sizeof(router_header)}, {data, data_len} };
    auto& nodes = m_services[header->service_id].nodes;
    auto actions = nodes | std::views::filter([token](const auto& target) {
        return target.token > 0 && target.token != token;
        }) | std::views::transform([](const auto& target) {
            return target.token;
        });
        size_t broadcast_num = 0;
        std::ranges::for_each(actions, [&](uint32_t btoken) {
            m_mgr->sendv(btoken, items, _countof(items));
            m_route_count++;
            broadcast_num++;
        });
        on_forward_broadcast(token, header, broadcast_num);
}

void socket_router::do_forward_hash(uint32_t token, router_header* header, pbyte data, size_t data_len) {
    uint16_t hash = header->target_id;
    auto& services = m_services[header->service_id];
    auto& nodes = services.nodes;
    uint16_t count = (uint16_t)nodes.size();
    if (count > 0) {
        auto& target = nodes[hash % count];
        if (target.token > 0) {
            header->type = FORWARD_SELF;
            sendv_item items[] = { {header, sizeof(router_header)}, { data, data_len } };
            m_mgr->sendv(target.token, items, _countof(items));
            m_route_count++;
            return;
        }
    }
    on_forward_error(token, header, data, data_len);
}

void socket_router::do_forward_relay(uint8_t service_id, uint32_t token, router_header* header, pbyte data, size_t data_len) {
    uint16_t hash = header->target_id;
    auto& services = m_services[service_id];
    auto& nodes = services.nodes;
    uint16_t count = (uint16_t)nodes.size();
    if (count > 0) {
        auto& target = nodes[hash % count];
        if (target.token > 0) {
            sendv_item items[] = { {header, sizeof(router_header)}, { data, data_len } };
            m_mgr->sendv(target.token, items, _countof(items));
            m_route_count++;
            return;
        }
    }
    on_forward_error(token, header, data, data_len);
}

uint32_t socket_router::get_route_count() {
    uint32_t old = m_route_count;
    m_route_count = 0;
    return old;
}

void socket_router::on_forward_error(uint32_t token, router_header* header, pbyte data, size_t data_len) {
    if (header->session_id > 0) {
        header->type = FORWARD_SELF;
        header->flag = FLAG_UNREACH;
        sendv_item items[] = { { header, sizeof(router_header)}, { data, data_len } };
        m_mgr->sendv(token, items, _countof(items));
    }
}

void socket_router::on_forward_broadcast(uint32_t token, router_header* header, size_t broadcast_num) {
    if (header->session_id > 0) {
        size_t data_len = 0;
        auto data = m_codec->encode(&data_len, 5, 0, "on_forward_broadcast", true, 0, broadcast_num);
        header->flag = FLAG_RES;
        header->len = data_len + sizeof(router_header);
        sendv_item items[] = { { header, sizeof(router_header)}, { data, data_len } };
        m_mgr->sendv(token, items, _countof(items));
    }
}