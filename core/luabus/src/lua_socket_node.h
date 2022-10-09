#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_router.h"

class lua_socket_node
{
public:
    lua_socket_node(uint32_t token, lua_State* L, std::shared_ptr<socket_mgr>& mgr,
    	std::shared_ptr<socket_router> router, bool blisten = false, eproto_type proto_type = eproto_type::proto_rpc);
    ~lua_socket_node();

	void close();

	uint32_t build_session_id() { return m_stoken | m_sindex++; }
	void set_timeout(int ms) { m_mgr->set_timeout(m_token, ms); }
	void set_nodelay(bool flag) { m_mgr->set_nodelay(m_token, flag); }

	int call_slice(slice* slice);
	int call_text(const char* data, uint32_t data_len);
	int call(uint32_t session_id, uint8_t flag, slice* slice);
	int call_head(uint16_t cmd_id, uint8_t flag, uint8_t type, uint32_t session_id, const char* data, uint32_t data_len);
    int forward_target(uint32_t session_id, uint8_t flag, uint32_t target_id, slice* slice);

    int forward_hash(uint32_t session_id, uint8_t flag, uint16_t service_id, uint16_t hash, slice* slice);

	template <rpc_type forward_method>
	int forward_by_group(uint32_t session_id, uint8_t flag, uint16_t service_id, slice* slice) {
		size_t data_len = 0;
		router_header header;
		char* data = (char*)slice->data(&data_len);
		header.len = data_len + sizeof(router_header);
		header.context = (uint8_t)forward_method << 4 | flag;
		header.session_id = session_id;
		header.target_id = service_id;

		sendv_item items[] = { { &header, sizeof(router_header)}, {data, data_len} };
		m_mgr->sendv(m_token, items, _countof(items));
		return header.len;
	}


public:
	std::string m_ip;
	uint32_t m_token = 0;
	uint32_t m_stoken = 0;
	uint16_t m_sindex = 1;

private:
	void on_recv(slice* slice);
    void on_call_head(slice* slice);
    void on_call_text(slice* slice);
    void on_call_common(slice* slice);
    void on_call(router_header* header, slice* slice);
	void on_forward_broadcast(router_header* header, size_t target_size);
	void on_forward_error(router_header* header);

    lua_State* m_lvm = nullptr;
    std::shared_ptr<socket_mgr> m_mgr;
    std::shared_ptr<socket_router> m_router;
	eproto_type m_proto_type;
};
