/*
 *  Written by xphh 2015 with 'MIT License'
 */
#define _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_DEPRECATE
#include "socket.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#ifdef WIN32
#include <winsock2.h>
#undef errno
#define errno		GetLastError()
#define ioctl		ioctlsocket
#define close		closesocket
#define EWOULDBLOCK WSAEWOULDBLOCK
#define EINPROGRESS WSAEINPROGRESS
typedef unsigned int socklen_t;
#else
#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <arpa/inet.h>
#define INVALID_SOCKET -1
typedef struct sockaddr SOCKADDR;
typedef struct sockaddr_in SOCKADDR_IN;
#endif

C_API void socket_startup()
{
#ifdef WIN32
	static int first = 1;
	if (first)
	{
		WSADATA wsaData;
		WSAStartup(MAKEWORD(2, 2), &wsaData);
		first = 0;
	}
#endif
}

C_API void socket_cleanup()
{
#ifdef WIN32
	WSACleanup();
#endif
}

static char errmsg[1024] = {0};
C_API const char *socket_error()
{
	return errmsg;
}

#define dump_error(msg)		sprintf(errmsg, "err[%d] %s", errno, msg)

static int check_ret(int ret, const char *msg)
{
	if (ret <= 0)
	{
#ifndef WIN32
		if (errno == EINTR)
		{
			return 0;
		}
#endif
		if (errno == EWOULDBLOCK || errno == EINPROGRESS)
		{
			return 0;
		}
		ret = -1;
		dump_error(msg);
	}
	return ret;
}

static void copy_ip_out(const SOCKADDR_IN *addr, char *ip_buf, int *p_port)
{
	unsigned char *ip = (unsigned char *)&(addr->sin_addr.s_addr);
	sprintf(ip_buf, "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
	*p_port = (int)ntohs(addr->sin_port);
}

static int socket_bind(int fd, const char *ip, int port)
{
	int ret = 0;

	SOCKADDR_IN tAddr;
	memset(&tAddr, 0, sizeof(tAddr));
	tAddr.sin_family = AF_INET; 
	tAddr.sin_addr.s_addr = inet_addr(ip);
	tAddr.sin_port = htons(port);

	ret = bind(fd, (SOCKADDR *)&tAddr, sizeof(tAddr));
	if (ret < 0)
	{
		dump_error("bind fail");
		return -1;
	}

	return 0;
}

C_API int socket_tcp(const char *ip, int port)
{
	int fd = (int)socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (fd < 0)
	{
		dump_error("create tcp socket fail");
		return -1;
	}

	/* set socket option */
	{
		int on = 1;
		ioctl(fd, FIONBIO, &on);
		setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (char*)&on, sizeof(on));
		setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (char*)&on, sizeof(on));
	}

	if (ip && socket_bind(fd, ip, port) < 0)
	{
		close(fd);
		return -1;
	}

	return fd;
}

C_API int socket_udp(const char *ip, int port)
{
	int fd = -1;

	fd = (int)socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (fd < 0)
	{
		dump_error("create udp socket fail");
		return -1;
	}

	if (ip && socket_bind(fd, ip, port) < 0)
	{
		close(fd);
		return -1;
	}

	return fd;
}

C_API int socket_close(int fd)
{
	int ret = (close(fd));
	if (ret < 0)
	{
		dump_error("listen fail");
	}
	return ret;
}

C_API int socket_localaddr(int fd, char *ip_buf, int *p_port)
{
	struct sockaddr_in tAddr;
	socklen_t nLen;
	int ret;

	memset(&tAddr, 0, sizeof(tAddr));
	nLen = (socklen_t)sizeof(tAddr);

	ret = getsockname(fd, (SOCKADDR*)&tAddr, &nLen);
	if (ret != 0)
	{
		return -1;
	}

	copy_ip_out(&tAddr, ip_buf, p_port);

	return 0;
}

C_API int socket_peeraddr(int fd, char *ip_buf, int *p_port)
{
	struct sockaddr_in tAddr;
	socklen_t nLen;
	int ret;

	memset(&tAddr, 0, sizeof(tAddr));
	nLen = (socklen_t)sizeof(tAddr);

	ret = getpeername(fd, (SOCKADDR*)&tAddr, &nLen);
	if (ret != 0)
	{
		return -1;
	}

	copy_ip_out(&tAddr, ip_buf, p_port);

	return 0;
}

C_API int socket_listen(int fd)
{
	int ret = (listen(fd, 1000));
	if (ret < 0)
	{
		dump_error("listen fail");
		return -1;
	}
	return 0;
}

C_API int socket_accept(int fd, char *ip_buf, int *p_port)
{
	SOCKADDR_IN tAddr;
	socklen_t nLen;
	int new_fd;

	memset(&tAddr, 0, sizeof(tAddr));
	nLen = (socklen_t)sizeof(tAddr);

	new_fd = (int)accept(fd, (SOCKADDR*)&tAddr, &nLen);
	if (new_fd < 0)
	{
		dump_error("accept fail");
		return -1;
	}

	int on = 1;
	ioctl(new_fd, FIONBIO, &on);
	copy_ip_out(&tAddr, ip_buf, p_port);

	return new_fd;
}

C_API int socket_connect(int fd, const char *ip, int port)
{
	int ret;
	SOCKADDR_IN tAddr;

	memset(&tAddr, 0, sizeof(tAddr));
	tAddr.sin_family = AF_INET; 
	tAddr.sin_addr.s_addr = inet_addr(ip);
	tAddr.sin_port = htons(port);

	ret = connect(fd, (SOCKADDR*)&tAddr, sizeof(tAddr));

	return check_ret(ret, "connect fail");
}

C_API int socket_send(int fd, const char *data, int len, const char *ip, int port)
{
	int ret;

	if (ip && port > 0)
	{
		SOCKADDR_IN tAddr;
		memset(&tAddr, 0, sizeof(tAddr));
		tAddr.sin_family = AF_INET; 
		tAddr.sin_addr.s_addr = inet_addr(ip);
		tAddr.sin_port = htons(port);

		ret = sendto(fd, data, len, 0, (SOCKADDR*)&tAddr, sizeof(tAddr));
	}
	else
	{
		ret = send(fd, data, len, 0);
	}

	return check_ret(ret, "send fail");;
}

C_API int socket_recv(int fd, char *buf, int size, char *ip_buf, int *p_port)
{
	int ret;

	if (ip_buf && p_port)
	{
		SOCKADDR_IN tAddr;
		socklen_t nLen;
		memset(&tAddr, 0, sizeof(tAddr));
		nLen = (socklen_t)sizeof(tAddr);

		ret = recvfrom(fd, buf, size, 0, (SOCKADDR*)&tAddr, &nLen);
	}
	else
	{
		ret = recv(fd, buf, size, 0);
	}

	return check_ret(ret, "recv fail");;
}
 
