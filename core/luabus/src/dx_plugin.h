/**
 * @author: errorcpp@qq.com
 * @date:   2019-07-11
 */

#pragma once

#include <cstdint>
#include "luna.h"
#include "lua_archiver.h"

#define NET_PACKET_MAX_LEN (64*1024-1)

struct dx_pkt_header
{
    uint16_t		len;            // 整个包的长度
    uint8_t   		flag;			// 标志位
    uint8_t	    	seq_id;			// cli->svr 客户端请求序列号，递增，可用于防止包回放; svr->cli 服务端发给客户端的包序列号，客户端收到的包序号不连续，则主动断开
    uint32_t		cmd_id;         // 协议ID
    uint32_t		session_id;     // sessionId
};

typedef dx_pkt_header* dx_pkt_header_ptr;
