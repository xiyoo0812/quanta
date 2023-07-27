#pragma once
#include "ltimer.h"
#include "lua_kit.h"

const int SOCKET_RECV_LEN   = 4096;
const int SOCKET_PACKET_MAX = 1024 * 1024 * 16; //16m

#pragma pack(1)
struct socket_header {
    uint16_t    len;            // 整个包的长度
    uint8_t     flag;           // 标志位
    uint8_t     type;           // 消息类型
    uint16_t    cmd_id;         // 协议ID
    uint16_t    session_id;     // sessionId
    uint8_t     crc8;           // crc8
};
#pragma pack()

#if defined(__linux) || defined(__APPLE__)
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <netdb.h>
#include <cstring>
#include <sys/stat.h>
#include <netinet/udp.h>
using socket_t = int;
using BYTE = unsigned char;
const socket_t INVALID_SOCKET = -1;
const int SOCKET_ERROR = -1;
inline int get_socket_error() { return errno; }
inline void closesocket(socket_t fd) { close(fd); }
template <typename T, int N>
constexpr int _countof(T(&_array)[N]) { return N; }
#define SD_RECEIVE SHUT_RD
#define WSAEWOULDBLOCK EWOULDBLOCK
#define WSAEINPROGRESS EINPROGRESS
#endif

#ifdef _MSC_VER
using socket_t = SOCKET;
inline int get_socket_error() { return WSAGetLastError(); }
bool wsa_send_empty(socket_t fd, WSAOVERLAPPED& ovl);
bool wsa_recv_empty(socket_t fd, WSAOVERLAPPED& ovl);
#endif

bool make_ip_addr(sockaddr_storage* addr, size_t* len, const char ip[], int port);
// ip字符串建议大小: char ip[INET6_ADDRSTRLEN];
bool get_ip_string(char ip[], size_t ip_size, const void* addr, size_t addr_len);

// timeout: 单位ms,传入-1表示阻塞到永远
bool check_can_write(socket_t fd, int timeout);

void set_no_block(socket_t fd);
void set_no_delay(socket_t fd, int enable);
void set_close_on_exec(socket_t fd);
void set_reuseaddr(socket_t fd);

#define MAX_ERROR_TXT 128

char* get_error_string(char buffer[], int len, int no);
void get_error_string(std::string& err, int no);

