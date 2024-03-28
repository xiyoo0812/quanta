#pragma once
#include "ltimer.h"
#include "lua_kit.h"

const int SOCKET_RECV_LEN   = 4096;
const int SOCKET_PACKET_MAX = 1024 * 1024 * 16; //16m

#if defined(__ORBIS__) || defined(__PROSPERO__)
using BYTE = unsigned char;
using socket_t = SceNetId;
using socklen_t = SceNetSocklen_t;
using sockaddr = SceNetSockaddr;
using sockaddr_in = SceNetSockaddrIn;
using sockaddr_storage = SceNetSockaddrStorage;
using epoll_event = SceNetEpollEvent;
const int SOCKET_ERROR = -1;
const socket_t INVALID_SOCKET = -1;
inline int get_socket_error() { return sce_net_errno; }
inline int epoll_create(int flags) { return sceNetEpollCreate("__EPOLL__", flags); }
inline socket_t socket(int domain, int type, int protocol) { return sceNetSocket("__SOCKET__", domain, type, protocol); }
template <typename T, int N>
constexpr int _countof(T(&_array)[N]) { return N; }
#define bind sceNetBind
#define send sceNetSend
#define recv sceNetRecv
#define htons sceNetHtons
#define ntohs sceNetNtohs
#define accept sceNetAccept
#define listen sceNetListen
#define sendto sceNetSendto
#define connect sceNetConnect
#define recvfrom sceNetRecvfrom
#define shutdown sceNetShutdown
#define inet_ntop sceNetInetNtop
#define inet_ntoa sceNetInetNtoa
#define inet_pton sceNetInetPton
#define setsockopt sceNetSetsockopt
#define getsockopt sceNetGetsockopt
#define closesocket sceNetSocketClose
#define epoll_ctl sceNetEpollControl
#define epoll_wait sceNetEpollWait
#define close sceNetEpollDestroy

#define AF_INET SCE_NET_AF_INET
#define INET_ADDRSTRLEN SCE_NET_INET_ADDRSTRLEN

#define INADDR_ANY SCE_NET_INADDR_ANY
#define IPPROTO_IP SCE_NET_IPPROTO_IP
#define IPPROTO_TCP SCE_NET_IPPROTO_TCP
#define IPPROTO_UDP SCE_NET_IPPROTO_UDP

#define SOL_SOCKET SCE_NET_SOL_SOCKET
#define SOCK_DGRAM SCE_NET_SOCK_DGRAM
#define SOCK_STREAM SCE_NET_SOCK_STREAM
#define TCP_NODELAY SCE_NET_TCP_NODELAY
#define SO_ERROR SCE_NET_SO_ERROR
#define SO_REUSEADDR SCE_NET_SO_REUSEADDR

#define EPOLLIN SCE_NET_EPOLLIN
#define EPOLLET 0x000004
#define EPOLLERR SCE_NET_EPOLLERR
#define EPOLLHUB SCE_NET_EPOLLHUB
#define EPOLLOUT SCE_NET_EPOLLOUT
#define EPOLL_CTL_ADD SCE_NET_EPOLL_CTL_ADD
#define EPOLL_CTL_MOD SCE_NET_EPOLL_CTL_MOD

#define SD_RECEIVE  SCE_NET_SHUT_RD
#define SD_SEND     SCE_NET_SHUT_WR
#define SD_BOTH     SCE_NET_SHUT_RDWR

#define WSAEWOULDBLOCK EWOULDBLOCK
#define WSAEINPROGRESS EINPROGRESS
#endif

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
const int SOCKET_ERROR = -1;
const socket_t INVALID_SOCKET = -1;
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

template <typename T>
using stdsptr = std::shared_ptr<T>;

bool make_ip_addr(sockaddr_storage* addr, size_t* len, const char ip[], int port);
// ip字符串建议大小: char ip[INET6_ADDRSTRLEN];
bool get_ip_string(char ip[], size_t ip_size, const void* addr);
void set_no_block(socket_t fd);
void set_no_delay(socket_t fd, int enable);
void set_close_on_exec(socket_t fd);
void set_reuseaddr(socket_t fd);

#define MAX_ERROR_TXT 128

char* get_error_string(char buffer[], int len, int no);
void get_error_string(std::string& err, int no);

