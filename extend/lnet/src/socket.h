/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifndef _SOCKET_H_
#define _SOCKET_H_

#ifdef __cplusplus
#define C_API	extern "C" 
#else
#define C_API	extern
#endif

#ifdef WIN32
#pragma comment(lib,"Ws2_32.lib")
#endif

C_API void socket_startup();
C_API void socket_cleanup();

C_API const char *socket_error();

C_API int socket_tcp(const char *ip, int port);
C_API int socket_udp(const char *ip, int port);
C_API int socket_close(int fd);

C_API int socket_localaddr(int fd, char *ip_buf, int *p_port);
C_API int socket_peeraddr(int fd, char *ip_buf, int *p_port);

C_API int socket_listen(int fd);
C_API int socket_accept(int fd, char *ip_buf, int *p_port);
C_API int socket_connect(int fd, const char *ip, int port);

C_API int socket_send(int fd, const char *data, int len, const char *ip, int port);
C_API int socket_recv(int fd, char *buf, int size, char *ip_buf, int *p_port);

#endif
