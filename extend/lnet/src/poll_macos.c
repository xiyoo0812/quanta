/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifdef __APPLE__

#include "poll.h"
#include <stdlib.h>
#include <pthread.h>
#include <sys/event.h>
#include <sys/time.h>

typedef void (*mfd_callback)(void *mp);
static int i_select(event_t *evs, event_t *evs_out, int size, int timeout, int mfd, mfd_callback mcb, void *mp)
{
	fd_set rd_set;
	fd_set wr_set;
	struct timeval tv, *ptv = NULL;
	int i, maxfd = 0;
	int count = 0;

	if (timeout >= 0)
	{
		tv.tv_sec = timeout/1000;
		tv.tv_usec = (timeout % 1000) * 1000;
		ptv = &tv;
	}

	FD_ZERO(&rd_set);
	FD_ZERO(&wr_set);

	if (mfd != -1)
	{
		FD_SET(mfd, &rd_set);
		maxfd = mfd;
	}

	for (i = 0; i < size; i++)
	{
		if (evs[i].flag & READABLE)
		{
			FD_SET(evs[i].fd, &rd_set);
		}
		if (evs[i].flag & WRITABLE)
		{
			FD_SET(evs[i].fd, &wr_set);
		}

		if (evs[i].fd > maxfd)
		{
			maxfd = evs[i].fd;
		}
	}

	if (select(maxfd + 1, &rd_set, &wr_set, NULL, ptv) > 0)
	{
		if (mfd != -1 && FD_ISSET(mfd, &rd_set))
		{
			mcb(mp);
		}

		for (i = 0; i < size; i++)
		{
			int flag = 0;
			if (FD_ISSET(evs[i].fd, &rd_set))
			{
				flag |= READABLE;
			}
			if (FD_ISSET(evs[i].fd, &wr_set))
			{
				flag |= WRITABLE;
			}

			if (flag > 0)
			{
				evs_out[count].fd = evs[i].fd;
				evs_out[count].flag = flag;
				count++;
			}
		}
	}

	return count;
}

C_API int socket_wait(int fd, int flag, int timeout)
{
	event_t ev, ev_out;
	ev.fd = fd;
	ev.flag = flag;

	if (i_select(&ev, &ev_out, 1, timeout, -1, NULL, NULL) > 0)
	{
		return ev_out.flag;
	}

	return 0;
}

#define POLL_MAGIC 0x20150313
struct poll_t
{
	int magic;
	int kqueuefd;
	pthread_mutex_t mtx;
	int size;
	int num;
	struct kevent *evs;
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
	p->kqueuefd = kqueue();
	p->size = size;
	p->evs = calloc(1, sizeof(struct kevent) * size);
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
	struct kevent kev[2];
	if (mode == POLL_DEL)
	{
		EV_SET(&kev[0], ev->fd, EVFILT_READ, EV_DELETE, 0, 0, (void*)(intptr_t)p->kqueuefd);
		EV_SET(&kev[0], ev->fd, EVFILT_WRITE, EV_DELETE, 0, 0, (void*)(intptr_t)p->kqueuefd);
	}
	else
	{
		if (ev->flag & READABLE) 
		{
			EV_SET(&kev[0], ev->fd, EVFILT_READ, EV_ADD|EV_ENABLE, 0, 0, (void*)(intptr_t)p->kqueuefd);
		}
		if (ev->flag & WRITABLE) 
		{
		    EV_SET(&kev[1], ev->fd, EVFILT_WRITE, EV_ADD|EV_ENABLE, 0, 0, (void*)(intptr_t)p->kqueuefd);	
		}
	}
	ret = kevent(p->kqueuefd, kev, 2, NULL, 0, NULL);
	pthread_mutex_unlock(&p->mtx);
	return ret;
}

C_API int poll_do(poll_handle p, int timeout)
{
	struct timespec to;
	to.tv_sec = timeout / 1000;
	to.tv_nsec = (timeout % 1000) * 1000 * 1000;
	p->num = kevent(p->kqueuefd, NULL, 0, p->evs, p->size, &to);
	return p->num;
}

C_API void poll_event(poll_handle p, int id, event_t *ev)
{
	ev->fd = -1;
	ev->flag = 0;
	if (0 <= id && id < p->num)
	{
		ev->fd = (int)(intptr_t)p->evs[id].udata;
    	int events = p->evs[id].filter;
		if (events & EVFILT_READ) ev->flag |= READABLE;
		if (events & EVFILT_WRITE) ev->flag |= WRITABLE;
	}
}

#endif
