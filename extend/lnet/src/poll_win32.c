/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifdef WIN32

#include "poll.h"
#include <winsock2.h>

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
	int size;
	int cfd;
	int mfd;
	char mip[64];
	int mport;
	int n;
	event_t *evs;
	int n_out;
	event_t *evs_out;
	DWORD tid;
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
	if (size <= 0) size = FD_SETSIZE;
	p->magic = POLL_MAGIC;
	p->size = size;
	p->cfd = socket_udp("127.0.0.1", 0);
	p->mfd = socket_udp("127.0.0.1", 0);
	socket_localaddr(p->mfd, p->mip, &p->mport);
	p->evs = calloc(1, sizeof(event_t) * size);
	p->evs_out = calloc(1, sizeof(event_t) * size);
	return p;
}

C_API void poll_destroy(poll_handle p)
{
	socket_close(p->cfd);
	socket_close(p->mfd);
	free(p->evs);
	free(p->evs_out);
	free(p);
}

static int find_fd(poll_handle p, int fd)
{
	int i;
	for (i = 0; i < p->n; i++)
	{
		if (p->evs[i].fd == fd)
		{
			return i;
		}
	}
	return -1;
}

C_API int poll_control_inthread(poll_handle p, const event_t *ev)
{
	int id = find_fd(p, ev->fd);
	if (ev->flag > 0)
	{
		if (id >= 0)
		{
			p->evs[id] = *ev;
		}
		else if (p->n < p->size)
		{
			p->evs[p->n++] = *ev;
		}
	}
	else if (id >= 0)
	{
		p->evs[id] = p->evs[p->n - 1];
		p->n--;
	}
	return 0;
}

C_API int poll_control(poll_handle p, int mode, const event_t *ev)
{
	if (GetCurrentThreadId() == p->tid)
	{
		poll_control_inthread(p, ev);
	}
	else
	{
		socket_send(p->cfd, (const char *)ev, (int)sizeof(*ev), p->mip, p->mport);
	}
	return 0;
}

static void poll_mfd_callback(void *mp)
{
	poll_handle p = (poll_handle)mp;
	event_t ev;
	int rcvlen = socket_recv(p->mfd, (char *)&ev, (int)sizeof(ev), NULL, 0);
	if (rcvlen == (int)sizeof(ev))
	{
		poll_control_inthread(p, &ev);
	}
}

C_API int poll_do(poll_handle p, int timeout)
{
	p->tid = GetCurrentThreadId();
	p->n_out = i_select(p->evs, p->evs_out, p->n, timeout, p->mfd, poll_mfd_callback, p);
	return p->n_out;
}

C_API void poll_event(poll_handle p, int id, event_t *ev)
{
	if (0 <= id && id < p->n_out)
	{
		*ev = p->evs_out[id];
	}
	else
	{
		ev->fd = -1;
		ev->flag = 0;
	}
}

#endif
