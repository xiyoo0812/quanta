/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifdef WIN32
#define _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_DEPRECATE
#define LUA_BUILD_AS_DLL
#define LUA_LIB
#else
#include <netdb.h>
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "socket.h"
#include "poll.h"

#include <stdlib.h>
#include <string.h>

/************************************************************************/
/* thread                                                               */
/************************************************************************/
typedef void *(*task_t)(void *p);

#ifdef WIN32
#include <windows.h>
static void create_thread(task_t task, void *context)
{
	CreateThread(NULL, 64<<10, (LPTHREAD_START_ROUTINE)task, context, 0, NULL);
}
#else
#include <unistd.h>
#include <pthread.h>
static void create_thread(task_t task, void *context)
{
	pthread_t tid = 0;
	pthread_create(&tid, NULL, task, context);
}
#endif

/************************************************************************/
/* mutex                                                                */
/************************************************************************/
#ifdef WIN32
#define T_MUTEX			CRITICAL_SECTION
#define MUTEX_INIT(m)	InitializeCriticalSection(m)
#define MUTEX_UNINIT(m)	DeleteCriticalSection(m)
#define MUTEX_LOCK(m)	EnterCriticalSection(m)
#define MUTEX_UNLOCK(m)	LeaveCriticalSection(m)
#else
#define T_MUTEX			pthread_mutex_t
#define MUTEX_INIT(m)	pthread_mutex_init(m, NULL)
#define MUTEX_UNINIT(m)	pthread_mutex_destroy(m)
#define MUTEX_LOCK(m)	pthread_mutex_lock(m)
#define MUTEX_UNLOCK(m)	pthread_mutex_unlock(m)
#endif

/************************************************************************/
/* simple sync for lua                                                  */
/************************************************************************/
static T_MUTEX g_mtx;

static int _enter_sync(lua_State *L)
{
	MUTEX_LOCK(&g_mtx);
	return 0;
}

static int _leave_sync(lua_State *L)
{
	MUTEX_UNLOCK(&g_mtx);
	return 0;
}

/************************************************************************/
/* socket for lua                                                       */
/************************************************************************/
static int _tcp(lua_State *L)
{
	const char *ip = NULL;
	int port = 0;
	int fd;
	int count = lua_gettop(L);
	if (count == 2)
	{
		ip = luaL_checkstring(L, 1);
		port = (int)luaL_checkinteger(L, 2);
	}
	fd = socket_tcp(ip, port);
	lua_pushinteger(L, fd);
	lua_pushstring(L, socket_error());
	return 2;
}

static int _udp(lua_State *L)
{
	const char *ip = NULL;
	int port = 0;
	int fd;
	int count = lua_gettop(L);
	if (count == 2)
	{
		ip = luaL_checkstring(L, 1);
		port = (int)luaL_checkinteger(L, 2);
	}
	fd = socket_udp(ip, port);
	lua_pushinteger(L, fd);
	lua_pushstring(L, socket_error());
	return 2;
}

static int _close(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	int ret = socket_close(fd);
	lua_pushinteger(L, ret);
	lua_pushstring(L, socket_error());
	return 2;
}

static int _connect(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	const char *ip = luaL_checkstring(L, 2);
	int port = (int)luaL_checkinteger(L, 3);
	int ret = socket_connect(fd, ip, port);
	lua_pushinteger(L, ret);
	lua_pushstring(L, socket_error());
	return 2;
}

static int _listen(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	int ret = socket_listen(fd);
	lua_pushinteger(L, ret);
	lua_pushstring(L, socket_error());
	return 2;
}

static int _accept(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	char ip[64] = {0};
	int port = 0;
	int ret = socket_accept(fd, ip, &port);
	lua_pushinteger(L, ret);
	lua_pushstring(L, socket_error());
	lua_pushstring(L, ip);
	lua_pushinteger(L, port);
	return 4;
}

static int _send(lua_State *L)
{
	int count = lua_gettop(L);
	int fd = (int)luaL_checkinteger(L, 1);
	size_t data_len = 0;
	const char *data = luaL_checklstring(L, 2, &data_len);
	const char *ip = NULL;
	int port = 0;
	int ret;
	if (count == 4)
	{
		ip = luaL_checkstring(L, 3);
		port = (int)luaL_checkinteger(L, 4);
	}
	ret = socket_send(fd, data, (int)data_len, NULL, 0);
	lua_pushinteger(L, ret);
	lua_pushstring(L, socket_error());
	return 2;
}

#define RCV_STACK_SIZE 8192
static int _recv(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	int size = (int)luaL_checkinteger(L, 2);
	char buf_stack[RCV_STACK_SIZE];
	char *buf = size > RCV_STACK_SIZE ? malloc(size) : buf_stack;
	char *ip = NULL;
	int port = 0;
	if (lua_gettop(L) == 4)
	{
		ip = luaL_checkstring(L, 3);
		port = (int)luaL_checkinteger(L, 4);
	}
	int ret = socket_recv(fd, buf, size, ip, &port);
	lua_pushinteger(L, ret);
	if (ret < 0) lua_pushstring(L, socket_error()); else lua_pushlstring(L, buf, ret);
	if (buf != buf_stack ) free(buf);
	return 2;
}

static int _wait(lua_State *L)
{
	int fd = (int)luaL_checkinteger(L, 1);
	int bread = (int)lua_toboolean(L, 2);
	int bwrite = (int)lua_toboolean(L, 3);
	int timeout = (int)luaL_checkinteger(L, 4);
	int flag_in = 0, flag_out = 0;
	if (bread) flag_in |= READABLE;
	if (bwrite) flag_in |= WRITABLE;
	flag_out = socket_wait(fd, flag_in, timeout);
	lua_pushboolean(L, flag_out & READABLE);
	lua_pushboolean(L, flag_out & WRITABLE);
	return 2;
}

static int _gethostbyname(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	struct hostent *answer = gethostbyname(name);
	if (answer)
	{
		char ipstr[64] = {0};
		unsigned char *ip = (unsigned char *)answer->h_addr_list[0];
		sprintf(ipstr, "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
		lua_pushstring(L, ipstr);
		return 1;
	}
	return 0;
}

/************************************************************************/
/* poll for lua                                                         */
/************************************************************************/
static int _create_poll(lua_State *L)
{
	int size = (int)luaL_checkinteger(L, 1);
	poll_handle p = poll_create(size);
	lua_pushlightuserdata(L, p);
	return 1;
}

static int _destroy_poll(lua_State *L)
{
	poll_handle p = lua_touserdata(L, 1);
	luaL_argcheck(L, check_poll(p), 1, "'poll' expected");
	poll_destroy(p);
	return 0;
}

static int _control_poll(lua_State *L)
{
	poll_handle p = lua_touserdata(L, 1);
	int fd = (int)luaL_checkinteger(L, 2);
	int mode = (int)luaL_checkinteger(L, 3);
	event_t ev;
	luaL_argcheck(L, check_poll(p), 1, "'poll' expected");
	ev.fd = fd;
	ev.flag = 0;
	if (mode == POLL_ADD || mode == POLL_MOD)
	{
		int bread = 0;
		int bwrite = 0;
		bread = lua_toboolean(L, 4);
		bwrite = lua_toboolean(L, 5);
		if (bread) ev.flag |= READABLE;
		if (bwrite) ev.flag |= WRITABLE;
	}
	poll_control(p, mode, &ev);
	return 0;
}

static int _do_poll(lua_State *L)
{
	int n;
	poll_handle p = lua_touserdata(L, 1);
	int timeout = (int)luaL_checkinteger(L, 2);
	luaL_argcheck(L, check_poll(p), 1, "'poll' expected");
	n = poll_do(p, timeout);
	lua_pushinteger(L, n);
	return 1;
}

static int _get_event(lua_State *L)
{
	poll_handle p = lua_touserdata(L, 1);
	int id = (int)luaL_checkinteger(L, 2);
	event_t ev;
	luaL_argcheck(L, check_poll(p), 1, "'poll' expected");
	poll_event(p, id - 1, &ev);
	lua_pushinteger(L, ev.fd);
	lua_pushboolean(L, ev.flag & READABLE);
	lua_pushboolean(L, ev.flag & WRITABLE);
	return 3;
}

typedef struct
{
	poll_handle p;
	const char *filename;
	int id;
	const char *ctxstring;
} thread_info_t;

void *thread_task(void *p)
{
	thread_info_t info;
	lua_State *L;

	memcpy(&info, p, sizeof(info));
	free(p);

	L = luaL_newstate();
	luaL_openlibs(L);

	lua_pushinteger(L, info.id);
	lua_setglobal(L, "_THREADID");
	lua_pushlightuserdata(L, info.p);
	lua_setglobal(L, "_POLL");
	lua_pushstring(L, info.ctxstring);
	lua_setglobal(L, "_CTXSTRING"); 

	if (luaL_loadfile(L, info.filename) || lua_pcall(L, 0, 0, 0))
	{
		printf("\nlnet thread[%d] panic: %s\n", info.id, lua_tostring(L, -1));
		exit(-1);
	}

	lua_close(L);

	return 0;
}

static int _poll_thread(lua_State *L)
{
	poll_handle p = lua_touserdata(L, 1);
	const char *filename = luaL_checkstring(L, 2);
	int id = (int)luaL_checkinteger(L, 3);
	const char *ctxstring = luaL_checkstring(L, 4);
	luaL_argcheck(L, check_poll(p), 1, "'poll' expected");
	{
		thread_info_t *info = calloc(1, sizeof(*info));
		info->p = p;
		info->filename = filename;
		info->id = id;
		info->ctxstring = ctxstring;
		create_thread(thread_task, info);
	}
	return 0;
}

/************************************************************************/
/* register                                                             */
/************************************************************************/
static const struct luaL_Reg lnetlib[] = {
	{"enter_sync", _enter_sync},
	{"leave_sync", _leave_sync},
	{"tcp", _tcp},
	{"udp", _udp},
	{"close", _close},
	{"listen", _listen},
	{"accept", _accept},
	{"connect", _connect},
	{"send", _send},
	{"recv", _recv},
	{"wait", _wait},
	{"gethostbyname", _gethostbyname},
	{"create_poll", _create_poll},
	{"destroy_poll", _destroy_poll},
	{"control_poll", _control_poll},
	{"do_poll", _do_poll},
	{"get_event", _get_event},
	{"poll_thread", _poll_thread},
	{NULL, NULL}
};

LUALIB_API int luaopen_lnet(lua_State *L)
{
	MUTEX_INIT(&g_mtx);
	socket_startup();
	luaL_newlib(L, lnetlib);
	lua_pushvalue(L, -1);
	lua_setglobal(L, "lnet");
	return 1;
}
