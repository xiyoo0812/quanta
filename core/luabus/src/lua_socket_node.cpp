/*
** repository: https://github.com/trumanzhao/luabus.git
** trumanzhao, 2017-07-09, trumanzhao@foxmail.com
*/
#include "stdafx.h"
#include "var_int.h"
#include "lua_socket_node.h"
#include "socket_helper.h"
#include <iostream>

EXPORT_CLASS_BEGIN(lua_socket_node)
EXPORT_LUA_FUNCTION(call)
EXPORT_LUA_FUNCTION(call_pack)
EXPORT_LUA_FUNCTION(call_text)
EXPORT_LUA_FUNCTION(forward_target)
EXPORT_LUA_FUNCTION_AS(forward_by_group<msg_id::forward_master>, "forward_master")
EXPORT_LUA_FUNCTION_AS(forward_by_group<msg_id::forward_random>, "forward_random")
EXPORT_LUA_FUNCTION_AS(forward_by_group<msg_id::forward_broadcast>, "forward_broadcast")
EXPORT_LUA_FUNCTION(forward_hash)
EXPORT_LUA_FUNCTION(close)
EXPORT_LUA_FUNCTION(set_send_buffer_size)
EXPORT_LUA_FUNCTION(set_recv_buffer_size)
EXPORT_LUA_FUNCTION(set_timeout)
EXPORT_LUA_FUNCTION(set_nodelay)
EXPORT_LUA_STD_STR_AS_R(m_ip, "ip")
EXPORT_LUA_INT_AS_R(m_token, "token")
EXPORT_CLASS_END()

lua_socket_node::lua_socket_node(uint32_t token, lua_State* L, std::shared_ptr<socket_mgr>& mgr,
	std::shared_ptr<lua_archiver>& ar, std::shared_ptr<socket_router> router, bool blisten, eproto_type proto_type)
    : m_token(token), m_lvm(L), m_mgr(mgr), m_archiver(ar), m_router(router), m_proto_type(proto_type)
{
    m_mgr->get_remote_ip(m_token, m_ip);

	if (blisten)
	{
		m_mgr->set_accept_callback(token, [this](uint32_t steam_token, eproto_type proto_type)
		{
			lua_guard g(m_lvm);
			auto stream = new lua_socket_node(steam_token, m_lvm, m_mgr, m_archiver, m_router, false, proto_type);
			lua_call_object_function(m_lvm, nullptr, this, "on_accept", std::tie(), stream);
		});
	}    

    m_mgr->set_connect_callback(token, [this](bool ok, const char* reason)
    {
        if (ok)
        {
            m_mgr->get_remote_ip(m_token, m_ip);
        }
        lua_guard g(m_lvm);
        lua_call_object_function(m_lvm, nullptr, this, "on_connect", std::tie(), ok ? "ok" : reason);
		if (!ok) 
		{
			this->m_token = 0;
		}
    });

    m_mgr->set_error_callback(token, [this](const char* err)
	{
        lua_guard g(m_lvm);
		lua_call_object_function(m_lvm, nullptr, this, "on_error", std::tie(), err);
		this->m_token = 0;
    });

    m_mgr->set_package_callback(token, [this](char* data, size_t data_len)
    {
        on_recv(data, data_len);
    });
}

lua_socket_node::~lua_socket_node()
{
    close_node();
}

int lua_socket_node::call_pack(lua_State* L)
{
    int top = lua_gettop(L);
    if (top < 4)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    socket_header header;
    header.cmd_id = lua_tointeger(L, 1);
    header.flag = lua_tointeger(L, 2);
    header.session_id = lua_tointeger(L, 3);

    size_t data_len = 0;
    const char* data_ptr = lua_tolstring(L, 4, &data_len);
    if (data_len + sizeof(socket_header) >= USHRT_MAX)
    {
        lua_pushinteger(L, -2);
        return 1;
    }
    header.len = data_len + sizeof(socket_header);

    sendv_item items[] = { { &header, sizeof(socket_header) }, {data_ptr, data_len} };
    m_mgr->sendv(m_token, items, _countof(items));
    
    lua_pushinteger(L, header.len);
    return 1;
}

int lua_socket_node::call_text(lua_State* L)
{
    size_t data_len = 0;
    const char* data_ptr = lua_tolstring(L, 1, &data_len);
    if (data_len  >= USHRT_MAX)
    {
        lua_pushinteger(L, -1);
        return 1;
    }
    m_mgr->send(m_token, data_ptr, data_len);    
    lua_pushinteger(L, data_len);
    return 1;
}

size_t lua_socket_node::format_header(lua_State* L, BYTE* header_data, size_t data_len, msg_id msgid)
{
    uint32_t offset = 0;
    router_header header;
    header.session_id = (uint32_t)lua_tointeger(L, 1);
    header.rpc_flag = (uint32_t)lua_tointeger(L, 2);
    header.source_id = (uint32_t)lua_tointeger(L, 3);
    return m_router->format_header(header_data, data_len, &header, msgid);
}

size_t lua_socket_node::parse_header(BYTE* data, size_t data_len, uint64_t* msgid, router_header* header)
{
    size_t offset = 0;
    size_t len = decode_u64(msgid, data + offset, data_len - offset);
    if (len == 0)
        return 0;
    offset += len;
    len = decode_u64(&header->session_id, data + offset, data_len - offset);
    if (len == 0)
        return 0;
    offset += len;
    len = decode_u64(&header->rpc_flag, data + offset, data_len - offset);
    if (len == 0)
        return 0;
    offset += len;
    len = decode_u64(&header->source_id, data + offset, data_len - offset);
    if (len == 0)
        return 0;
    offset += len;
    return offset;
}

int lua_socket_node::call(lua_State* L)
{
    int top = lua_gettop(L);
    if (top < 4)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    BYTE header[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(L, header, sizeof(header), msg_id::remote_call);

    size_t data_len = 0;
    void* data = m_archiver->save(&data_len, L, 4, top);
    if (data == nullptr)
    {
        lua_pushinteger(L, -2);
        return 1;
    }

    sendv_item items[] = { {header, header_len}, {data, data_len} };
    m_mgr->sendv(m_token, items, _countof(items));
    lua_pushinteger(L, header_len + data_len);
    return 1;
}

int lua_socket_node::forward_target(lua_State* L)
{
    int top = lua_gettop(L);
    if (top < 5)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    BYTE header[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(L, header, sizeof(header), msg_id::forward_target);

    BYTE svr_id_data[MAX_VARINT_SIZE];
    uint32_t service_id = (uint32_t)lua_tointeger(L, 4);
    size_t svr_id_len = encode_u64(svr_id_data, sizeof(svr_id_data), service_id);

    size_t data_len = 0;
    void* data = m_archiver->save(&data_len, L, 5, top);
    if (data == nullptr)
    {
        lua_pushinteger(L, -2);
        return 1;
    }

    sendv_item items[] = { {header, header_len}, {svr_id_data, svr_id_len}, {data, data_len}};
    m_mgr->sendv(m_token, items, _countof(items));

    size_t send_len = header_len + svr_id_len + data_len;
    lua_pushinteger(L, send_len);
    return 1;
}

template <msg_id forward_method>
int lua_socket_node::forward_by_group(lua_State* L)
{
    int top = lua_gettop(L);
    if (top < 5)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    static_assert(forward_method == msg_id::forward_master || forward_method == msg_id::forward_random ||
        forward_method == msg_id::forward_broadcast, "Unexpected forward method !");

    BYTE header[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(L, header, sizeof(header), forward_method);
    
    uint8_t group_id = (uint8_t)lua_tointeger(L, 4);
    BYTE group_id_data[MAX_VARINT_SIZE];
    size_t group_id_len = encode_u64(group_id_data, sizeof(group_id_data), group_id);

    size_t data_len = 0;
    void* data = m_archiver->save(&data_len, L, 5, top);
    if (data == nullptr)
    {
        lua_pushinteger(L, -2);
        return 1;
    }

    sendv_item items[] = { {header, header_len}, {group_id_data, group_id_len}, {data, data_len}};
    m_mgr->sendv(m_token, items, _countof(items));

    size_t send_len = header_len + group_id_len + data_len;
    lua_pushinteger(L, data_len);
    return 1;
}

int lua_socket_node::forward_hash(lua_State* L)
{
    int top = lua_gettop(L);
    if (top < 6)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    BYTE header[MAX_VARINT_SIZE * 4];
    size_t header_len = format_header(L, header, sizeof(header), msg_id::forward_hash);

    uint8_t group_id = (uint8_t)lua_tointeger(L, 4);
    BYTE group_id_data[MAX_VARINT_SIZE];
    size_t group_id_len = encode_u64(group_id_data, sizeof(group_id_data), group_id);

    size_t hash_key = luaL_optinteger(L, 5, 0);
    if(hash_key == 0)
    {
        // unexpected hash key
        lua_pushinteger(L, -3);
        return 1;
    }

    BYTE hash_data[MAX_VARINT_SIZE];
    size_t hash_len = encode_u64(hash_data, sizeof(hash_data), hash_key);

    size_t data_len = 0;
    void* data = m_archiver->save(&data_len, L, 6, top);
    if (data == nullptr)
    {
        lua_pushinteger(L, -2);
        return 1;
    }

    sendv_item items[] = { {header, header_len}, {group_id_data, group_id_len}, {hash_data, hash_len}, {data, data_len}};
    m_mgr->sendv(m_token, items, _countof(items));

    size_t send_len = header_len + group_id_len + hash_len + data_len;
    lua_pushinteger(L, send_len);
    return 1;
}

void lua_socket_node::close_node(bool immediately)
{
    if (m_token != 0)
    {
        m_mgr->close(m_token, immediately);
        m_token = 0;
    }
}

int lua_socket_node::close(lua_State* L)
{
    bool immediately = true;
    if (lua_gettop(L) > 0)
    {
        immediately = lua_toboolean(L, 1);
    }
    close_node(immediately);
    return 0;
}

void lua_socket_node::on_recv(char* data, size_t data_len)
{
    if (eproto_type::proto_pack == m_proto_type)
    {
        on_call_pack(data, data_len);
        return;
    }
    if (eproto_type::proto_text == m_proto_type)
    {
        on_call_text(data, data_len);
        return;
    }

    uint64_t msg = 0;
    router_header header;
    size_t len = parse_header((BYTE*)data, data_len, &msg, &header);
    if (len == 0)
        return;

    data += len;
    data_len -= len;

    switch ((msg_id)msg)
    {
    case msg_id::remote_call:
        on_call(&header, data, data_len);
        break;
    case msg_id::forward_target:
        if (!m_router->do_forward_target(&header, data, data_len))
            on_forward_error(&header);
        break;
    case msg_id::forward_random:
        if (!m_router->do_forward_random(&header, data, data_len))
            on_forward_error(&header);
        break;
    case msg_id::forward_master:
        if (!m_router->do_forward_master(&header, data, data_len))
            on_forward_error(&header);
        break;
    case msg_id::forward_hash:
        if (!m_router->do_forward_hash(&header, data, data_len))
            on_forward_error(&header);
        break;
    case msg_id::forward_broadcast:
        {
            size_t boardcast_num = 0;
            if (m_router->do_forward_broadcast(&header, m_token, data, data_len, boardcast_num))
                on_forward_boardcast(&header, boardcast_num);
            else
                on_forward_error(&header);
        }
        break;
    default:
        break;
    }
}

void lua_socket_node::on_forward_error(router_header* header)
{
    if (header->session_id > 0)
    {
        lua_guard g(m_lvm);
        if (!lua_get_object_function(m_lvm, this, "on_forward_error"))
            return;
        lua_pushinteger(m_lvm, header->session_id);
        lua_call_function(m_lvm, nullptr, 1, 0);
    }
}

void lua_socket_node::on_forward_boardcast(router_header* header, size_t boardcast_num)
{
    if (header->session_id > 0)
    {
        lua_guard g(m_lvm);
        if (!lua_get_object_function(m_lvm, this, "on_forward_boardcast"))
            return;
        lua_pushinteger(m_lvm, header->session_id);
        lua_pushinteger(m_lvm, boardcast_num);
        lua_call_function(m_lvm, nullptr, 2, 0);
    }
}

void lua_socket_node::on_call(router_header* header, char* data, size_t data_len)
{
    lua_guard g(m_lvm);
    if (!lua_get_object_function(m_lvm, this, "on_call"))
        return;

    lua_pushinteger(m_lvm, data_len);
    lua_pushinteger(m_lvm, header->session_id);
    lua_pushinteger(m_lvm, header->rpc_flag);
    lua_pushinteger(m_lvm, header->source_id);
    int param_count = m_archiver->load(m_lvm, data, data_len);
    if (param_count == 0)
        return;

    lua_call_function(m_lvm, nullptr, param_count + 4, 0);
}

void lua_socket_node::on_call_pack(char* data, size_t data_len)
{
    std::string body;
    auto head = (socket_header*)data;
    body.append(data + sizeof(socket_header), data_len - sizeof(socket_header));

    lua_guard g(m_lvm);
    lua_call_object_function(m_lvm, nullptr, this, "on_call_pack", std::tie(), data_len, head->cmd_id, head->flag, head->session_id, body);
}

void lua_socket_node::on_call_text(char* data, size_t data_len)
{
    std::string body;
    body.append(data, data_len);

    lua_guard g(m_lvm);
    lua_call_object_function(m_lvm, nullptr, this, "on_call_text", std::tie(), data_len, body);
}