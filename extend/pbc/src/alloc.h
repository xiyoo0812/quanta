#ifndef PROTOBUF_C_ALLOC_H
#define PROTOBUF_C_ALLOC_H

#include <stdlib.h>
#include <string.h>

void * _pbcM_malloc(size_t sz);
void _pbcM_free(void *p);
void * _pbcM_realloc(void *p, size_t sz);
void _pbcM_memory();

struct heap;

struct heap * _pbcH_new(int pagesize);
void _pbcH_delete(struct heap *);
void* _pbcH_alloc(struct heap *, int size);

#define HMALLOC(size) ((h) ? _pbcH_alloc(h, size) : _pbcM_malloc(size))

#ifdef malloc
#undef malloc
#endif

#ifdef free
#undef free
#endif

#ifdef realloc
#undef realloc
#endif

#define malloc _pbcM_malloc
#define free _pbcM_free
#define realloc _pbcM_realloc
#define memory _pbcM_memory



#ifdef _MSC_VER

#define alloca _alloca

#endif

#endif
