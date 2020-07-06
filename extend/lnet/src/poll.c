/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifndef WIN32

#include "poll.h"
#include <stdlib.h>
#include <pthread.h>
#include <sys/poll.h>
#include <sys/epoll.h>

C_API int socket_wait(int fd, int flag, int timeout)
{
	int flag_out = 0;
	struct pollfd pfd;

	pfd.fd = fd;
	pfd.events = 0;

	if (flag & READABLE)
	{
		pfd.events |= POLLIN;
	}
	if (flag & WRITABLE)
	{
		pfd.events |= POLLOUT;
	}

	if (poll(&pfd, 1, timeout) > 0)
	{
		if (pfd.revents & POLLIN)
		{
			flag_out |= READABLE;
		}

		if (pfd.revents & POLLOUT)
		{
			flag_out |= WRITABLE;
		}
	}

	return flag_out;
}

#define POLL_MAGIC 0x20150313
struct poll_t
{
	int magic;
	int epfd;
	pthread_mutex_t mtx;
	int size;
	int num;
	struct epoll_event *evs;
};

C_API int check_poll(poll_handle p)
{
	if (p && p->magic == POLL_MAGIC)
	{
		return 1;
	}
	return 0;
}

C_API poll_handle poll_create(int size)
{
	struct poll_t *p = calloc(1, sizeof(struct poll_t));
	if (size <= 0) size = 1024;
	p->magic = POLL_MAGIC;
	pthread_mutex_init(&p->mtx, NULL);
	p->epfd = epoll_create(size);
	p->size = size;
	p->evs = calloc(1, sizeof(struct epoll_event) * size);
	return p;
}

C_API void poll_destroy(poll_handle p)
{
	pthread_mutex_destroy(&p->mtx);
	free(p->evs);
	free(p);
}

C_API int poll_control(poll_handle p, int mode, const event_t *ev)
{
	int ret;
	pthread_mutex_lock(&p->mtx);
	if (mode == POLL_DEL)
	{
		ret = epoll_ctl(p->epfd, EPOLL_CTL_DEL, ev->fd, NULL);
	}
	else
	{
		struct epoll_event epev = {0};
		epev.data.fd = ev->fd;
		if (ev->flag & READABLE) epev.events |= EPOLLIN;
		if (ev->flag & WRITABLE) epev.events |= EPOLLOUT;
		if (mode == POLL_ADD)
		{
			ret = epoll_ctl(p->epfd, EPOLL_CTL_ADD, ev->fd, &epev);
		}
		else
		{
			ret = epoll_ctl(p->epfd, EPOLL_CTL_MOD, ev->fd, &epev);
		}
	}
	pthread_mutex_unlock(&p->mtx);
	return ret;
}

C_API int poll_do(poll_handle p, int timeout)
{
	p->num = epoll_wait(p->epfd, p->evs, p->size, timeout);
	return p->num;
}

C_API void poll_event(poll_handle p, int id, event_t *ev)
{
	ev->fd = -1;
	ev->flag = 0;
	if (0 <= id && id < p->num)
	{
		struct epoll_event *epev = &p->evs[id];
		ev->fd = epev->data.fd;
		if (epev->events & EPOLLIN) ev->flag |= READABLE;
		if (epev->events & EPOLLOUT) ev->flag |= WRITABLE;
	}
}

#endif
