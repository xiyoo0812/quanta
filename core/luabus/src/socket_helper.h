#pragma once
#include "lua_kit.h"

const int SOCKET_RECV_LEN   = 4096;
const int SOCKET_PACKET_MAX = 1024 * 1024 * 16; //16m

#ifdef POSIXI_API
using socket_t = int;
using BYTE = unsigned char;
const int SOCKET_ERROR = -1;
const socket_t INVALID_SOCKET = -1;
inline int get_socket_error() { return errno; }
inline void closesocket(socket_t fd) { close(fd); }
template <typename T, int N>
constexpr int _countof(T(&_array)[N]) { return N; }
#define SD_RECEIVE SHUT_RD
#define SD_SEND    SHUT_WR
#define SD_BOTH    SHUT_RDWR
#define WSAEWOULDBLOCK EWOULDBLOCK
#define WSAEINPROGRESS EINPROGRESS
#endif

#ifdef WIN32
using socket_t = SOCKET;
inline int get_socket_error() { return WSAGetLastError(); }
bool wsa_send_empty(socket_t fd, WSAOVERLAPPED& ovl);
bool wsa_recv_empty(socket_t fd, WSAOVERLAPPED& ovl);
#endif

template <typename T>
using stdsptr = std::shared_ptr<T>;

bool make_ip_addr(sockaddr_storage* addr, socklen_t* len, const char ip[], int port);
// ip字符串建议大小: char ip[INET6_ADDRSTRLEN];
bool get_ip_string(char ip[], size_t ip_size, const void* addr);
void set_no_block(socket_t fd);
void set_no_delay(socket_t fd, int enable);
void set_close_on_exec(socket_t fd);
void set_reuseaddr(socket_t fd);

int derive_port(int port, char* ip);

#define MAX_ERROR_TXT 128

char* get_error_string(char buffer[], int len, int no);
void get_error_string(std::string& err, int no);

