﻿/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2017-02-11, trumanzhao@foxmail.com
*/
#include "stdafx.h"
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <algorithm>
#include "tools.h"
#include "var_int.h"
#include "socket_router.h"

uint32_t get_group_idx(uint32_t service_id) { return  (service_id >> 16) & 0xff; }

void socket_router::set_master(uint32_t group_idx, uint32_t token)
{
    if (group_idx < m_groups.size())
    {
        m_groups[group_idx].master = token;
    }
}

void socket_router::map_token(uint32_t service_id, uint32_t token)
{
    uint32_t group_idx = get_group_idx(service_id);
    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), service_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == service_id)
    {
        it->token = token;
    }
    else
    {
        service_node node;
        node.id = service_id;
        node.token = token;
        nodes.insert(it, node);
    }
}

void socket_router::erase(uint32_t service_id)
{
    uint32_t group_idx = get_group_idx(service_id);
    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), service_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it != nodes.end() && it->id == service_id)
    {
        nodes.erase(it);
    }
}

size_t socket_router::format_header(BYTE* header_data, size_t data_len, router_header* header, msg_id msgid)
{
    size_t offset = 0;
    offset += encode_u64(header_data + offset, data_len - offset, (char)msgid);
    offset += encode_u64(header_data + offset, data_len - offset, header->session_id);
    offset += encode_u64(header_data + offset, data_len - offset, header->rpc_flag);
    offset += encode_u64(header_data + offset, data_len - offset, header->source_id);
    return offset;
}

bool socket_router::do_forward_target(router_header* header, char* data, size_t data_len)
{
    uint64_t target_id64 = 0;
    size_t len = decode_u64(&target_id64, (BYTE*)data, data_len);
    if (len == 0)
        return false;

    data += len;
    data_len -= len;

    uint32_t target_id = (uint32_t)target_id64;
    uint32_t group_idx = get_group_idx(target_id);
    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    auto it = std::lower_bound(nodes.begin(), nodes.end(), target_id, [](service_node& node, uint32_t id) { return node.id < id; });
    if (it == nodes.end() || it->id != target_id)
        return false;
    
    BYTE header_data[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(header_data, sizeof(header_data), header, msg_id::remote_call);

    sendv_item items[] = {{header_data, header_len}, {data, data_len}};
    m_mgr->sendv(it->token, items, _countof(items));
    return true;
}

bool socket_router::do_forward_master(router_header* header, char* data, size_t data_len)
{
    uint64_t group_idx = 0;
    size_t len = decode_u64(&group_idx, (BYTE*)data, data_len);
    if (len == 0 || group_idx >= m_groups.size())
        return false;

    data += len;
    data_len -= len;

    auto token = m_groups[group_idx].master;
    if (token == 0)
        return false;

    BYTE header_data[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(header_data, sizeof(header_data), header, msg_id::remote_call);

    sendv_item items[] = {{header_data, header_len}, {data, data_len}};
    m_mgr->sendv(token, items, _countof(items));
    return true;
}

bool socket_router::do_forward_random(router_header* header, char* data, size_t data_len)
{
    uint64_t group_idx = 0;
    size_t len = decode_u64(&group_idx, (BYTE*)data, data_len);
    if (len == 0 || group_idx >= m_groups.size())
        return false;

    data += len;
    data_len -= len;

    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    int count = (int)nodes.size();
    if (count == 0)
        return false;

    BYTE header_data[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(header_data, sizeof(header_data), header, msg_id::remote_call);
    sendv_item items[] = {{header_data, header_len}, {data, data_len}};

    int idx = rand() % count;
    for (int i = 0; i < count; i++)
    {
        auto& target = nodes[(idx + i) % count];
        if (target.token != 0)
        {
            m_mgr->sendv(target.token, items, _countof(items));
            return true;
        }
    }
    return false;
}

bool socket_router::do_forward_broadcast(router_header* header, int source, char* data, size_t data_len, size_t& boardcast_num)
{
    uint64_t group_idx = 0;
    size_t len = decode_u64(&group_idx, (BYTE*)data, data_len);
    if (len == 0 || group_idx >= m_groups.size())
        return false;

    data += len;
    data_len -= len;

    BYTE header_data[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(header_data, sizeof(header_data), header, msg_id::remote_call);
    sendv_item items[] = {{header_data, header_len}, {data, data_len}};

    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    int count = (int)nodes.size();
    for (auto& target : nodes)
    {
        if (target.token != 0 && target.token != source)
        {
            m_mgr->sendv(target.token, items, _countof(items));
            boardcast_num++;
        }
    }
    return boardcast_num > 0;
}

bool socket_router::do_forward_hash(router_header* header, char* data, size_t data_len)
{
    uint64_t group_idx = 0;
    size_t len = decode_u64(&group_idx, (BYTE*)data, data_len);
    if (len == 0 || group_idx >= m_groups.size())
        return false;

    data += len;
    data_len -= len;

    uint64_t hash = 0;
    len = decode_u64(&hash, (BYTE*)data, data_len);
    if (len == 0)
        return false;

    data += len;
    data_len -= len;

    auto& group = m_groups[group_idx];
    auto& nodes = group.nodes;
    int count = (int)nodes.size();
    if (count == 0)
        return false;

    BYTE header_data[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(header_data, sizeof(header_data), header, msg_id::remote_call);
    sendv_item items[] = {{header_data, header_len}, {data, data_len}};

    int idx = hash % count;
    for (int i = 0; i < count; i++)
    {
        auto& target = nodes[(idx + i) % count];
        if (target.token != 0)
        {
            m_mgr->sendv(target.token, items, _countof(items));
            return true;
        }
    }
    return false;
}
