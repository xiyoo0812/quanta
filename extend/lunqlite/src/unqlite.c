/*
 * Symisc UnQLite-KV: A Transactional Key/Value Database Engine.
 * Copyright (C) 2016 - 2022, Symisc Systems http://unqlite.symisc.net/
 * Copyright (C) 2014, Yuras Shumovich <shumovichy@gmail.com>
 * Version 1.4
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
/*
 * Copyright (C) 2012, 2022 Symisc Systems, S.U.A.R.L [M.I.A.G Mrad Chems Eddine <chm@symisc.net>].
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY SYMISC SYSTEMS ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
 * NON-INFRINGEMENT, ARE DISCLAIMED.  IN NO EVENT SHALL SYMISC SYSTEMS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/*
 * $SymiscID: unqlite.c v1.1.4 Win10 2025-04-25 03:54:12 stable <chm@symisc.net> $ 
 */
/* This file is an amalgamation of many separate C source files from unqlite version 1.4
 * By combining all the individual C code files into this single large file, the entire code
 * can be compiled as a single translation unit. This allows many compilers to do optimization's
 * that would not be possible if the files were compiled separately. Performance improvements
 * are commonly seen when unqlite is compiled as a single translation unit.
 *
 * This file is all you need to compile unqlite. To use unqlite in other programs, you need
 * this file and the "unqlite.h" header file that defines the programming interface to the 
 * unqlite engine.(If you do not have the "unqlite.h" header file at hand, you will find
 * a copy embedded within the text of this file.Search for "Header file: <unqlite.h>" to find
 * the start of the embedded unqlite.h header file.) Additional code files may be needed if
 * you want a wrapper to interface unqlite with your choice of programming language.
 * To get the official documentation, please visit http://unqlite.symisc.net/
 */
 /*
  * Make the sure the following directive is defined in the amalgamation build.
  */
 #ifndef UNQLITE_AMALGAMATION
 #define UNQLITE_AMALGAMATION
 #endif /* UNQLITE_AMALGAMATION */
#include "unqlite.h"
/*
 * ----------------------------------------------------------
 * File: unqliteInt.h
 * ID: 325816ce05f6adbaab2c39a41875dedd
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2016, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: unqliteInt.h v1.7 FreeBSD 2012-11-02 11:25 devel <chm@symisc.net> $ */
#ifndef __UNQLITEINT_H__
#define __UNQLITEINT_H__
#include <string.h>
/* Internal interface definitions for UnQLite. */
/* Marker for routines not intended for external use */
#define UNQLITE_PRIVATE static
/*
 * Constants for the largest and smallest possible 64-bit signed integers.
 * These macros are designed to work correctly on both 32-bit and 64-bit
 * compilers.
 */
#ifndef LARGEST_INT64
#define LARGEST_INT64  (0xffffffff|(((sxi64)0x7fffffff)<<32))
#endif
#ifndef SMALLEST_INT64
#define SMALLEST_INT64 (((sxi64)-1) - LARGEST_INT64)
#endif
/* Forward declaration of private structures */
typedef struct jx9_foreach_info   jx9_foreach_info;
typedef struct jx9_foreach_step   jx9_foreach_step;
typedef struct jx9_hashmap_node   jx9_hashmap_node;
typedef struct jx9_hashmap        jx9_hashmap;
/* Symisc Standard types */
#if !defined(SYMISC_STD_TYPES)
#define SYMISC_STD_TYPES
#ifdef __WINNT__
/* Disable nuisance warnings on Borland compilers */
#if defined(__BORLANDC__)
#pragma warn -rch /* unreachable code */
#pragma warn -ccc /* Condition is always true or false */
#pragma warn -aus /* Assigned value is never used */
#pragma warn -csu /* Comparing signed and unsigned */
#pragma warn -spa /* Suspicious pointer arithmetic */
#endif
#endif
typedef signed char        sxi8; /* signed char */
typedef unsigned char      sxu8; /* unsigned char */
typedef signed short int   sxi16; /* 16 bits(2 bytes) signed integer */
typedef unsigned short int sxu16; /* 16 bits(2 bytes) unsigned integer */
typedef int                sxi32; /* 32 bits(4 bytes) integer */
typedef unsigned int       sxu32; /* 32 bits(4 bytes) unsigned integer */
typedef long               sxptr;
typedef unsigned long      sxuptr;
typedef long               sxlong;
typedef unsigned long      sxulong;
typedef sxi32              sxofft;
typedef sxi64              sxofft64;
typedef long double	       sxlongreal;
typedef double             sxreal;
#define SXI8_HIGH       0x7F
#define SXU8_HIGH       0xFF
#define SXI16_HIGH      0x7FFF
#define SXU16_HIGH      0xFFFF
#define SXI32_HIGH      0x7FFFFFFF
#define SXU32_HIGH      0xFFFFFFFF
#define SXI64_HIGH      0x7FFFFFFFFFFFFFFF
#define SXU64_HIGH      0xFFFFFFFFFFFFFFFF 
#if !defined(TRUE)
#define TRUE 1
#endif
#if !defined(FALSE)
#define FALSE 0
#endif
/*
 * The following macros are used to cast pointers to integers and
 * integers to pointers.
 */
#if defined(__PTRDIFF_TYPE__)  
# define SX_INT_TO_PTR(X)  ((void*)(__PTRDIFF_TYPE__)(X))
# define SX_PTR_TO_INT(X)  ((int)(__PTRDIFF_TYPE__)(X))
#elif !defined(__GNUC__)    
# define SX_INT_TO_PTR(X)  ((void*)&((char*)0)[X])
# define SX_PTR_TO_INT(X)  ((int)(((char*)X)-(char*)0))
#else                       
# define SX_INT_TO_PTR(X)  ((void*)(X))
# define SX_PTR_TO_INT(X)  ((int)(X))
#endif
#define SXMIN(a, b)  ((a < b) ? (a) : (b))
#define SXMAX(a, b)  ((a < b) ? (b) : (a))
#endif /* SYMISC_STD_TYPES */
/* Symisc Run-time API private definitions */
#if !defined(SYMISC_PRIVATE_DEFS)
#define SYMISC_PRIVATE_DEFS

typedef sxi32 (*ProcRawStrCmp)(const SyString *, const SyString *);
#define SyStringData(RAW)	((RAW)->zString)
#define SyStringLength(RAW)	((RAW)->nByte)
#define SyStringInitFromBuf(RAW, ZBUF, NLEN){\
	(RAW)->zString 	= (const char *)ZBUF;\
	(RAW)->nByte	= (sxu32)(NLEN);\
}
#define SyStringUpdatePtr(RAW, NBYTES){\
	if( NBYTES > (RAW)->nByte ){\
		(RAW)->nByte = 0;\
	}else{\
		(RAW)->zString += NBYTES;\
		(RAW)->nByte -= NBYTES;\
	}\
}
#define SyStringDupPtr(RAW1, RAW2)\
	(RAW1)->zString = (RAW2)->zString;\
	(RAW1)->nByte = (RAW2)->nByte;

#define SyStringTrimLeadingChar(RAW, CHAR)\
	while((RAW)->nByte > 0 && (RAW)->zString[0] == CHAR ){\
			(RAW)->zString++;\
			(RAW)->nByte--;\
	}
#define SyStringTrimTrailingChar(RAW, CHAR)\
	while((RAW)->nByte > 0 && (RAW)->zString[(RAW)->nByte - 1] == CHAR){\
		(RAW)->nByte--;\
	}
#define SyStringCmp(RAW1, RAW2, xCMP)\
	(((RAW1)->nByte == (RAW2)->nByte) ? xCMP((RAW1)->zString, (RAW2)->zString, (RAW2)->nByte) : (sxi32)((RAW1)->nByte - (RAW2)->nByte))

#define SyStringCmp2(RAW1, RAW2, xCMP)\
	(((RAW1)->nByte >= (RAW2)->nByte) ? xCMP((RAW1)->zString, (RAW2)->zString, (RAW2)->nByte) : (sxi32)((RAW2)->nByte - (RAW1)->nByte))

#define SyStringCharCmp(RAW, CHAR) \
	(((RAW)->nByte == sizeof(char)) ? ((RAW)->zString[0] == CHAR ? 0 : CHAR - (RAW)->zString[0]) : ((RAW)->zString[0] == CHAR ? 0 : (RAW)->nByte - sizeof(char)))

#define SX_ADDR(PTR)    ((sxptr)PTR)
#define SX_ARRAYSIZE(X) (sizeof(X)/sizeof(X[0]))
#define SXUNUSED(P) ((void)P)
#define	SX_EMPTY(PTR)   (PTR == 0)
#define SX_EMPTY_STR(STR) (STR == 0 || STR[0] == 0 )
typedef struct SyMemBackend SyMemBackend;
typedef struct SyBlob SyBlob;
typedef struct SySet SySet;
/* Standard function signatures */
typedef sxi32 (*ProcCmp)(const void *, const void *, sxu32);
typedef sxi32 (*ProcPatternMatch)(const char *, sxu32, const char *, sxu32, sxu32 *);
typedef sxi32 (*ProcSearch)(const void *, sxu32, const void *, sxu32, ProcCmp, sxu32 *);
typedef sxu32 (*ProcHash)(const void *, sxu32);
typedef sxi32 (*ProcHashSum)(const void *, sxu32, unsigned char *, sxu32);
typedef sxi32 (*ProcSort)(void *, sxu32, sxu32, ProcCmp);
#define MACRO_LIST_PUSH(Head, Item)\
	Item->pNext = Head;\
	Head = Item; 
#define MACRO_LD_PUSH(Head, Item)\
	if( Head == 0 ){\
		Head = Item;\
	}else{\
		Item->pNext = Head;\
		Head->pPrev = Item;\
		Head = Item;\
	}
#define MACRO_LD_REMOVE(Head, Item)\
	if( Head == Item ){\
		Head = Head->pNext;\
	}\
	if( Item->pPrev ){ Item->pPrev->pNext = Item->pNext;}\
	if( Item->pNext ){ Item->pNext->pPrev = Item->pPrev;}
/*
 * A generic dynamic set.
 */
struct SySet
{
	SyMemBackend *pAllocator; /* Memory backend */
	void *pBase;              /* Base pointer */	
	sxu32 nUsed;              /* Total number of used slots  */
	sxu32 nSize;              /* Total number of available slots */
	sxu32 eSize;              /* Size of a single slot */
	sxu32 nCursor;	          /* Loop cursor */	
	void *pUserData;          /* User private data associated with this container */
};
#define SySetBasePtr(S)           ((S)->pBase)
#define SySetBasePtrJump(S, OFFT)  (&((char *)(S)->pBase)[OFFT*(S)->eSize])
#define SySetUsed(S)              ((S)->nUsed)
#define SySetSize(S)              ((S)->nSize)
#define SySetElemSize(S)          ((S)->eSize) 
#define SySetCursor(S)            ((S)->nCursor)
#define SySetGetAllocator(S)      ((S)->pAllocator)
#define SySetSetUserData(S, DATA)  ((S)->pUserData = DATA)
#define SySetGetUserData(S)       ((S)->pUserData)
/*
 * A variable length containers for generic data.
 */
struct SyBlob
{
	SyMemBackend *pAllocator; /* Memory backend */
	void   *pBlob;	          /* Base pointer */
	sxu32  nByte;	          /* Total number of used bytes */
	sxu32  mByte;	          /* Total number of available bytes */
	sxu32  nFlags;	          /* Blob internal flags, see below */
};
#define SXBLOB_LOCKED	0x01	/* Blob is locked [i.e: Cannot auto grow] */
#define SXBLOB_STATIC	0x02	/* Not allocated from heap   */
#define SXBLOB_RDONLY   0x04    /* Read-Only data */

#define SyBlobFreeSpace(BLOB)	 ((BLOB)->mByte - (BLOB)->nByte)
#define SyBlobLength(BLOB)	     ((BLOB)->nByte)
#define SyBlobData(BLOB)	     ((BLOB)->pBlob)
#define SyBlobCurData(BLOB)	     ((void*)(&((char*)(BLOB)->pBlob)[(BLOB)->nByte]))
#define SyBlobDataAt(BLOB, OFFT)	 ((void *)(&((char *)(BLOB)->pBlob)[OFFT]))
#define SyBlobGetAllocator(BLOB) ((BLOB)->pAllocator)

#define SXMEM_POOL_INCR			3
#define SXMEM_POOL_NBUCKETS		12
#define SXMEM_BACKEND_MAGIC	0xBAC3E67D
#define SXMEM_BACKEND_CORRUPT(BACKEND)	(BACKEND == 0 || BACKEND->nMagic != SXMEM_BACKEND_MAGIC)

#define SXMEM_BACKEND_RETRY	3
/* A memory backend subsystem is defined by an instance of the following structures */
typedef union SyMemHeader SyMemHeader;
typedef struct SyMemBlock SyMemBlock;
struct SyMemBlock
{
	SyMemBlock *pNext, *pPrev; /* Chain of allocated memory blocks */
#ifdef UNTRUST
	sxu32 nGuard;             /* magic number associated with each valid block, so we
							   * can detect misuse.
							   */
#endif
};
/*
 * Header associated with each valid memory pool block.
 */
union SyMemHeader
{
	SyMemHeader *pNext; /* Next chunk of size 1 << (nBucket + SXMEM_POOL_INCR) in the list */
	sxu32 nBucket;      /* Bucket index in aPool[] */
};
struct SyMemBackend
{
	const SyMutexMethods *pMutexMethods; /* Mutex methods */
	const SyMemMethods *pMethods;  /* Memory allocation methods */
	SyMemBlock *pBlocks;           /* List of valid memory blocks */
	sxu32 nBlock;                  /* Total number of memory blocks allocated so far */
	ProcMemError xMemError;        /* Out-of memory callback */
	void *pUserData;               /* First arg to xMemError() */
	SyMutex *pMutex;               /* Per instance mutex */
	sxu32 nMagic;                  /* Sanity check against misuse */
	SyMemHeader *apPool[SXMEM_POOL_NBUCKETS+SXMEM_POOL_INCR]; /* Pool of memory chunks */
};
/* Mutex types */
#define SXMUTEX_TYPE_FAST	1
#define SXMUTEX_TYPE_RECURSIVE	2
#define SXMUTEX_TYPE_STATIC_1	3
#define SXMUTEX_TYPE_STATIC_2	4
#define SXMUTEX_TYPE_STATIC_3	5
#define SXMUTEX_TYPE_STATIC_4	6
#define SXMUTEX_TYPE_STATIC_5	7
#define SXMUTEX_TYPE_STATIC_6	8

#define SyMutexGlobalInit(METHOD){\
	if( (METHOD)->xGlobalInit ){\
	(METHOD)->xGlobalInit();\
	}\
}
#define SyMutexGlobalRelease(METHOD){\
	if( (METHOD)->xGlobalRelease ){\
	(METHOD)->xGlobalRelease();\
	}\
}
#define SyMutexNew(METHOD, TYPE)			(METHOD)->xNew(TYPE)
#define SyMutexRelease(METHOD, MUTEX){\
	if( MUTEX && (METHOD)->xRelease ){\
		(METHOD)->xRelease(MUTEX);\
	}\
}
#define SyMutexEnter(METHOD, MUTEX){\
	if( MUTEX ){\
	(METHOD)->xEnter(MUTEX);\
	}\
}
#define SyMutexTryEnter(METHOD, MUTEX){\
	if( MUTEX && (METHOD)->xTryEnter ){\
	(METHOD)->xTryEnter(MUTEX);\
	}\
}
#define SyMutexLeave(METHOD, MUTEX){\
	if( MUTEX ){\
	(METHOD)->xLeave(MUTEX);\
	}\
}
/* Comparison, byte swap, byte copy macros */
#define SyZero(PTR,NBYTES) memset(PTR, 0, NBYTES)
#define SyStrlen(STR) strlen(STR)
#define	SX_MACRO_FAST_MEMCPY(SRC, DST, SIZ) memcpy(DST,SRC,SIZ)
#define SX_MSEC_PER_SEC	(1000)			/* Millisec per seconds */
#define SX_USEC_PER_SEC	(1000000)		/* Microsec per seconds */
#define SX_NSEC_PER_SEC	(1000000000)	/* Nanosec per seconds */
#endif /* SYMISC_PRIVATE_DEFS */
/* Symisc Run-time API auxiliary definitions */
#if !defined(SYMISC_PRIVATE_AUX_DEFS)
#define SYMISC_PRIVATE_AUX_DEFS

typedef struct SyHashEntry_Pr SyHashEntry_Pr;
typedef struct SyHashEntry SyHashEntry;
typedef struct SyHash SyHash;
/*
 * Each public hashtable entry is represented by an instance
 * of the following structure.
 */
struct SyHashEntry
{
	const void *pKey; /* Hash key */
	sxu32 nKeyLen;    /* Key length */
	void *pUserData;  /* User private data */
};
#define SyHashEntryGetUserData(ENTRY) ((ENTRY)->pUserData)
#define SyHashEntryGetKey(ENTRY)      ((ENTRY)->pKey)
/* Each active hashtable is identified by an instance of the following structure */
struct SyHash
{
	SyMemBackend *pAllocator;         /* Memory backend */
	ProcHash xHash;                   /* Hash function */
	ProcCmp xCmp;                     /* Comparison function */
	SyHashEntry_Pr *pList, *pCurrent;  /* Linked list of hash entries user for linear traversal */
	sxu32 nEntry;                     /* Total number of entries */
	SyHashEntry_Pr **apBucket;        /* Hash buckets */
	sxu32 nBucketSize;                /* Current bucket size */
};
#define SXHASH_BUCKET_SIZE 16 /* Initial bucket size: must be a power of two */
#define SXHASH_FILL_FACTOR 3
/* Hash access macro */
#define SyHashFunc(HASH)		((HASH)->xHash)
#define SyHashCmpFunc(HASH)		((HASH)->xCmp)
#define SyHashTotalEntry(HASH)	((HASH)->nEntry)
#define SyHashGetPool(HASH)		((HASH)->pAllocator)
/*
 * An instance of the following structure define a single context
 * for an Pseudo Random Number Generator.
 *
 * Nothing in this file or anywhere else in the library does any kind of
 * encryption.  The RC4 algorithm is being used as a PRNG (pseudo-random
 * number generator) not as an encryption device.
 * This implementation is taken from the SQLite3 source tree.
 */
typedef struct SyPRNGCtx SyPRNGCtx;
struct SyPRNGCtx
{
    sxu8 i, j;				/* State variables */
    unsigned char s[256];   /* State variables */
	sxu16 nMagic;			/* Sanity check */
 };
typedef sxi32 (*ProcRandomSeed)(void *, unsigned int, void *);
/* High resolution timer.*/
typedef struct sytime sytime;
struct sytime
{
	long tm_sec;	/* seconds */
	long tm_usec;	/* microseconds */
};
/* Forward declaration */
typedef struct SyStream SyStream;
typedef struct SyToken  SyToken;
typedef struct SyLex    SyLex;
/*
 * Tokenizer callback signature.
 */
typedef sxi32 (*ProcTokenizer)(SyStream *, SyToken *, void *, void *);
/*
 * Each token in the input is represented by an instance
 * of the following structure.
 */
struct SyToken
{
	SyString sData;  /* Token text and length */
	sxu32 nType;     /* Token type */
	sxu32 nLine;     /* Token line number */
	void *pUserData; /* User private data associated with this token */
};
/*
 * During tokenization, information about the state of the input
 * stream is held in an instance of the following structure.
 */
struct SyStream
{
	const unsigned char *zInput; /* Complete text of the input */
	const unsigned char *zText; /* Current input we are processing */	
	const unsigned char *zEnd; /* End of input marker */
	sxu32  nLine; /* Total number of processed lines */
	sxu32  nIgn; /* Total number of ignored tokens */
	SySet *pSet; /* Token containers */
};
/*
 * Each lexer is represented by an instance of the following structure.
 */
struct SyLex
{
	SyStream sStream;         /* Input stream */
	ProcTokenizer xTokenizer; /* Tokenizer callback */
	void * pUserData;         /* Third argument to xTokenizer() */
	SySet *pTokenSet;         /* Token set */
};
#define SyLexTotalToken(LEX)    SySetTotalEntry(&(LEX)->aTokenSet)
#define SyLexTotalLines(LEX)    ((LEX)->sStream.nLine)
#define SyLexTotalIgnored(LEX)  ((LEX)->sStream.nIgn)
#define XLEX_IN_LEN(STREAM)     (sxu32)(STREAM->zEnd - STREAM->zText)
#endif /* SYMISC_PRIVATE_AUX_DEFS */
/*
** Notes on UTF-8 (According to SQLite3 authors):
**
**   Byte-0    Byte-1    Byte-2    Byte-3    Value
**  0xxxxxxx                                 00000000 00000000 0xxxxxxx
**  110yyyyy  10xxxxxx                       00000000 00000yyy yyxxxxxx
**  1110zzzz  10yyyyyy  10xxxxxx             00000000 zzzzyyyy yyxxxxxx
**  11110uuu  10uuzzzz  10yyyyyy  10xxxxxx   000uuuuu zzzzyyyy yyxxxxxx
**
*/
/*
** Assuming zIn points to the first byte of a UTF-8 character, 
** advance zIn to point to the first byte of the next UTF-8 character.
*/
#define SX_JMP_UTF8(zIn, zEnd)\
	while(zIn < zEnd && (((unsigned char)zIn[0] & 0xc0) == 0x80) ){ zIn++; }
#define SX_WRITE_UTF8(zOut, c) {                       \
  if( c<0x00080 ){                                     \
    *zOut++ = (sxu8)(c&0xFF);                          \
  }else if( c<0x00800 ){                               \
    *zOut++ = 0xC0 + (sxu8)((c>>6)&0x1F);              \
    *zOut++ = 0x80 + (sxu8)(c & 0x3F);                 \
  }else if( c<0x10000 ){                               \
    *zOut++ = 0xE0 + (sxu8)((c>>12)&0x0F);             \
    *zOut++ = 0x80 + (sxu8)((c>>6) & 0x3F);            \
    *zOut++ = 0x80 + (sxu8)(c & 0x3F);                 \
  }else{                                               \
    *zOut++ = 0xF0 + (sxu8)((c>>18) & 0x07);           \
    *zOut++ = 0x80 + (sxu8)((c>>12) & 0x3F);           \
    *zOut++ = 0x80 + (sxu8)((c>>6) & 0x3F);            \
    *zOut++ = 0x80 + (sxu8)(c & 0x3F);                 \
  }                                                    \
}
/* Rely on the standard ctype */
#include <ctype.h>
#define SyToUpper(c) toupper(c) 
#define SyToLower(c) tolower(c) 
#define SyisUpper(c) isupper(c)
#define SyisLower(c) islower(c)
#define SyisSpace(c) isspace(c)
#define SyisBlank(c) isspace(c)
#define SyisAlpha(c) isalpha(c)
#define SyisDigit(c) isdigit(c)
#define SyisHex(c)	 isxdigit(c)
#define SyisPrint(c) isprint(c)
#define SyisPunct(c) ispunct(c)
#define SyisSpec(c)	 iscntrl(c)
#define SyisCtrl(c)	 iscntrl(c)
#define SyisAscii(c) isascii(c)
#define SyisAlphaNum(c) isalnum(c)
#define SyisGraph(c)     isgraph(c)
#define SyDigToHex(c)    "0123456789ABCDEF"[c & 0x0F] 		
#define SyDigToInt(c)     ((c < 0xc0 && SyisDigit(c))? (c - '0') : 0 )
#define SyCharToUpper(c)  ((c < 0xc0 && SyisLower(c))? SyToUpper(c) : c)
#define SyCharToLower(c)  ((c < 0xc0 && SyisUpper(c))? SyToLower(c) : c)
/* Remove white space/NUL byte from a raw string */
#define SyStringLeftTrim(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[0] < 0xc0 && SyisSpace((RAW)->zString[0])){\
		(RAW)->nByte--;\
		(RAW)->zString++;\
	}
#define SyStringLeftTrimSafe(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[0] < 0xc0 && ((RAW)->zString[0] == 0 || SyisSpace((RAW)->zString[0]))){\
		(RAW)->nByte--;\
		(RAW)->zString++;\
	}
#define SyStringRightTrim(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[(RAW)->nByte - 1] < 0xc0  && SyisSpace((RAW)->zString[(RAW)->nByte - 1])){\
		(RAW)->nByte--;\
	}
#define SyStringRightTrimSafe(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[(RAW)->nByte - 1] < 0xc0  && \
	(( RAW)->zString[(RAW)->nByte - 1] == 0 || SyisSpace((RAW)->zString[(RAW)->nByte - 1]))){\
		(RAW)->nByte--;\
	}

#define SyStringFullTrim(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[0] < 0xc0  && SyisSpace((RAW)->zString[0])){\
		(RAW)->nByte--;\
		(RAW)->zString++;\
	}\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[(RAW)->nByte - 1] < 0xc0  && SyisSpace((RAW)->zString[(RAW)->nByte - 1])){\
		(RAW)->nByte--;\
	}
#define SyStringFullTrimSafe(RAW)\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[0] < 0xc0  && \
          ( (RAW)->zString[0] == 0 || SyisSpace((RAW)->zString[0]))){\
		(RAW)->nByte--;\
		(RAW)->zString++;\
	}\
	while((RAW)->nByte > 0 && (unsigned char)(RAW)->zString[(RAW)->nByte - 1] < 0xc0  && \
                   ( (RAW)->zString[(RAW)->nByte - 1] == 0 || SyisSpace((RAW)->zString[(RAW)->nByte - 1]))){\
		(RAW)->nByte--;\
	}
UNQLITE_PRIVATE sxi32 SySetRelease(SySet *pSet);
UNQLITE_PRIVATE sxi32 SySetPut(SySet *pSet, const void *pItem);
UNQLITE_PRIVATE sxi32 SySetInit(SySet *pSet, SyMemBackend *pAllocator, sxu32 ElemSize);
UNQLITE_PRIVATE sxi32 SyBlobRelease(SyBlob *pBlob);
UNQLITE_PRIVATE sxi32 SyBlobReset(SyBlob *pBlob);
UNQLITE_PRIVATE sxi32 SyBlobDup(SyBlob *pSrc, SyBlob *pDest);
UNQLITE_PRIVATE sxi32 SyBlobNullAppend(SyBlob *pBlob);
UNQLITE_PRIVATE sxu32 SyBlobFormatAp(SyBlob *pBlob, const char *zFormat, va_list ap);
UNQLITE_PRIVATE sxi32 SyBlobAppend(SyBlob *pBlob, const void *pData, sxu32 nSize);
UNQLITE_PRIVATE sxi32 SyBlobInit(SyBlob *pBlob, SyMemBackend *pAllocator);
UNQLITE_PRIVATE sxi32 SyBlobInitFromBuf(SyBlob *pBlob, void *pBuffer, sxu32 nSize);
UNQLITE_PRIVATE void *SyMemBackendDup(SyMemBackend *pBackend, const void *pSrc, sxu32 nSize);
UNQLITE_PRIVATE sxi32 SyMemBackendRelease(SyMemBackend *pBackend);
UNQLITE_PRIVATE sxi32 SyMemBackendInitFromOthers(SyMemBackend *pBackend, const SyMemMethods *pMethods, ProcMemError xMemErr, void *pUserData);
UNQLITE_PRIVATE sxi32 SyMemBackendInit(SyMemBackend *pBackend, ProcMemError xMemErr, void *pUserData);
UNQLITE_PRIVATE sxi32 SyMemBackendInitFromParent(SyMemBackend *pBackend,const SyMemBackend *pParent);
#if 0
/* Not used in the current release of the JX9 engine */
UNQLITE_PRIVATE void *SyMemBackendPoolRealloc(SyMemBackend *pBackend, void *pOld, sxu32 nByte);
#endif
UNQLITE_PRIVATE sxi32 SyMemBackendPoolFree(SyMemBackend *pBackend, void *pChunk);
UNQLITE_PRIVATE void *SyMemBackendPoolAlloc(SyMemBackend *pBackend, sxu32 nByte);
UNQLITE_PRIVATE sxi32 SyMemBackendFree(SyMemBackend *pBackend, void *pChunk);
UNQLITE_PRIVATE void *SyMemBackendRealloc(SyMemBackend *pBackend, void *pOld, sxu32 nByte);
UNQLITE_PRIVATE void *SyMemBackendAlloc(SyMemBackend *pBackend, sxu32 nByte);
UNQLITE_PRIVATE sxu32 SyMemcpy(const void *pSrc, void *pDest, sxu32 nLen);
UNQLITE_PRIVATE sxi32 SyMemcmp(const void *pB1, const void *pB2, sxu32 nSize);
UNQLITE_PRIVATE sxi32 SyStrnicmp(const char *zLeft, const char *zRight, sxu32 SLen);
UNQLITE_PRIVATE sxu32 Systrcpy(char *zDest, sxu32 nDestLen, const char *zSrc, sxu32 nLen);
#if defined(__APPLE__)
UNQLITE_PRIVATE sxi32 SyStrncmp(const char *zLeft, const char *zRight, sxu32 nLen);
#endif
#if defined(UNQLITE_ENABLE_THREADS)
UNQLITE_PRIVATE const SyMutexMethods *SyMutexExportMethods(void);
UNQLITE_PRIVATE sxi32 SyMemBackendMakeThreadSafe(SyMemBackend *pBackend, const SyMutexMethods *pMethods);
#endif
UNQLITE_PRIVATE void SyBigEndianPack32(unsigned char *buf,sxu32 nb);
UNQLITE_PRIVATE void SyBigEndianUnpack32(const unsigned char *buf,sxu32 *uNB);
UNQLITE_PRIVATE void SyBigEndianPack16(unsigned char *buf,sxu16 nb);
UNQLITE_PRIVATE void SyBigEndianUnpack16(const unsigned char *buf,sxu16 *uNB);
UNQLITE_PRIVATE void SyBigEndianPack64(unsigned char *buf,sxu64 n64);
UNQLITE_PRIVATE void SyBigEndianUnpack64(const unsigned char *buf,sxu64 *n64);
UNQLITE_PRIVATE void SyTimeFormatToDos(Sytm *pFmt,sxu32 *pOut);
UNQLITE_PRIVATE void SyDosTimeFormat(sxu32 nDosDate, Sytm *pOut);
/* forward declaration */
typedef struct unqlite_db unqlite_db;
/*
** The following values may be passed as the second argument to
** UnqliteOsLock(). The various locks exhibit the following semantics:
**
** SHARED:    Any number of processes may hold a SHARED lock simultaneously.
** RESERVED:  A single process may hold a RESERVED lock on a file at
**            any time. Other processes may hold and obtain new SHARED locks.
** PENDING:   A single process may hold a PENDING lock on a file at
**            any one time. Existing SHARED locks may persist, but no new
**            SHARED locks may be obtained by other processes.
** EXCLUSIVE: An EXCLUSIVE lock precludes all other locks.
**
** PENDING_LOCK may not be passed directly to UnqliteOsLock(). Instead, a
** process that requests an EXCLUSIVE lock may actually obtain a PENDING
** lock. This can be upgraded to an EXCLUSIVE lock by a subsequent call to
** UnqliteOsLock().
*/
#define NO_LOCK         0
#define SHARED_LOCK     1
#define RESERVED_LOCK   2
#define PENDING_LOCK    3
#define EXCLUSIVE_LOCK  4
/*
 * UnQLite Locking Strategy (Same as SQLite3)
 *
 * The following #defines specify the range of bytes used for locking.
 * SHARED_SIZE is the number of bytes available in the pool from which
 * a random byte is selected for a shared lock.  The pool of bytes for
 * shared locks begins at SHARED_FIRST. 
 *
 * The same locking strategy and byte ranges are used for Unix and Windows.
 * This leaves open the possiblity of having clients on winNT, and
 * unix all talking to the same shared file and all locking correctly.
 * To do so would require that samba (or whatever
 * tool is being used for file sharing) implements locks correctly between
 * windows and unix.  I'm guessing that isn't likely to happen, but by
 * using the same locking range we are at least open to the possibility.
 *
 * Locking in windows is mandatory.  For this reason, we cannot store
 * actual data in the bytes used for locking.  The pager never allocates
 * the pages involved in locking therefore.  SHARED_SIZE is selected so
 * that all locks will fit on a single page even at the minimum page size.
 * PENDING_BYTE defines the beginning of the locks.  By default PENDING_BYTE
 * is set high so that we don't have to allocate an unused page except
 * for very large databases.  But one should test the page skipping logic 
 * by setting PENDING_BYTE low and running the entire regression suite.
 *
 * Changing the value of PENDING_BYTE results in a subtly incompatible
 * file format.  Depending on how it is changed, you might not notice
 * the incompatibility right away, even running a full regression test.
 * The default location of PENDING_BYTE is the first byte past the
 * 1GB boundary.
 */
#define PENDING_BYTE     (0x40000000)
#define RESERVED_BYTE    (PENDING_BYTE+1)
#define SHARED_FIRST     (PENDING_BYTE+2)
#define SHARED_SIZE      510
/*
 * The default size of a disk sector in bytes.
 */
#ifndef UNQLITE_DEFAULT_SECTOR_SIZE
#define UNQLITE_DEFAULT_SECTOR_SIZE 512
#endif
/*
 * Each open database file is managed by a separate instance
 * of the "Pager" structure.
 */
typedef struct Pager Pager;
/*
 * Each database file to be accessed by the system is an instance
 * of the following structure.
 */
struct unqlite_db
{
	Pager *pPager;              /* Pager and Transaction manager */
	unqlite_kv_cursor *pCursor; /* Database cursor for common usage */
};
/*
 * Each database connection is an instance of the following structure.
 */
struct unqlite
{
	SyMemBackend sMem;              /* Memory allocator subsystem */
	SyBlob sErr;                    /* Error log */
	unqlite_db sDB;                 /* Storage backend */
#if defined(UNQLITE_ENABLE_THREADS)
	const SyMutexMethods *pMethods;  /* Mutex methods */
	SyMutex *pMutex;                 /* Per-handle mutex */
#endif
	sxi32 iFlags;                    /* Control flags (See below)  */
	unqlite *pNext,*pPrev;           /* List of active DB handles */
	sxu32 nMagic;                    /* Sanity check against misuse */
};
#define UNQLITE_FL_DISABLE_AUTO_COMMIT   0x001 /* Disable auto-commit on close */
/* 
 * Database signature to identify a valid database image.
 */
#define UNQLITE_DB_SIG "unqlite"
/*
 * Database magic number (4 bytes).
 */
#define UNQLITE_DB_MAGIC   0xDB7C2712
/*
 * Maximum page size in bytes.
 */
#ifdef UNQLITE_MAX_PAGE_SIZE
# undef UNQLITE_MAX_PAGE_SIZE
#endif
#define UNQLITE_MAX_PAGE_SIZE 65536 /* 65K */
/*
 * Minimum page size in bytes.
 */
#ifdef UNQLITE_MIN_PAGE_SIZE
# undef UNQLITE_MIN_PAGE_SIZE
#endif
#define UNQLITE_MIN_PAGE_SIZE 512
/*
 * The default size of a database page.
 */
#ifndef UNQLITE_DEFAULT_PAGE_SIZE
# undef UNQLITE_DEFAULT_PAGE_SIZE
#endif
# define UNQLITE_DEFAULT_PAGE_SIZE 4096 /* 4K */
/* Forward declaration */
typedef struct Bitvec Bitvec;
/* Private library functions */
/* api.c */
UNQLITE_PRIVATE const SyMemBackend * unqliteExportMemBackend(void);
UNQLITE_PRIVATE int unqliteDataConsumer(
	const void *pOut,   /* Data to consume */
	unsigned int nLen,  /* Data length */
	void *pUserData     /* User private data */
	);
UNQLITE_PRIVATE unqlite_kv_methods * unqliteFindKVStore(
	const char *zName, /* Storage engine name [i.e. Hash, B+tree, LSM, etc.] */
	sxu32 nByte        /* zName length */
	);
UNQLITE_PRIVATE int unqliteGetPageSize(void);
UNQLITE_PRIVATE int unqliteGenError(unqlite *pDb,const char *zErr);
UNQLITE_PRIVATE int unqliteGenErrorFormat(unqlite *pDb,const char *zFmt,...);
UNQLITE_PRIVATE int unqliteGenOutofMem(unqlite *pDb);
/* vfs.c [io_win.c, io_unix.c ] */
UNQLITE_PRIVATE const unqlite_vfs * unqliteExportBuiltinVfs(void);
/* mem_kv.c */
UNQLITE_PRIVATE const unqlite_kv_methods * unqliteExportMemKvStorage(void);
/* lhash_kv.c */
UNQLITE_PRIVATE const unqlite_kv_methods * unqliteExportDiskKvStorage(void);
/* os.c */
UNQLITE_PRIVATE int unqliteOsRead(unqlite_file *id, void *pBuf, unqlite_int64 amt, unqlite_int64 offset);
UNQLITE_PRIVATE int unqliteOsWrite(unqlite_file *id, const void *pBuf, unqlite_int64 amt, unqlite_int64 offset);
UNQLITE_PRIVATE int unqliteOsTruncate(unqlite_file *id, unqlite_int64 size);
UNQLITE_PRIVATE int unqliteOsSync(unqlite_file *id, int flags);
UNQLITE_PRIVATE int unqliteOsFileSize(unqlite_file *id, unqlite_int64 *pSize);
UNQLITE_PRIVATE int unqliteOsLock(unqlite_file *id, int lockType);
UNQLITE_PRIVATE int unqliteOsUnlock(unqlite_file *id, int lockType);
UNQLITE_PRIVATE int unqliteOsCheckReservedLock(unqlite_file *id, int *pResOut);
UNQLITE_PRIVATE int unqliteOsSectorSize(unqlite_file *id);
UNQLITE_PRIVATE int unqliteOsOpen(
  unqlite_vfs *pVfs,
  SyMemBackend *pAlloc,
  const char *zPath, 
  unqlite_file **ppOut, 
  unsigned int flags
);
UNQLITE_PRIVATE int unqliteOsCloseFree(SyMemBackend *pAlloc,unqlite_file *pId);
UNQLITE_PRIVATE int unqliteOsDelete(unqlite_vfs *pVfs, const char *zPath, int dirSync);
UNQLITE_PRIVATE int unqliteOsAccess(unqlite_vfs *pVfs,const char *zPath,int flags,int *pResOut);
/* bitmap.c */
UNQLITE_PRIVATE Bitvec *unqliteBitvecCreate(SyMemBackend *pAlloc,pgno iSize);
UNQLITE_PRIVATE int unqliteBitvecTest(Bitvec *p,pgno i);
UNQLITE_PRIVATE int unqliteBitvecSet(Bitvec *p,pgno i);
UNQLITE_PRIVATE void unqliteBitvecDestroy(Bitvec *p);
/* pager.c */
UNQLITE_PRIVATE int unqliteInitCursor(unqlite *pDb,unqlite_kv_cursor **ppOut);
UNQLITE_PRIVATE int unqliteReleaseCursor(unqlite *pDb,unqlite_kv_cursor *pCur);
UNQLITE_PRIVATE int unqlitePagerSetCachesize(Pager *pPager,int mxPage);
UNQLITE_PRIVATE int unqlitePagerClose(Pager *pPager);
UNQLITE_PRIVATE int unqlitePagerOpen(
  unqlite_vfs *pVfs,       /* The virtual file system to use */
  unqlite *pDb,            /* Database handle */
  const char *zFilename,   /* Name of the database file to open */
  unsigned int iFlags      /* flags controlling this file */
  );
UNQLITE_PRIVATE int unqlitePagerRegisterKvEngine(Pager *pPager,unqlite_kv_methods *pMethods);
UNQLITE_PRIVATE unqlite_kv_engine * unqlitePagerGetKvEngine(unqlite *pDb);
UNQLITE_PRIVATE int unqlitePagerBegin(Pager *pPager);
UNQLITE_PRIVATE int unqlitePagerCommit(Pager *pPager);
UNQLITE_PRIVATE int unqlitePagerRollback(Pager *pPager,int bResetKvEngine);
UNQLITE_PRIVATE void unqlitePagerRandomString(Pager *pPager,char *zBuf,sxu32 nLen);
UNQLITE_PRIVATE sxu32 unqlitePagerRandomNum(Pager *pPager);
#endif /* __UNQLITEINT_H__ */
/*
 * ----------------------------------------------------------
 * File: api.c
 * ID: d79e8404e50dacd0ea75635c1ebe553a
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: api.c v2.0 FreeBSD 2012-11-08 23:07 stable <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* This file implement the public interfaces presented to host-applications.
 * Routines in other files are for internal use by UnQLite and should not be
 * accessed by users of the library.
 */
#define UNQLITE_DB_MISUSE(DB) (DB == 0 || DB->nMagic != UNQLITE_DB_MAGIC)
#define UNQLITE_VM_MISUSE(VM) (VM == 0 || VM->nMagic == JX9_VM_STALE)
/* If another thread have released a working instance, the following macros
 * evaluates to true. These macros are only used when the library
 * is built with threading support enabled.
 */
#define UNQLITE_THRD_DB_RELEASE(DB) (DB->nMagic != UNQLITE_DB_MAGIC)
#define UNQLITE_THRD_VM_RELEASE(VM) (VM->nMagic == JX9_VM_STALE)
/* IMPLEMENTATION: unqlite@embedded@symisc 118-09-4785 */
/*
 * All global variables are collected in the structure named "sUnqlMPGlobal".
 * That way it is clear in the code when we are using static variable because
 * its name start with sUnqlMPGlobal.
 */
static struct unqlGlobal_Data
{
	SyMemBackend sAllocator;                /* Global low level memory allocator */
#if defined(UNQLITE_ENABLE_THREADS)
	const SyMutexMethods *pMutexMethods;   /* Mutex methods */
	SyMutex *pMutex;                       /* Global mutex */
	sxu32 nThreadingLevel;                 /* Threading level: 0 == Single threaded/1 == Multi-Threaded 
										    * The threading level can be set using the [unqlite_lib_config()]
											* interface with a configuration verb set to
											* UNQLITE_LIB_CONFIG_THREAD_LEVEL_SINGLE or 
											* UNQLITE_LIB_CONFIG_THREAD_LEVEL_MULTI
											*/
#endif
	SySet kv_storage;                      /* Installed KV storage engines */
	int iPageSize;                         /* Default Page size */
	unqlite_vfs *pVfs;                     /* Underlying virtual file system (Vfs) */
	sxi32 nDB;                             /* Total number of active DB handles */
	unqlite *pDB;                          /* List of active DB handles */
	sxu32 nMagic;                          /* Sanity check against library misuse */
}sUnqlMPGlobal = {
	{0, 0, 0, 0, 0, 0, 0, 0, {0}}, 
#if defined(UNQLITE_ENABLE_THREADS)
	0, 
	0, 
	0, 
#endif
	{0, 0, 0, 0, 0, 0, 0 },
	UNQLITE_DEFAULT_PAGE_SIZE,
	0, 
	0, 
	0, 
	0
};
#define UNQLITE_LIB_MAGIC  0xEA1495BA
#define UNQLITE_LIB_MISUSE (sUnqlMPGlobal.nMagic != UNQLITE_LIB_MAGIC)
/*
 * Supported threading level.
 * These options have meaning only when the library is compiled with multi-threading
 * support. That is, the UNQLITE_ENABLE_THREADS compile time directive must be defined
 * when UnQLite is built.
 * UNQLITE_THREAD_LEVEL_SINGLE:
 *  In this mode, mutexing is disabled and the library can only be used by a single thread.
 * UNQLITE_THREAD_LEVEL_MULTI
 *  In this mode, all mutexes including the recursive mutexes on [unqlite] objects
 *  are enabled so that the application is free to share the same database handle
 *  between different threads at the same time.
 */
#define UNQLITE_THREAD_LEVEL_SINGLE 1 
#define UNQLITE_THREAD_LEVEL_MULTI  2
/*
 * Find a Key Value storage engine from the set of installed engines.
 * Return a pointer to the storage engine methods on success. NULL on failure.
 */
UNQLITE_PRIVATE unqlite_kv_methods * unqliteFindKVStore(
	const char *zName, /* Storage engine name [i.e. Hash, B+tree, LSM, etc.] */
	sxu32 nByte /* zName length */
	)
{
	unqlite_kv_methods **apStore,*pEntry;
	sxu32 n,nMax;
	/* Point to the set of installed engines */
	apStore = (unqlite_kv_methods **)SySetBasePtr(&sUnqlMPGlobal.kv_storage);
	nMax = SySetUsed(&sUnqlMPGlobal.kv_storage);
	for( n = 0 ; n < nMax; ++n ){
		pEntry = apStore[n];
		if( nByte == SyStrlen(pEntry->zName) && SyStrnicmp(pEntry->zName,zName,nByte) == 0 ){
			/* Storage engine found */
			return pEntry;
		}
	}
	/* No such entry, return NULL */
	return 0;
}
/*
 * Configure the UnQLite library.
 * Return UNQLITE_OK on success. Any other return value indicates failure.
 * Refer to [unqlite_lib_config()].
 */
static sxi32 unqliteCoreConfigure(sxi32 nOp, va_list ap)
{
	int rc = UNQLITE_OK;
	switch(nOp){
	    case UNQLITE_LIB_CONFIG_PAGE_SIZE: {
			/* Default page size: Must be a power of two */
			int iPage = va_arg(ap,int);
			if( iPage >= UNQLITE_MIN_PAGE_SIZE && iPage <= UNQLITE_MAX_PAGE_SIZE ){
				if( !(iPage & (iPage - 1)) ){
					sUnqlMPGlobal.iPageSize = iPage;
				}else{
					/* Invalid page size */
					rc = UNQLITE_INVALID;
				}
			}else{
				/* Invalid page size */
				rc = UNQLITE_INVALID;
			}
			break;
										   }
	    case UNQLITE_LIB_CONFIG_STORAGE_ENGINE: {
			/* Install a key value storage engine */
			unqlite_kv_methods *pMethods = va_arg(ap,unqlite_kv_methods *);
			/* Make sure we are delaing with a valid methods */
			if( pMethods == 0 || SX_EMPTY_STR(pMethods->zName) || pMethods->xSeek == 0 || pMethods->xData == 0
				|| pMethods->xKey == 0 || pMethods->xDataLength == 0 || pMethods->xKeyLength == 0 
				|| pMethods->szKv < (int)sizeof(unqlite_kv_engine) ){
					rc = UNQLITE_INVALID;
					break;
			}
			/* Install it */
			rc = SySetPut(&sUnqlMPGlobal.kv_storage,(const void *)&pMethods);
			break;
												}
	    case UNQLITE_LIB_CONFIG_VFS:{
			/* Install a virtual file system */
			unqlite_vfs *pVfs = va_arg(ap,unqlite_vfs *);
			if( pVfs ){
			 sUnqlMPGlobal.pVfs = pVfs;
			}
			break;
								}
		case UNQLITE_LIB_CONFIG_USER_MALLOC: {
			/* Use an alternative low-level memory allocation routines */
			const SyMemMethods *pMethods = va_arg(ap, const SyMemMethods *);
			/* Save the memory failure callback (if available) */
			ProcMemError xMemErr = sUnqlMPGlobal.sAllocator.xMemError;
			void *pMemErr = sUnqlMPGlobal.sAllocator.pUserData;
			if( pMethods == 0 ){
				/* Use the built-in memory allocation subsystem */
				rc = SyMemBackendInit(&sUnqlMPGlobal.sAllocator, xMemErr, pMemErr);
			}else{
				rc = SyMemBackendInitFromOthers(&sUnqlMPGlobal.sAllocator, pMethods, xMemErr, pMemErr);
			}
			break;
										  }
		case UNQLITE_LIB_CONFIG_MEM_ERR_CALLBACK: {
			/* Memory failure callback */
			ProcMemError xMemErr = va_arg(ap, ProcMemError);
			void *pUserData = va_arg(ap, void *);
			sUnqlMPGlobal.sAllocator.xMemError = xMemErr;
			sUnqlMPGlobal.sAllocator.pUserData = pUserData;
			break;
												 }	  
		case UNQLITE_LIB_CONFIG_USER_MUTEX: {
#if defined(UNQLITE_ENABLE_THREADS)
			/* Use an alternative low-level mutex subsystem */
			const SyMutexMethods *pMethods = va_arg(ap, const SyMutexMethods *);
#if defined (UNTRUST)
			if( pMethods == 0 ){
				rc = UNQLITE_CORRUPT;
			}
#endif
			/* Sanity check */
			if( pMethods->xEnter == 0 || pMethods->xLeave == 0 || pMethods->xNew == 0){
				/* At least three criticial callbacks xEnter(), xLeave() and xNew() must be supplied */
				rc = UNQLITE_CORRUPT;
				break;
			}
			if( sUnqlMPGlobal.pMutexMethods ){
				/* Overwrite the previous mutex subsystem */
				SyMutexRelease(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex);
				if( sUnqlMPGlobal.pMutexMethods->xGlobalRelease ){
					sUnqlMPGlobal.pMutexMethods->xGlobalRelease();
				}
				sUnqlMPGlobal.pMutex = 0;
			}
			/* Initialize and install the new mutex subsystem */
			if( pMethods->xGlobalInit ){
				rc = pMethods->xGlobalInit();
				if ( rc != UNQLITE_OK ){
					break;
				}
			}
			/* Create the global mutex */
			sUnqlMPGlobal.pMutex = pMethods->xNew(SXMUTEX_TYPE_FAST);
			if( sUnqlMPGlobal.pMutex == 0 ){
				/*
				 * If the supplied mutex subsystem is so sick that we are unable to
				 * create a single mutex, there is no much we can do here.
				 */
				if( pMethods->xGlobalRelease ){
					pMethods->xGlobalRelease();
				}
				rc = UNQLITE_CORRUPT;
				break;
			}
			sUnqlMPGlobal.pMutexMethods = pMethods;			
			if( sUnqlMPGlobal.nThreadingLevel == 0 ){
				/* Set a default threading level */
				sUnqlMPGlobal.nThreadingLevel = UNQLITE_THREAD_LEVEL_MULTI; 
			}
#endif
			break;
										   }
		case UNQLITE_LIB_CONFIG_THREAD_LEVEL_SINGLE:
#if defined(UNQLITE_ENABLE_THREADS)
			/* Single thread mode (Only one thread is allowed to play with the library) */
			sUnqlMPGlobal.nThreadingLevel = UNQLITE_THREAD_LEVEL_SINGLE;
#endif
			break;
		case UNQLITE_LIB_CONFIG_THREAD_LEVEL_MULTI:
#if defined(UNQLITE_ENABLE_THREADS)
			/* Multi-threading mode (library is thread safe and database handles and virtual machines
			 * may be shared between multiple threads).
			 */
			sUnqlMPGlobal.nThreadingLevel = UNQLITE_THREAD_LEVEL_MULTI;
#endif
			break;
		default:
			/* Unknown configuration option */
			rc = UNQLITE_CORRUPT;
			break;
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_lib_config()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_lib_config(int nConfigOp,...)
{
	va_list ap;
	int rc;
	if( sUnqlMPGlobal.nMagic == UNQLITE_LIB_MAGIC ){
		/* Library is already initialized, this operation is forbidden */
		return UNQLITE_LOCKED;
	}
	va_start(ap,nConfigOp);
	rc = unqliteCoreConfigure(nConfigOp,ap);
	va_end(ap);
	return rc;
}
/*
 * Global library initialization
 * Refer to [unqlite_lib_init()]
 * This routine must be called to initialize the memory allocation subsystem, the mutex 
 * subsystem prior to doing any serious work with the library. The first thread to call
 * this routine does the initialization process and set the magic number so no body later
 * can re-initialize the library. If subsequent threads call this  routine before the first
 * thread have finished the initialization process, then the subsequent threads must block 
 * until the initialization process is done.
 */
static sxi32 unqliteCoreInitialize(void)
{
	const unqlite_kv_methods *pMethods;
	const unqlite_vfs *pVfs; /* Built-in vfs */
#if defined(UNQLITE_ENABLE_THREADS)
	const SyMutexMethods *pMutexMethods = 0;
	SyMutex *pMaster = 0;
#endif
	int rc;
	/*
	 * If the library is already initialized, then a call to this routine
	 * is a no-op.
	 */
	if( sUnqlMPGlobal.nMagic == UNQLITE_LIB_MAGIC ){
		return UNQLITE_OK; /* Already initialized */
	}
	if( sUnqlMPGlobal.pVfs == 0 ){
		/* Point to the built-in vfs */
		pVfs = unqliteExportBuiltinVfs();
		/* Install it */
		unqlite_lib_config(UNQLITE_LIB_CONFIG_VFS, pVfs);
	}
#if defined(UNQLITE_ENABLE_THREADS)
	if( sUnqlMPGlobal.nThreadingLevel >= UNQLITE_THREAD_LEVEL_SINGLE ){
		pMutexMethods = sUnqlMPGlobal.pMutexMethods;
		if( pMutexMethods == 0 ){
			/* Use the built-in mutex subsystem */
			pMutexMethods = SyMutexExportMethods();
			if( pMutexMethods == 0 ){
				return UNQLITE_CORRUPT; /* Can't happen */
			}
			/* Install the mutex subsystem */
			rc = unqlite_lib_config(UNQLITE_LIB_CONFIG_USER_MUTEX, pMutexMethods);
			if( rc != UNQLITE_OK ){
				return rc;
			}
		}
		/* Obtain a static mutex so we can initialize the library without calling malloc() */
		pMaster = SyMutexNew(pMutexMethods, SXMUTEX_TYPE_STATIC_1);
		if( pMaster == 0 ){
			return UNQLITE_CORRUPT; /* Can't happen */
		}
	}
	/* Lock the master mutex */
	rc = UNQLITE_OK;
	SyMutexEnter(pMutexMethods, pMaster); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
	if( sUnqlMPGlobal.nMagic != UNQLITE_LIB_MAGIC ){
#endif
		if( sUnqlMPGlobal.sAllocator.pMethods == 0 ){
			/* Install a memory subsystem */
			rc = unqlite_lib_config(UNQLITE_LIB_CONFIG_USER_MALLOC, 0); /* zero mean use the built-in memory backend */
			if( rc != UNQLITE_OK ){
				/* If we are unable to initialize the memory backend, there is no much we can do here.*/
				goto End;
			}
		}
#if defined(UNQLITE_ENABLE_THREADS)
		if( sUnqlMPGlobal.nThreadingLevel >= UNQLITE_THREAD_LEVEL_SINGLE ){
			/* Protect the memory allocation subsystem */
			rc = SyMemBackendMakeThreadSafe(&sUnqlMPGlobal.sAllocator, sUnqlMPGlobal.pMutexMethods);
			if( rc != UNQLITE_OK ){
				goto End;
			}
		}
#endif
		SySetInit(&sUnqlMPGlobal.kv_storage,&sUnqlMPGlobal.sAllocator,sizeof(unqlite_kv_methods *));
		/* Install the built-in Key Value storage engines */
		pMethods = unqliteExportMemKvStorage(); /* In-memory storage */
		unqlite_lib_config(UNQLITE_LIB_CONFIG_STORAGE_ENGINE,pMethods);
		/* Default disk key/value storage engine */
		pMethods = unqliteExportDiskKvStorage(); /* Disk storage */
		unqlite_lib_config(UNQLITE_LIB_CONFIG_STORAGE_ENGINE,pMethods);
		/* Default page size */
		if( sUnqlMPGlobal.iPageSize < UNQLITE_MIN_PAGE_SIZE ){
			unqlite_lib_config(UNQLITE_LIB_CONFIG_PAGE_SIZE,UNQLITE_DEFAULT_PAGE_SIZE);
		}
		/* Our library is initialized, set the magic number */
		sUnqlMPGlobal.nMagic = UNQLITE_LIB_MAGIC;
		rc = UNQLITE_OK;
#if defined(UNQLITE_ENABLE_THREADS)
	} /* sUnqlMPGlobal.nMagic != UNQLITE_LIB_MAGIC */
#endif
End:
#if defined(UNQLITE_ENABLE_THREADS)
	/* Unlock the master mutex */
	SyMutexLeave(pMutexMethods, pMaster); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
#endif
	return rc;
}
/*
 * Release a single instance of an unqlite database handle.
 */
static int unqliteDbRelease(unqlite *pDb)
{
	unqlite_db *pStore = &pDb->sDB;
	int rc = UNQLITE_OK;
	if( (pDb->iFlags & UNQLITE_FL_DISABLE_AUTO_COMMIT) == 0 ){
		/* Commit any outstanding transaction */
		rc = unqlitePagerCommit(pStore->pPager);
		if( rc != UNQLITE_OK ){
			/* Rollback the transaction */
			rc = unqlitePagerRollback(pStore->pPager,FALSE);
		}
	}else{
		/* Rollback any outstanding transaction */
		rc = unqlitePagerRollback(pStore->pPager,FALSE);
	}
	/* Close the pager */
	unqlitePagerClose(pStore->pPager);
	/* Set a dummy magic number */
	pDb->nMagic = 0x7250;
	/* Release the whole memory subsystem */
	SyMemBackendRelease(&pDb->sMem);
	/* Commit or rollback result */
	return rc;
}
/*
 * Release all resources consumed by the library.
 * Note: This call is not thread safe. Refer to [unqlite_lib_shutdown()].
 */
static void unqliteCoreShutdown(void)
{
	unqlite *pDb, *pNext;
	/* Release all active databases handles */
	pDb = sUnqlMPGlobal.pDB;
	for(;;){
		if( sUnqlMPGlobal.nDB < 1 ){
			break;
		}
		pNext = pDb->pNext;
		unqliteDbRelease(pDb); 
		pDb = pNext;
		sUnqlMPGlobal.nDB--;
	}
	/* Release the storage methods container */
	SySetRelease(&sUnqlMPGlobal.kv_storage);
#if defined(UNQLITE_ENABLE_THREADS)
	/* Release the mutex subsystem */
	if( sUnqlMPGlobal.pMutexMethods ){
		if( sUnqlMPGlobal.pMutex ){
			SyMutexRelease(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex);
			sUnqlMPGlobal.pMutex = 0;
		}
		if( sUnqlMPGlobal.pMutexMethods->xGlobalRelease ){
			sUnqlMPGlobal.pMutexMethods->xGlobalRelease();
		}
		sUnqlMPGlobal.pMutexMethods = 0;
	}
	sUnqlMPGlobal.nThreadingLevel = 0;
#endif
	if( sUnqlMPGlobal.sAllocator.pMethods ){
		/* Release the memory backend */
		SyMemBackendRelease(&sUnqlMPGlobal.sAllocator);
	}
	sUnqlMPGlobal.nMagic = 0x1764;

}
/*
 * [CAPIREF: unqlite_lib_init()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_lib_init(void)
{
	int rc;
	rc = unqliteCoreInitialize();
	return rc;
}
/*
 * [CAPIREF: unqlite_lib_shutdown()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_lib_shutdown(void)
{
	if( sUnqlMPGlobal.nMagic != UNQLITE_LIB_MAGIC ){
		/* Already shut */
		return UNQLITE_OK;
	}
	unqliteCoreShutdown();
	return UNQLITE_OK;
}
/*
 * [CAPIREF: unqlite_lib_is_threadsafe()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_lib_is_threadsafe(void)
{
	if( sUnqlMPGlobal.nMagic != UNQLITE_LIB_MAGIC ){
		return 0;
	}
#if defined(UNQLITE_ENABLE_THREADS)
		if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE ){
			/* Muli-threading support is enabled */
			return 1;
		}else{
			/* Single-threading */
			return 0;
		}
#else
	return 0;
#endif
}
/*
 *
 * [CAPIREF: unqlite_lib_version()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
const char * unqlite_lib_version(void)
{
	return UNQLITE_VERSION;
}
/*
 *
 * [CAPIREF: unqlite_lib_signature()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
const char * unqlite_lib_signature(void)
{
	return UNQLITE_SIG;
}
/*
 *
 * [CAPIREF: unqlite_lib_ident()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
const char * unqlite_lib_ident(void)
{
	return UNQLITE_IDENT;
}
/*
 *
 * [CAPIREF: unqlite_lib_copyright()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
const char * unqlite_lib_copyright(void)
{
	return UNQLITE_COPYRIGHT;
}
/*
 * Remove harmfull and/or stale flags passed to the [unqlite_open()] interface.
 */
static unsigned int unqliteSanityzeFlag(unsigned int iFlags)
{
	iFlags &= ~UNQLITE_OPEN_EXCLUSIVE; /* Reserved flag */
	if( iFlags & UNQLITE_OPEN_TEMP_DB ){
		/* Omit journaling for temporary database */
		iFlags |= UNQLITE_OPEN_OMIT_JOURNALING|UNQLITE_OPEN_CREATE;
	}
	if( (iFlags & (UNQLITE_OPEN_READONLY|UNQLITE_OPEN_READWRITE)) == 0 ){
		/* Auto-append the R+W flag */
		iFlags |= UNQLITE_OPEN_READWRITE;
	}
	if( iFlags & UNQLITE_OPEN_CREATE ){
		iFlags &= ~(UNQLITE_OPEN_MMAP|UNQLITE_OPEN_READONLY);
		/* Auto-append the R+W flag */
		iFlags |= UNQLITE_OPEN_READWRITE;
	}else{
		if( iFlags & UNQLITE_OPEN_READONLY ){
			iFlags &= ~UNQLITE_OPEN_READWRITE;
		}else if( iFlags & UNQLITE_OPEN_READWRITE ){
			iFlags &= ~UNQLITE_OPEN_MMAP;
		}
	}
	return iFlags;
}
/*
 * This routine does the work of initializing a database handle on behalf
 * of [unqlite_open()].
 */
static int unqliteInitDatabase(
	unqlite *pDB,            /* Database handle */
	SyMemBackend *pParent,   /* Master memory backend */
	const char *zFilename,   /* Target database */
	unsigned int iFlags      /* Open flags */
	)
{
	int rc;
	/* Initialize the memory subsystem */
	SyMemBackendInitFromParent(&pDB->sMem,pParent);
	SyBlobInit(&pDB->sErr,&pDB->sMem);
	/* Sanitize flags */
	iFlags = unqliteSanityzeFlag(iFlags);
	/* Init the pager and the transaction manager */
	rc = unqlitePagerOpen(sUnqlMPGlobal.pVfs,pDB,zFilename,iFlags);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	return UNQLITE_OK;
}
/*
 * Return the default page size.
 */
UNQLITE_PRIVATE int unqliteGetPageSize(void)
{
	int iSize =  sUnqlMPGlobal.iPageSize;
	if( iSize < UNQLITE_MIN_PAGE_SIZE || iSize > UNQLITE_MAX_PAGE_SIZE ){
		iSize = UNQLITE_DEFAULT_PAGE_SIZE;
	}
	return iSize;
}
/*
 * Generate an error message.
 */
UNQLITE_PRIVATE int unqliteGenError(unqlite *pDb,const char *zErr)
{
	int rc;
	/* Append the error message */
	rc = SyBlobAppend(&pDb->sErr,(const void *)zErr,SyStrlen(zErr));
	/* Append a new line */
	SyBlobAppend(&pDb->sErr,(const void *)"\n",sizeof(char));
	return rc;
}
/*
 * Generate an error message (Printf like).
 */
UNQLITE_PRIVATE int unqliteGenErrorFormat(unqlite *pDb,const char *zFmt,...)
{
	va_list ap;
	int rc;
	va_start(ap,zFmt);
	rc = SyBlobFormatAp(&pDb->sErr,zFmt,ap);
	va_end(ap);
	/* Append a new line */
	SyBlobAppend(&pDb->sErr,(const void *)"\n",sizeof(char));
	return rc;
}
/*
 * Generate an error message (Out of memory).
 */
UNQLITE_PRIVATE int unqliteGenOutofMem(unqlite *pDb)
{
	int rc;
	rc = unqliteGenError(pDb,"unQLite is running out of memory");
	return rc;
}
/*
 * Configure a working UnQLite database handle.
 */
static int unqliteConfigure(unqlite *pDb,int nOp,va_list ap)
{
	int rc = UNQLITE_OK;
	switch(nOp){
	case UNQLITE_CONFIG_MAX_PAGE_CACHE: {
		int max_page = va_arg(ap,int);
		/* Maximum number of page to cache (Simple hint). */
		rc = unqlitePagerSetCachesize(pDb->sDB.pPager,max_page);
		break;
										}
	case UNQLITE_CONFIG_ERR_LOG: {
		/* Database error log if any */
		const char **pzPtr = va_arg(ap, const char **);
		int *pLen = va_arg(ap, int *);
		if( pzPtr == 0 ){
			rc = UNQLITE_CORRUPT;
			break;
		}
		/* NULL terminate the error-log buffer */
		SyBlobNullAppend(&pDb->sErr);
		/* Point to the error-log buffer */
		*pzPtr = (const char *)SyBlobData(&pDb->sErr);
		if( pLen ){
			if( SyBlobLength(&pDb->sErr) > 1 /* NULL '\0' terminator */ ){
				*pLen = (int)SyBlobLength(&pDb->sErr);
			}else{
				*pLen = 0;
			}
		}
		break;
								 }
	case UNQLITE_CONFIG_DISABLE_AUTO_COMMIT:{
		/* Disable auto-commit */
		pDb->iFlags |= UNQLITE_FL_DISABLE_AUTO_COMMIT;
		break;
											}
	case UNQLITE_CONFIG_GET_KV_NAME: {
		/* Name of the underlying KV storage engine */
		const char **pzPtr = va_arg(ap,const char **);
		if( pzPtr ){
			unqlite_kv_engine *pEngine;
			pEngine = unqlitePagerGetKvEngine(pDb);
			/* Point to the name */
			*pzPtr = pEngine->pIo->pMethods->zName;
		}
		break;
									 }
	default:
		/* Unknown configuration option */
		rc = UNQLITE_UNKNOWN;
		break;
	}
	return rc;
}
/*
 * Export the global (master) memory allocator to submodules.
 */
UNQLITE_PRIVATE const SyMemBackend * unqliteExportMemBackend(void)
{
	return &sUnqlMPGlobal.sAllocator;
}
/*
 * [CAPIREF: unqlite_open()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_open(unqlite **ppDB,const char *zFilename,unsigned int iMode)
{
	unqlite *pHandle;
	int rc;
#if defined(UNTRUST)
	if( ppDB == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	*ppDB = 0;
	/* One-time automatic library initialization */
	rc = unqliteCoreInitialize();
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Allocate a new database handle */
	pHandle = (unqlite *)SyMemBackendPoolAlloc(&sUnqlMPGlobal.sAllocator, sizeof(unqlite));
	if( pHandle == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pHandle,sizeof(unqlite));
	if( iMode < 1 ){
		/* Assume a read-only database */
		iMode = UNQLITE_OPEN_READONLY|UNQLITE_OPEN_MMAP;
	}
	/* Init the database */
	rc = unqliteInitDatabase(pHandle,&sUnqlMPGlobal.sAllocator,zFilename,iMode);
	if( rc != UNQLITE_OK ){
		goto Release;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	if( !(iMode & UNQLITE_OPEN_NOMUTEX) && (sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE) ){
		 /* Associate a recursive mutex with this instance */
		 pHandle->pMutex = SyMutexNew(sUnqlMPGlobal.pMutexMethods, SXMUTEX_TYPE_RECURSIVE);
		 if( pHandle->pMutex == 0 ){
			 rc = UNQLITE_NOMEM;
			 goto Release;
		 }
	 }
#endif
	/* Link to the list of active DB handles */
#if defined(UNQLITE_ENABLE_THREADS)
	/* Enter the global mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
#endif
	 MACRO_LD_PUSH(sUnqlMPGlobal.pDB,pHandle);
	 sUnqlMPGlobal.nDB++;
#if defined(UNQLITE_ENABLE_THREADS)
	/* Leave the global mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
#endif
	/* Set the magic number to identify a valid DB handle */
	 pHandle->nMagic = UNQLITE_DB_MAGIC;
	/* Make the handle available to the caller */
	*ppDB = pHandle;
	return UNQLITE_OK;
Release:
	SyMemBackendRelease(&pHandle->sMem);
	SyMemBackendPoolFree(&sUnqlMPGlobal.sAllocator,pHandle);
	return rc;
}
/*
 * [CAPIREF: unqlite_config()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_config(unqlite *pDb,int nConfigOp,...)
{
	va_list ap;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 va_start(ap, nConfigOp);
	 rc = unqliteConfigure(&(*pDb),nConfigOp, ap);
	 va_end(ap);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_close()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_close(unqlite *pDb)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	/* Release the database handle */
	rc = unqliteDbRelease(pDb);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 /* Release DB mutex */
	 SyMutexRelease(sUnqlMPGlobal.pMutexMethods, pDb->pMutex) /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
#if defined(UNQLITE_ENABLE_THREADS)
	/* Enter the global mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
#endif
	/* Unlink from the list of active database handles */
	 MACRO_LD_REMOVE(sUnqlMPGlobal.pDB, pDb);
	sUnqlMPGlobal.nDB--;
#if defined(UNQLITE_ENABLE_THREADS)
	/* Leave the global mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods, sUnqlMPGlobal.pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel == UNQLITE_THREAD_LEVEL_SINGLE */
#endif
	/* Release the memory chunk allocated to this handle */
	SyMemBackendPoolFree(&sUnqlMPGlobal.sAllocator,pDb);
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_store()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_store(unqlite *pDb,const void *pKey,int nKeyLen,const void *pData,unqlite_int64 nDataLen)
{
	unqlite_kv_engine *pEngine;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 if( pEngine->pIo->pMethods->xReplace == 0 ){
		 /* Storage engine does not implement such method */
		 unqliteGenError(pDb,"xReplace() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 if( nKeyLen < 0 ){
			 /* Assume a null terminated string and compute it's length */
			 nKeyLen = SyStrlen((const char *)pKey);
		 }
		 if( !nKeyLen ){
			 unqliteGenError(pDb,"Empty key");
			 rc = UNQLITE_EMPTY;
		 }else{
			 /* Perform the requested operation */
			 rc = pEngine->pIo->pMethods->xReplace(pEngine,pKey,nKeyLen,pData,nDataLen);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_store_fmt()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_store_fmt(unqlite *pDb,const void *pKey,int nKeyLen,const char *zFormat,...)
{
	unqlite_kv_engine *pEngine;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 if( pEngine->pIo->pMethods->xReplace == 0 ){
		 /* Storage engine does not implement such method */
		 unqliteGenError(pDb,"xReplace() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 if( nKeyLen < 0 ){
			 /* Assume a null terminated string and compute it's length */
			 nKeyLen = SyStrlen((const char *)pKey);
		 }
		 if( !nKeyLen ){
			 unqliteGenError(pDb,"Empty key");
			 rc = UNQLITE_EMPTY;
		 }else{
			 SyBlob sWorker; /* Working buffer */
			 va_list ap;
			 SyBlobInit(&sWorker,&pDb->sMem);
			 /* Format the data */
			 va_start(ap,zFormat);
			 SyBlobFormatAp(&sWorker,zFormat,ap);
			 va_end(ap);
			 /* Perform the requested operation */
			 rc = pEngine->pIo->pMethods->xReplace(pEngine,pKey,nKeyLen,SyBlobData(&sWorker),SyBlobLength(&sWorker));
			 /* Clean up */
			 SyBlobRelease(&sWorker);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_append()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_append(unqlite *pDb,const void *pKey,int nKeyLen,const void *pData,unqlite_int64 nDataLen)
{
	unqlite_kv_engine *pEngine;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 if( pEngine->pIo->pMethods->xAppend == 0 ){
		 /* Storage engine does not implement such method */
		 unqliteGenError(pDb,"xAppend() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 if( nKeyLen < 0 ){
			 /* Assume a null terminated string and compute it's length */
			 nKeyLen = SyStrlen((const char *)pKey);
		 }
		 if( !nKeyLen ){
			 unqliteGenError(pDb,"Empty key");
			 rc = UNQLITE_EMPTY;
		 }else{
			 /* Perform the requested operation */
			 rc = pEngine->pIo->pMethods->xAppend(pEngine,pKey,nKeyLen,pData,nDataLen);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_append_fmt()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_append_fmt(unqlite *pDb,const void *pKey,int nKeyLen,const char *zFormat,...)
{
	unqlite_kv_engine *pEngine;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 if( pEngine->pIo->pMethods->xAppend == 0 ){
		 /* Storage engine does not implement such method */
		 unqliteGenError(pDb,"xAppend() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 if( nKeyLen < 0 ){
			 /* Assume a null terminated string and compute it's length */
			 nKeyLen = SyStrlen((const char *)pKey);
		 }
		 if( !nKeyLen ){
			 unqliteGenError(pDb,"Empty key");
			 rc = UNQLITE_EMPTY;
		 }else{
			 SyBlob sWorker; /* Working buffer */
			 va_list ap;
			 SyBlobInit(&sWorker,&pDb->sMem);
			 /* Format the data */
			 va_start(ap,zFormat);
			 SyBlobFormatAp(&sWorker,zFormat,ap);
			 va_end(ap);
			 /* Perform the requested operation */
			 rc = pEngine->pIo->pMethods->xAppend(pEngine,pKey,nKeyLen,SyBlobData(&sWorker),SyBlobLength(&sWorker));
			 /* Clean up */
			 SyBlobRelease(&sWorker);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_fetch()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_fetch(unqlite *pDb,const void *pKey,int nKeyLen,void *pBuf,unqlite_int64 *pBufLen)
{
	unqlite_kv_methods *pMethods;
	unqlite_kv_engine *pEngine;
	unqlite_kv_cursor *pCur;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 pMethods = pEngine->pIo->pMethods;
	 pCur = pDb->sDB.pCursor;
	 if( nKeyLen < 0 ){
		 /* Assume a null terminated string and compute it's length */
		 nKeyLen = SyStrlen((const char *)pKey);
	 }
	 /* Seek to the record position */
	 rc = pMethods->xSeek(pCur,pKey,nKeyLen,UNQLITE_CURSOR_MATCH_EXACT);
	 if( rc == UNQLITE_OK ){
		 if( pBuf == 0 ){
			 /* Data length only */
			 rc = pMethods->xDataLength(pCur,pBufLen);
		 }else{
			 SyBlob sBlob;
			 /* Initialize the data consumer */
			 SyBlobInitFromBuf(&sBlob,pBuf,(sxu32)*pBufLen);
			 /* Consume the data */
			 rc = pMethods->xData(pCur,unqliteDataConsumer,&sBlob);
			 /* Data length */
			 *pBufLen = (unqlite_int64)SyBlobLength(&sBlob);
			 /* Cleanup */
			 SyBlobRelease(&sBlob);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_fetch_callback()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_fetch_callback(unqlite *pDb,const void *pKey,int nKeyLen,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	unqlite_kv_methods *pMethods;
	unqlite_kv_engine *pEngine;
	unqlite_kv_cursor *pCur;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 pMethods = pEngine->pIo->pMethods;
	 pCur = pDb->sDB.pCursor;
	 if( nKeyLen < 0 ){
		 /* Assume a null terminated string and compute it's length */
		 nKeyLen = SyStrlen((const char *)pKey);
	 }
	 /* Seek to the record position */
	 rc = pMethods->xSeek(pCur, pKey, nKeyLen, UNQLITE_CURSOR_MATCH_EXACT); 
	 if( rc == UNQLITE_OK && xConsumer ){
		 /* Consume the data directly */
		 rc = pMethods->xData(pCur,xConsumer,pUserData);	 
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_delete()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_delete(unqlite *pDb,const void *pKey,int nKeyLen)
{
	unqlite_kv_methods *pMethods;
	unqlite_kv_engine *pEngine;
	unqlite_kv_cursor *pCur;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 pMethods = pEngine->pIo->pMethods;
	 pCur = pDb->sDB.pCursor;
	 if( pMethods->xDelete == 0 ){
		 /* Storage engine does not implement such method */
		 unqliteGenError(pDb,"xDelete() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 if( nKeyLen < 0 ){
			 /* Assume a null terminated string and compute it's length */
			 nKeyLen = SyStrlen((const char *)pKey);
		 }
		 /* Seek to the record position */
		 rc = pMethods->xSeek(pCur,pKey,nKeyLen,UNQLITE_CURSOR_MATCH_EXACT);
		 if( rc == UNQLITE_OK ){
			 /* Exact match found, delete the entry */
			 rc = pMethods->xDelete(pCur);
		 }
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_config()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_config(unqlite *pDb,int iOp,...)
{
	unqlite_kv_engine *pEngine;
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Point to the underlying storage engine */
	 pEngine = unqlitePagerGetKvEngine(pDb);
	 if( pEngine->pIo->pMethods->xConfig == 0 ){
		 /* Storage engine does not implements such method */
		 unqliteGenError(pDb,"xConfig() method not implemented in the underlying storage engine");
		 rc = UNQLITE_NOTIMPLEMENTED;
	 }else{
		 va_list ap;
		 /* Configure the storage engine */
		 va_start(ap,iOp);
		 rc = pEngine->pIo->pMethods->xConfig(pEngine,iOp,ap);
		 va_end(ap);
	 }
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_init()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_init(unqlite *pDb,unqlite_kv_cursor **ppOut)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) || ppOut == 0 /* Noop */){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Allocate a new cursor */
	 rc = unqliteInitCursor(pDb,ppOut);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_release()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_release(unqlite *pDb,unqlite_kv_cursor *pCur)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) || pCur == 0 /* Noop */){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Release the cursor */
	 rc = unqliteReleaseCursor(pDb,pCur);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_first_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_first_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xFirst == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Seek to the first entry */
		rc = pCursor->pStore->pIo->pMethods->xFirst(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_last_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_last_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xLast == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Seek to the last entry */
		rc = pCursor->pStore->pIo->pMethods->xLast(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_valid_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_valid_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xValid == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		rc = pCursor->pStore->pIo->pMethods->xValid(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_next_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_next_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xNext == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Seek to the next entry */
		rc = pCursor->pStore->pIo->pMethods->xNext(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_prev_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_prev_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xPrev == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Seek to the previous entry */
		rc = pCursor->pStore->pIo->pMethods->xPrev(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_delete_entry()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_delete_entry(unqlite_kv_cursor *pCursor)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xDelete == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Delete the entry */
		rc = pCursor->pStore->pIo->pMethods->xDelete(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_reset()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_reset(unqlite_kv_cursor *pCursor)
{
	int rc = UNQLITE_OK;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Check if the requested method is implemented by the underlying storage engine */
	if( pCursor->pStore->pIo->pMethods->xReset == 0 ){
		rc = UNQLITE_NOTIMPLEMENTED;
	}else{
		/* Reset */
		pCursor->pStore->pIo->pMethods->xReset(pCursor);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_seek()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_seek(unqlite_kv_cursor *pCursor,const void *pKey,int nKeyLen,int iPos)
{
	int rc = UNQLITE_OK;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	if( nKeyLen < 0 ){
		/* Assume a null terminated string and compute it's length */
		nKeyLen = SyStrlen((const char *)pKey);
	}
	/* Seek to the desired location */
	rc = pCursor->pStore->pIo->pMethods->xSeek(pCursor,pKey,nKeyLen,iPos);
	return rc;
}
/*
 * Default data consumer callback. That is, all retrieved is redirected to this
 * routine which store the output in an internal blob.
 */
UNQLITE_PRIVATE int unqliteDataConsumer(
	const void *pOut,   /* Data to consume */
	unsigned int nLen,  /* Data length */
	void *pUserData     /* User private data */
	)
{
	 sxi32 rc;
	 /* Store the output in an internal BLOB */
	 rc = SyBlobAppend((SyBlob *)pUserData, pOut, nLen);
	 return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_data_callback()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_key_callback(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Consume the key directly */
	rc = pCursor->pStore->pIo->pMethods->xKey(pCursor,xConsumer,pUserData);
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_key()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_key(unqlite_kv_cursor *pCursor,void *pBuf,int *pnByte)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	if( pBuf == 0 ){
		/* Key length only */
		rc = pCursor->pStore->pIo->pMethods->xKeyLength(pCursor,pnByte);
	}else{
		SyBlob sBlob;
		if( (*pnByte) < 0 ){
			return UNQLITE_CORRUPT;
		}
		/* Initialize the data consumer */
		SyBlobInitFromBuf(&sBlob,pBuf,(sxu32)(*pnByte));
		/* Consume the key */
		rc = pCursor->pStore->pIo->pMethods->xKey(pCursor,unqliteDataConsumer,&sBlob);
		 /* Key length */
		*pnByte = SyBlobLength(&sBlob);
		/* Cleanup */
		SyBlobRelease(&sBlob);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_data_callback()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_data_callback(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	/* Consume the data directly */
	rc = pCursor->pStore->pIo->pMethods->xData(pCursor,xConsumer,pUserData);
	return rc;
}
/*
 * [CAPIREF: unqlite_kv_cursor_data()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_kv_cursor_data(unqlite_kv_cursor *pCursor,void *pBuf,unqlite_int64 *pnByte)
{
	int rc;
#ifdef UNTRUST
	if( pCursor == 0 ){
		return UNQLITE_CORRUPT;
	}
#endif
	if( pBuf == 0 ){
		/* Data length only */
		rc = pCursor->pStore->pIo->pMethods->xDataLength(pCursor,pnByte);
	}else{
		SyBlob sBlob;
		if( (*pnByte) < 0 ){
			return UNQLITE_CORRUPT;
		}
		/* Initialize the data consumer */
		SyBlobInitFromBuf(&sBlob,pBuf,(sxu32)(*pnByte));
		/* Consume the data */
		rc = pCursor->pStore->pIo->pMethods->xData(pCursor,unqliteDataConsumer,&sBlob);
		/* Data length */
		*pnByte = SyBlobLength(&sBlob);
		/* Cleanup */
		SyBlobRelease(&sBlob);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_begin()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_begin(unqlite *pDb)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Begin the write transaction */
	 rc = unqlitePagerBegin(pDb->sDB.pPager);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return rc;
}
/*
 * [CAPIREF: unqlite_commit()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_commit(unqlite *pDb)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Commit the transaction */
	 rc = unqlitePagerCommit(pDb->sDB.pPager);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return rc;
}
/*
 * [CAPIREF: unqlite_rollback()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
int unqlite_rollback(unqlite *pDb)
{
	int rc;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Rollback the transaction */
	 rc = unqlitePagerRollback(pDb->sDB.pPager,TRUE);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return rc;
}
/*
 * [CAPIREF: unqlite_util_load_mmaped_file()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
UNQLITE_APIEXPORT int unqlite_util_load_mmaped_file(const char *zFile, void **ppMap, unqlite_int64 *pFileSize)
{
	const unqlite_vfs *pVfs;
	int rc;
	if (SX_EMPTY_STR(zFile) || ppMap == 0 || pFileSize == 0) {
		/* Sanity check */
		return UNQLITE_CORRUPT;
	}
	*ppMap = 0;
	/* Extract the Vfs */
	pVfs = unqliteExportBuiltinVfs();
	/*
	 * Check if the underlying vfs implement the memory map routines
	 * [i.e: mmap() under UNIX/MapViewOfFile() under windows].
	 */
	if (pVfs == 0 || pVfs->xMmap == 0) {
		rc = UNQLITE_NOTIMPLEMENTED;
	}
	else {
		/* Try to get a read-only memory view of the whole file */
		rc = pVfs->xMmap(zFile, ppMap, pFileSize);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_util_release_mmaped_file()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
UNQLITE_APIEXPORT int unqlite_util_release_mmaped_file(void *pMap, unqlite_int64 iFileSize)
{
	const unqlite_vfs *pVfs;
	int rc = UNQLITE_OK;
	if (pMap == 0) {
		return UNQLITE_OK;
	}
	/* Extract the Vfs */
	pVfs = unqliteExportBuiltinVfs();
	if (pVfs == 0 || pVfs->xUnmap == 0) {
		rc = UNQLITE_NOTIMPLEMENTED;
	}
	else {
		pVfs->xUnmap(pMap, iFileSize);
	}
	return rc;
}
/*
 * [CAPIREF: unqlite_util_random_string()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
UNQLITE_APIEXPORT int unqlite_util_random_string(unqlite *pDb,char *zBuf,unsigned int buf_size)
{
	if( UNQLITE_DB_MISUSE(pDb) ){
		return UNQLITE_CORRUPT;
	}
	if( zBuf == 0 || buf_size < 3 ){
		/* Buffer must be long enough to hold three bytes */
		return UNQLITE_INVALID;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return UNQLITE_ABORT; /* Another thread have released this instance */
	 }
#endif
	 /* Generate the random string */
	 unqlitePagerRandomString(pDb->sDB.pPager,zBuf,buf_size);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return UNQLITE_OK;
}
/*
 * [CAPIREF: unqlite_util_random_num()]
 * Please refer to the official documentation for function purpose and expected parameters.
 */
UNQLITE_APIEXPORT unsigned int unqlite_util_random_num(unqlite *pDb)
{
	sxu32 iNum;
	if( UNQLITE_DB_MISUSE(pDb) ){
		return 0;
	}
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Acquire DB mutex */
	 SyMutexEnter(sUnqlMPGlobal.pMutexMethods, pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
	 if( sUnqlMPGlobal.nThreadingLevel > UNQLITE_THREAD_LEVEL_SINGLE && 
		 UNQLITE_THRD_DB_RELEASE(pDb) ){
			 return 0; /* Another thread have released this instance */
	 }
#endif
	 /* Generate the random number */
	 iNum = unqlitePagerRandomNum(pDb->sDB.pPager);
#if defined(UNQLITE_ENABLE_THREADS)
	 /* Leave DB mutex */
	 SyMutexLeave(sUnqlMPGlobal.pMutexMethods,pDb->pMutex); /* NO-OP if sUnqlMPGlobal.nThreadingLevel != UNQLITE_THREAD_LEVEL_MULTI */
#endif
	 return iNum;
}
/*
 * ----------------------------------------------------------
 * File: bitvec.c
 * ID: 7e3376710d8454ebcf8c77baacca880f
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: bitvec.c v1.0 Win7 2013-02-27 15:16 stable <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif

/** This file implements an object that represents a dynmaic
** bitmap.
**
** A bitmap is used to record which pages of a database file have been
** journalled during a transaction, or which pages have the "dont-write"
** property.  Usually only a few pages are meet either condition.
** So the bitmap is usually sparse and has low cardinality.
*/
/*
 * Actually, this is not a bitmap but a simple hashtable where page 
 * number (64-bit unsigned integers) are used as the lookup keys.
 */
typedef struct bitvec_rec bitvec_rec;
struct bitvec_rec
{
	pgno iPage;                  /* Page number */
	bitvec_rec *pNext,*pNextCol; /* Collison link */
};
struct Bitvec
{
	SyMemBackend *pAlloc; /* Memory allocator */
	sxu32 nRec;           /* Total number of records */
	sxu32 nSize;          /* Table size */
	bitvec_rec **apRec;   /* Record table */
	bitvec_rec *pList;    /* List of records */
};
/* 
 * Allocate a new bitvec instance.
*/
UNQLITE_PRIVATE Bitvec * unqliteBitvecCreate(SyMemBackend *pAlloc,pgno iSize)
{
	bitvec_rec **apNew;
	Bitvec *p;
	
	p = (Bitvec *)SyMemBackendAlloc(pAlloc,sizeof(*p) );
	if( p == 0 ){
		SXUNUSED(iSize); /* cc warning */
		return 0;
	}
	/* Zero the structure */
	SyZero(p,sizeof(Bitvec));
	/* Allocate a new table */
	p->nSize = 64; /* Must be a power of two */
	apNew = (bitvec_rec **)SyMemBackendAlloc(pAlloc,p->nSize * sizeof(bitvec_rec *));
	if( apNew == 0 ){
		SyMemBackendFree(pAlloc,p);
		return 0;
	}
	/* Zero the new table */
	SyZero((void *)apNew,p->nSize * sizeof(bitvec_rec *));
	/* Fill-in */
	p->apRec = apNew;
	p->pAlloc = pAlloc;
	return p;
}
/*
 * Check if the given page number is already installed in the table.
 * Return true if installed. False otherwise.
 */
UNQLITE_PRIVATE int unqliteBitvecTest(Bitvec *p,pgno i)
{  
	bitvec_rec *pRec;
	/* Point to the desired bucket */
	pRec = p->apRec[i & (p->nSize - 1)];
	for(;;){
		if( pRec == 0 ){ break; }
		if( pRec->iPage == i ){
			/* Page found */
			return 1;
		}
		/* Point to the next entry */
		pRec = pRec->pNextCol;

		if( pRec == 0 ){ break; }
		if( pRec->iPage == i ){
			/* Page found */
			return 1;
		}
		/* Point to the next entry */
		pRec = pRec->pNextCol;


		if( pRec == 0 ){ break; }
		if( pRec->iPage == i ){
			/* Page found */
			return 1;
		}
		/* Point to the next entry */
		pRec = pRec->pNextCol;


		if( pRec == 0 ){ break; }
		if( pRec->iPage == i ){
			/* Page found */
			return 1;
		}
		/* Point to the next entry */
		pRec = pRec->pNextCol;
	}
	/* No such entry */
	return 0;
}
/*
 * Install a given page number in our bitmap (Actually, our hashtable).
 */
UNQLITE_PRIVATE int unqliteBitvecSet(Bitvec *p,pgno i)
{
	bitvec_rec *pRec;
	sxi32 iBuck;
	/* Allocate a new instance */
	pRec = (bitvec_rec *)SyMemBackendPoolAlloc(p->pAlloc,sizeof(bitvec_rec));
	if( pRec == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pRec,sizeof(bitvec_rec));
	/* Fill-in */
	pRec->iPage = i;
	iBuck = i & (p->nSize - 1);
	pRec->pNextCol = p->apRec[iBuck];
	p->apRec[iBuck] = pRec;
	pRec->pNext = p->pList;
	p->pList = pRec;
	p->nRec++;
	if( p->nRec >= (p->nSize * 3) && p->nRec < 100000 ){
		/* Grow the hashtable */
		sxu32 nNewSize = p->nSize << 1;
		bitvec_rec *pEntry,**apNew;
		sxu32 n;
		apNew = (bitvec_rec **)SyMemBackendAlloc(p->pAlloc, nNewSize * sizeof(bitvec_rec *));
		if( apNew ){
			sxu32 iBucket;
			/* Zero the new table */
			SyZero((void *)apNew, nNewSize * sizeof(bitvec_rec *));
			/* Rehash all entries */
			n = 0;
			pEntry = p->pList;
			for(;;){
				/* Loop one */
				if( n >= p->nRec ){
					break;
				}
				pEntry->pNextCol = 0;
				/* Install in the new bucket */
				iBucket = pEntry->iPage & (nNewSize - 1);
				pEntry->pNextCol = apNew[iBucket];
				apNew[iBucket] = pEntry;
				/* Point to the next entry */
				pEntry = pEntry->pNext;
				n++;
			}
			/* Release the old table and reflect the change */
			SyMemBackendFree(p->pAlloc,(void *)p->apRec);
			p->apRec = apNew;
			p->nSize  = nNewSize;
		}
	}
	return UNQLITE_OK;
}
/*
 * Destroy a bitvec instance. Reclaim all memory used.
 */
UNQLITE_PRIVATE void unqliteBitvecDestroy(Bitvec *p)
{
	bitvec_rec *pNext,*pRec = p->pList;
	SyMemBackend *pAlloc = p->pAlloc;
	
	for(;;){
		if( p->nRec < 1 ){
			break;
		}
		pNext = pRec->pNext;
		SyMemBackendPoolFree(pAlloc,(void *)pRec);
		pRec = pNext;
		p->nRec--;

		if( p->nRec < 1 ){
			break;
		}
		pNext = pRec->pNext;
		SyMemBackendPoolFree(pAlloc,(void *)pRec);
		pRec = pNext;
		p->nRec--;


		if( p->nRec < 1 ){
			break;
		}
		pNext = pRec->pNext;
		SyMemBackendPoolFree(pAlloc,(void *)pRec);
		pRec = pNext;
		p->nRec--;


		if( p->nRec < 1 ){
			break;
		}
		pNext = pRec->pNext;
		SyMemBackendPoolFree(pAlloc,(void *)pRec);
		pRec = pNext;
		p->nRec--;
	}
	SyMemBackendFree(pAlloc,(void *)p->apRec);
	SyMemBackendFree(pAlloc,p);
}

#if defined(__WINNT__)
#include <Windows.h>
#else
#include <stdlib.h>
#endif
#if defined(UNQLITE_ENABLE_THREADS)
/* SyRunTimeApi: sxmutex.c */
#if defined(__WINNT__)
struct SyMutex
{
	CRITICAL_SECTION sMutex;
	sxu32 nType; /* Mutex type, one of SXMUTEX_TYPE_* */
};
/* Preallocated static mutex */
static SyMutex aStaticMutexes[] = {
		{{0}, SXMUTEX_TYPE_STATIC_1}, 
		{{0}, SXMUTEX_TYPE_STATIC_2}, 
		{{0}, SXMUTEX_TYPE_STATIC_3}, 
		{{0}, SXMUTEX_TYPE_STATIC_4}, 
		{{0}, SXMUTEX_TYPE_STATIC_5}, 
		{{0}, SXMUTEX_TYPE_STATIC_6}
};
static BOOL winMutexInit = FALSE;
static LONG winMutexLock = 0;

static sxi32 WinMutexGlobaInit(void)
{
	LONG rc;
	rc = InterlockedCompareExchange(&winMutexLock, 1, 0);
	if ( rc == 0 ){
		sxu32 n;
		for( n = 0 ; n  < SX_ARRAYSIZE(aStaticMutexes) ; ++n ){
			InitializeCriticalSection(&aStaticMutexes[n].sMutex);
		}
		winMutexInit = TRUE;
	}else{
		/* Someone else is doing this for us */
		while( winMutexInit == FALSE ){
			Sleep(1);
		}
	}
	return SXRET_OK;
}
static void WinMutexGlobalRelease(void)
{
	LONG rc;
	rc = InterlockedCompareExchange(&winMutexLock, 0, 1);
	if( rc == 1 ){
		/* The first to decrement to zero does the actual global release */
		if( winMutexInit == TRUE ){
			sxu32 n;
			for( n = 0 ; n < SX_ARRAYSIZE(aStaticMutexes) ; ++n ){
				DeleteCriticalSection(&aStaticMutexes[n].sMutex);
			}
			winMutexInit = FALSE;
		}
	}
}
static SyMutex * WinMutexNew(int nType)
{
	SyMutex *pMutex = 0;
	if( nType == SXMUTEX_TYPE_FAST || nType == SXMUTEX_TYPE_RECURSIVE ){
		/* Allocate a new mutex */
		pMutex = (SyMutex *)HeapAlloc(GetProcessHeap(), 0, sizeof(SyMutex));
		if( pMutex == 0 ){
			return 0;
		}
		InitializeCriticalSection(&pMutex->sMutex);
	}else{
		/* Use a pre-allocated static mutex */
		if( nType > SXMUTEX_TYPE_STATIC_6 ){
			nType = SXMUTEX_TYPE_STATIC_6;
		}
		pMutex = &aStaticMutexes[nType - 3];
	}
	pMutex->nType = nType;
	return pMutex;
}
static void WinMutexRelease(SyMutex *pMutex)
{
	if( pMutex->nType == SXMUTEX_TYPE_FAST || pMutex->nType == SXMUTEX_TYPE_RECURSIVE ){
		DeleteCriticalSection(&pMutex->sMutex);
		HeapFree(GetProcessHeap(), 0, pMutex);
	}
}
static void WinMutexEnter(SyMutex *pMutex)
{
	EnterCriticalSection(&pMutex->sMutex);
}
static sxi32 WinMutexTryEnter(SyMutex *pMutex)
{
#ifdef _WIN32_WINNT
	BOOL rc;
	/* Only WindowsNT platforms */
	rc = TryEnterCriticalSection(&pMutex->sMutex);
	if( rc ){
		return SXRET_OK;
	}else{
		return SXERR_BUSY;
	}
#else
	return SXERR_NOTIMPLEMENTED;
#endif
}
static void WinMutexLeave(SyMutex *pMutex)
{
	LeaveCriticalSection(&pMutex->sMutex);
}
/* Export Windows mutex interfaces */
static const SyMutexMethods sWinMutexMethods = {
	WinMutexGlobaInit,  /* xGlobalInit() */
	WinMutexGlobalRelease, /* xGlobalRelease() */
	WinMutexNew,     /* xNew() */
	WinMutexRelease, /* xRelease() */
	WinMutexEnter,   /* xEnter() */
	WinMutexTryEnter, /* xTryEnter() */
	WinMutexLeave     /* xLeave() */
};
UNQLITE_PRIVATE const SyMutexMethods * SyMutexExportMethods(void)
{
	return &sWinMutexMethods;
}
#elif defined(__UNIXES__)
#include <pthread.h>
struct SyMutex
{
	pthread_mutex_t sMutex;
	sxu32 nType;
};
static SyMutex * UnixMutexNew(int nType)
{
	static SyMutex aStaticMutexes[] = {
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_1}, 
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_2}, 
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_3}, 
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_4}, 
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_5}, 
		{PTHREAD_MUTEX_INITIALIZER, SXMUTEX_TYPE_STATIC_6}
	};
	SyMutex *pMutex;
	
	if( nType == SXMUTEX_TYPE_FAST || nType == SXMUTEX_TYPE_RECURSIVE ){
		pthread_mutexattr_t sRecursiveAttr;
  		/* Allocate a new mutex */
  		pMutex = (SyMutex *)malloc(sizeof(SyMutex));
  		if( pMutex == 0 ){
  			return 0;
  		}
  		if( nType == SXMUTEX_TYPE_RECURSIVE ){
  			pthread_mutexattr_init(&sRecursiveAttr);
  			pthread_mutexattr_settype(&sRecursiveAttr, PTHREAD_MUTEX_RECURSIVE);
  		}
  		pthread_mutex_init(&pMutex->sMutex, nType == SXMUTEX_TYPE_RECURSIVE ? &sRecursiveAttr : 0 );
		if(	nType == SXMUTEX_TYPE_RECURSIVE ){
   			pthread_mutexattr_destroy(&sRecursiveAttr);
		}
	}else{
		/* Use a pre-allocated static mutex */
		if( nType > SXMUTEX_TYPE_STATIC_6 ){
			nType = SXMUTEX_TYPE_STATIC_6;
		}
		pMutex = &aStaticMutexes[nType - 3];
	}
  pMutex->nType = nType;
  
  return pMutex;
}
static void UnixMutexRelease(SyMutex *pMutex)
{
	if( pMutex->nType == SXMUTEX_TYPE_FAST || pMutex->nType == SXMUTEX_TYPE_RECURSIVE ){
		pthread_mutex_destroy(&pMutex->sMutex);
		free(pMutex);
	}
}
static void UnixMutexEnter(SyMutex *pMutex)
{
	pthread_mutex_lock(&pMutex->sMutex);
}
static void UnixMutexLeave(SyMutex *pMutex)
{
	pthread_mutex_unlock(&pMutex->sMutex);
}
/* Export pthread mutex interfaces */
static const SyMutexMethods sPthreadMutexMethods = {
	0, /* xGlobalInit() */
	0, /* xGlobalRelease() */
	UnixMutexNew,      /* xNew() */
	UnixMutexRelease,  /* xRelease() */
	UnixMutexEnter,    /* xEnter() */
	0,                 /* xTryEnter() */
	UnixMutexLeave     /* xLeave() */
};
UNQLITE_PRIVATE const SyMutexMethods * SyMutexExportMethods(void)
{
	return &sPthreadMutexMethods;
}
#else
/* Host application must register their own mutex subsystem if the target
 * platform is not an UNIX-like or windows systems.
 */
struct SyMutex
{
	sxu32 nType;
};
static SyMutex * DummyMutexNew(int nType)
{
	static SyMutex sMutex;
	SXUNUSED(nType);
	return &sMutex;
}
static void DummyMutexRelease(SyMutex *pMutex)
{
	SXUNUSED(pMutex);
}
static void DummyMutexEnter(SyMutex *pMutex)
{
	SXUNUSED(pMutex);
}
static void DummyMutexLeave(SyMutex *pMutex)
{
	SXUNUSED(pMutex);
}
/* Export the dummy mutex interfaces */
static const SyMutexMethods sDummyMutexMethods = {
	0, /* xGlobalInit() */
	0, /* xGlobalRelease() */
	DummyMutexNew,      /* xNew() */
	DummyMutexRelease,  /* xRelease() */
	DummyMutexEnter,    /* xEnter() */
	0,                  /* xTryEnter() */
	DummyMutexLeave     /* xLeave() */
};
UNQLITE_PRIVATE const SyMutexMethods * SyMutexExportMethods(void)
{
	return &sDummyMutexMethods;
}
#endif /* __WINNT__ */
#endif /* UNQLITE_ENABLE_THREADS */
static void * SyOSHeapAlloc(sxu32 nByte)
{
	void *pNew;
#if defined(__WINNT__)
	pNew = HeapAlloc(GetProcessHeap(), 0, nByte);
#else
	pNew = malloc((size_t)nByte);
#endif
	return pNew;
}
static void * SyOSHeapRealloc(void *pOld, sxu32 nByte)
{
	void *pNew;
#if defined(__WINNT__)
	pNew = HeapReAlloc(GetProcessHeap(), 0, pOld, nByte);
#else
	pNew = realloc(pOld, (size_t)nByte);
#endif
	return pNew;	
}
static void SyOSHeapFree(void *pPtr)
{
#if defined(__WINNT__)
	HeapFree(GetProcessHeap(), 0, pPtr);
#else
	free(pPtr);
#endif
}
/* SyRunTimeApi:sxstr.c */
UNQLITE_PRIVATE sxi32 SyStrnicmp(const char *zLeft, const char *zRight, sxu32 SLen)
{
  	 unsigned char *p = (unsigned char *)zLeft;
	 unsigned char *q = (unsigned char *)zRight;
	
	if( SX_EMPTY_STR(p) || SX_EMPTY_STR(q) ){
		return SX_EMPTY_STR(p)? SX_EMPTY_STR(q) ? 0 : -1 :1;
	}
	for(;;){
		if( !SLen ){ return 0; }if( !*p || !*q || SyCharToLower(*p) != SyCharToLower(*q) ){ break; }p++;q++;--SLen;
		if( !SLen ){ return 0; }if( !*p || !*q || SyCharToLower(*p) != SyCharToLower(*q) ){ break; }p++;q++;--SLen;
		if( !SLen ){ return 0; }if( !*p || !*q || SyCharToLower(*p) != SyCharToLower(*q) ){ break; }p++;q++;--SLen;
		if( !SLen ){ return 0; }if( !*p || !*q || SyCharToLower(*p) != SyCharToLower(*q) ){ break; }p++;q++;--SLen;
		
	}
	return (sxi32)(SyCharToLower(p[0]) - SyCharToLower(q[0]));
}

#if defined(__APPLE__)
UNQLITE_PRIVATE sxi32 SyStrncmp(const char *zLeft, const char *zRight, sxu32 nLen)
{
	const unsigned char *zP = (const unsigned char *)zLeft;
	const unsigned char *zQ = (const unsigned char *)zRight;

	if( SX_EMPTY_STR(zP) || SX_EMPTY_STR(zQ)  ){
			return SX_EMPTY_STR(zP) ? (SX_EMPTY_STR(zQ) ? 0 : -1) :1;
	}
	if( nLen <= 0 ){
		return 0;
	}
	for(;;){
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
	}
	return (sxi32)(zP[0] - zQ[0]);
}	
#endif

UNQLITE_PRIVATE sxu32 Systrcpy(char *zDest, sxu32 nDestLen, const char *zSrc, sxu32 nLen)
{
	unsigned char *zBuf = (unsigned char *)zDest;
	unsigned char *zIn = (unsigned char *)zSrc;
	unsigned char *zEnd;
#if defined(UNTRUST)
	if( zSrc == (const char *)zDest ){
			return 0;
	}
#endif
	if( nLen <= 0 ){
		nLen = SyStrlen(zSrc);
	}
	zEnd = &zBuf[nDestLen - 1]; /* reserve a room for the null terminator */
	for(;;){
		if( zBuf >= zEnd || nLen == 0 ){ break;} zBuf[0] = zIn[0]; zIn++; zBuf++; nLen--;
		if( zBuf >= zEnd || nLen == 0 ){ break;} zBuf[0] = zIn[0]; zIn++; zBuf++; nLen--;
		if( zBuf >= zEnd || nLen == 0 ){ break;} zBuf[0] = zIn[0]; zIn++; zBuf++; nLen--;
		if( zBuf >= zEnd || nLen == 0 ){ break;} zBuf[0] = zIn[0]; zIn++; zBuf++; nLen--;
	}
	zBuf[0] = 0;
	return (sxu32)(zBuf-(unsigned char *)zDest);
}
/* SyRunTimeApi:sxmem.c */
UNQLITE_PRIVATE sxi32 SyMemcmp(const void *pB1, const void *pB2, sxu32 nSize)
{
	if( nSize <= 0 ){
		return 0;
	}
	if( pB1 == 0 || pB2 == 0 ){
		return pB1 != 0 ? 1 : (pB2 == 0 ? 0 : -1);
	}
	return memcmp(pB1, pB2, nSize);
}
UNQLITE_PRIVATE sxu32 SyMemcpy(const void *pSrc, void *pDest, sxu32 nLen)
{
	if( pSrc == 0 || pDest == 0 ){
		return 0;
	}
	if( pSrc == (const void *)pDest ){
		return nLen;
	}
	memcpy(pDest, pSrc, nLen);
	return nLen;
}
static void * MemOSAlloc(sxu32 nBytes)
{
	sxu32 *pChunk;
	pChunk = (sxu32 *)SyOSHeapAlloc(nBytes + sizeof(sxu32));
	if( pChunk == 0 ){
		return 0;
	}
	pChunk[0] = nBytes;
	return (void *)&pChunk[1];
}
static void * MemOSRealloc(void *pOld, sxu32 nBytes)
{
	sxu32 *pOldChunk;
	sxu32 *pChunk;
	pOldChunk = (sxu32 *)(((char *)pOld)-sizeof(sxu32));
	if( pOldChunk[0] >= nBytes ){
		return pOld;
	}
	pChunk = (sxu32 *)SyOSHeapRealloc(pOldChunk, nBytes + sizeof(sxu32));
	if( pChunk == 0 ){
		return 0;
	}
	pChunk[0] = nBytes;
	return (void *)&pChunk[1];
}
static void MemOSFree(void *pBlock)
{
	void *pChunk;
	pChunk = (void *)(((char *)pBlock)-sizeof(sxu32));
	SyOSHeapFree(pChunk);
}
static sxu32 MemOSChunkSize(void *pBlock)
{
	sxu32 *pChunk;
	pChunk = (sxu32 *)(((char *)pBlock)-sizeof(sxu32));
	return pChunk[0];
}
/* Export OS allocation methods */
static const SyMemMethods sOSAllocMethods = {
	MemOSAlloc, 
	MemOSRealloc, 
	MemOSFree, 
	MemOSChunkSize, 
	0, 
	0, 
	0
};
static void * MemBackendAlloc(SyMemBackend *pBackend, sxu32 nByte)
{
	SyMemBlock *pBlock;
	sxi32 nRetry = 0;

	/* Append an extra block so we can tracks allocated chunks and avoid memory
	 * leaks.
	 */
	nByte += sizeof(SyMemBlock);
	for(;;){
		pBlock = (SyMemBlock *)pBackend->pMethods->xAlloc(nByte);
		if( pBlock != 0 || pBackend->xMemError == 0 || nRetry > SXMEM_BACKEND_RETRY 
			|| SXERR_RETRY != pBackend->xMemError(pBackend->pUserData) ){
				break;
		}
		nRetry++;
	}
	if( pBlock  == 0 ){
		return 0;
	}
	pBlock->pNext = pBlock->pPrev = 0;
	/* Link to the list of already tracked blocks */
	MACRO_LD_PUSH(pBackend->pBlocks, pBlock);
#if defined(UNTRUST)
	pBlock->nGuard = SXMEM_BACKEND_MAGIC;
#endif
	pBackend->nBlock++;
	return (void *)&pBlock[1];
}
UNQLITE_PRIVATE void * SyMemBackendAlloc(SyMemBackend *pBackend, sxu32 nByte)
{
	void *pChunk;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) ){
		return 0;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	pChunk = MemBackendAlloc(&(*pBackend), nByte);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return pChunk;
}
static void * MemBackendRealloc(SyMemBackend *pBackend, void * pOld, sxu32 nByte)
{
	SyMemBlock *pBlock, *pNew, *pPrev, *pNext;
	sxu32 nRetry = 0;

	if( pOld == 0 ){
		return MemBackendAlloc(&(*pBackend), nByte);
	}
	pBlock = (SyMemBlock *)(((char *)pOld) - sizeof(SyMemBlock));
#if defined(UNTRUST)
	if( pBlock->nGuard != SXMEM_BACKEND_MAGIC ){
		return 0;
	}
#endif
	nByte += sizeof(SyMemBlock);
	pPrev = pBlock->pPrev;
	pNext = pBlock->pNext;
	for(;;){
		pNew = (SyMemBlock *)pBackend->pMethods->xRealloc(pBlock, nByte);
		if( pNew != 0 || pBackend->xMemError == 0 || nRetry > SXMEM_BACKEND_RETRY ||
			SXERR_RETRY != pBackend->xMemError(pBackend->pUserData) ){
				break;
		}
		nRetry++;
	}
	if( pNew == 0 ){
		return 0;
	}
	if( pNew != pBlock ){
		if( pPrev == 0 ){
			pBackend->pBlocks = pNew;
		}else{
			pPrev->pNext = pNew;
		}
		if( pNext ){
			pNext->pPrev = pNew;
		}
#if defined(UNTRUST)
		pNew->nGuard = SXMEM_BACKEND_MAGIC;
#endif
	}
	return (void *)&pNew[1];
}
UNQLITE_PRIVATE void * SyMemBackendRealloc(SyMemBackend *pBackend, void * pOld, sxu32 nByte)
{
	void *pChunk;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend)  ){
		return 0;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	pChunk = MemBackendRealloc(&(*pBackend), pOld, nByte);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return pChunk;
}
static sxi32 MemBackendFree(SyMemBackend *pBackend, void * pChunk)
{
	SyMemBlock *pBlock;
	pBlock = (SyMemBlock *)(((char *)pChunk) - sizeof(SyMemBlock));
#if defined(UNTRUST)
	if( pBlock->nGuard != SXMEM_BACKEND_MAGIC ){
		return SXERR_CORRUPT;
	}
#endif
	/* Unlink from the list of active blocks */
	if( pBackend->nBlock > 0 ){
		/* Release the block */
#if defined(UNTRUST)
		/* Mark as stale block */
		pBlock->nGuard = 0x635B;
#endif
		MACRO_LD_REMOVE(pBackend->pBlocks, pBlock);
		pBackend->nBlock--;
		pBackend->pMethods->xFree(pBlock);
	}
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyMemBackendFree(SyMemBackend *pBackend, void * pChunk)
{
	sxi32 rc;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) ){
		return SXERR_CORRUPT;
	}
#endif
	if( pChunk == 0 ){
		return SXRET_OK;
	}
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	rc = MemBackendFree(&(*pBackend), pChunk);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return rc;
}
#if defined(UNQLITE_ENABLE_THREADS)
UNQLITE_PRIVATE sxi32 SyMemBackendMakeThreadSafe(SyMemBackend *pBackend, const SyMutexMethods *pMethods)
{
	SyMutex *pMutex;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) || pMethods == 0 || pMethods->xNew == 0){
		return SXERR_CORRUPT;
	}
#endif
	pMutex = pMethods->xNew(SXMUTEX_TYPE_FAST);
	if( pMutex == 0 ){
		return SXERR_OS;
	}
	/* Attach the mutex to the memory backend */
	pBackend->pMutex = pMutex;
	pBackend->pMutexMethods = pMethods;
	return SXRET_OK;
}
#endif
/*
 * Memory pool allocator
 */
#define SXMEM_POOL_MAGIC		0xDEAD
#define SXMEM_POOL_MAXALLOC		(1<<(SXMEM_POOL_NBUCKETS+SXMEM_POOL_INCR)) 
#define SXMEM_POOL_MINALLOC		(1<<(SXMEM_POOL_INCR))
static sxi32 MemPoolBucketAlloc(SyMemBackend *pBackend, sxu32 nBucket)
{
	char *zBucket, *zBucketEnd;
	SyMemHeader *pHeader;
	sxu32 nBucketSize;
	
	/* Allocate one big block first */
	zBucket = (char *)MemBackendAlloc(&(*pBackend), SXMEM_POOL_MAXALLOC);
	if( zBucket == 0 ){
		return SXERR_MEM;
	}
	zBucketEnd = &zBucket[SXMEM_POOL_MAXALLOC];
	/* Divide the big block into mini bucket pool */
	nBucketSize = 1 << (nBucket + SXMEM_POOL_INCR);
	pBackend->apPool[nBucket] = pHeader = (SyMemHeader *)zBucket;
	for(;;){
		if( &zBucket[nBucketSize] >= zBucketEnd ){
			break;
		}
		pHeader->pNext = (SyMemHeader *)&zBucket[nBucketSize];
		/* Advance the cursor to the next available chunk */
		pHeader = pHeader->pNext;
		zBucket += nBucketSize;	
	}
	pHeader->pNext = 0;
	
	return SXRET_OK;
}
static void * MemBackendPoolAlloc(SyMemBackend *pBackend, sxu32 nByte)
{
	SyMemHeader *pBucket, *pNext;
	sxu32 nBucketSize;
	sxu32 nBucket;

	if( nByte + sizeof(SyMemHeader) >= SXMEM_POOL_MAXALLOC ){
		/* Allocate a big chunk directly */
		pBucket = (SyMemHeader *)MemBackendAlloc(&(*pBackend), nByte+sizeof(SyMemHeader));
		if( pBucket == 0 ){
			return 0;
		}
		/* Record as big block */
		pBucket->nBucket = (sxu32)(SXMEM_POOL_MAGIC << 16) | SXU16_HIGH;
		return (void *)(pBucket+1);
	}
	/* Locate the appropriate bucket */
	nBucket = 0;
	nBucketSize = SXMEM_POOL_MINALLOC;
	while( nByte + sizeof(SyMemHeader) > nBucketSize  ){
		nBucketSize <<= 1;
		nBucket++;
	}
	pBucket = pBackend->apPool[nBucket];
	if( pBucket == 0 ){
		sxi32 rc;
		rc = MemPoolBucketAlloc(&(*pBackend), nBucket);
		if( rc != SXRET_OK ){
			return 0;
		}
		pBucket = pBackend->apPool[nBucket];
	}
	/* Remove from the free list */
	pNext = pBucket->pNext;
	pBackend->apPool[nBucket] = pNext;
	/* Record bucket&magic number */
	pBucket->nBucket = (SXMEM_POOL_MAGIC << 16) | nBucket;
	return (void *)&pBucket[1];
}
UNQLITE_PRIVATE void * SyMemBackendPoolAlloc(SyMemBackend *pBackend, sxu32 nByte)
{
	void *pChunk;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) ){
		return 0;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	pChunk = MemBackendPoolAlloc(&(*pBackend), nByte);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return pChunk;
}
static sxi32 MemBackendPoolFree(SyMemBackend *pBackend, void * pChunk)
{
	SyMemHeader *pHeader;
	sxu32 nBucket;
	/* Get the corresponding bucket */
	pHeader = (SyMemHeader *)(((char *)pChunk) - sizeof(SyMemHeader));
	/* Sanity check to avoid misuse */
	if( (pHeader->nBucket >> 16) != SXMEM_POOL_MAGIC ){
		return SXERR_CORRUPT;
	}
	nBucket = pHeader->nBucket & 0xFFFF;
	if( nBucket == SXU16_HIGH ){
		/* Free the big block */
		MemBackendFree(&(*pBackend), pHeader);
	}else{
		/* Return to the free list */
		pHeader->pNext = pBackend->apPool[nBucket & 0x0f];
		pBackend->apPool[nBucket & 0x0f] = pHeader;
	}
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyMemBackendPoolFree(SyMemBackend *pBackend, void * pChunk)
{
	sxi32 rc;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) || pChunk == 0 ){
		return SXERR_CORRUPT;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	rc = MemBackendPoolFree(&(*pBackend), pChunk);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return rc;
}
#if 0
static void * MemBackendPoolRealloc(SyMemBackend *pBackend, void * pOld, sxu32 nByte)
{
	sxu32 nBucket, nBucketSize;
	SyMemHeader *pHeader;
	void * pNew;

	if( pOld == 0 ){
		/* Allocate a new pool */
		pNew = MemBackendPoolAlloc(&(*pBackend), nByte);
		return pNew;
	}
	/* Get the corresponding bucket */
	pHeader = (SyMemHeader *)(((char *)pOld) - sizeof(SyMemHeader));
	/* Sanity check to avoid misuse */
	if( (pHeader->nBucket >> 16) != SXMEM_POOL_MAGIC ){
		return 0;
	}
	nBucket = pHeader->nBucket & 0xFFFF;
	if( nBucket == SXU16_HIGH ){
		/* Big block */
		return MemBackendRealloc(&(*pBackend), pHeader, nByte);
	}
	nBucketSize = 1 << (nBucket + SXMEM_POOL_INCR);
	if( nBucketSize >= nByte + sizeof(SyMemHeader) ){
		/* The old bucket can honor the requested size */
		return pOld;
	}
	/* Allocate a new pool */
	pNew = MemBackendPoolAlloc(&(*pBackend), nByte);
	if( pNew == 0 ){
		return 0;
	}
	/* Copy the old data into the new block */
	SyMemcpy(pOld, pNew, nBucketSize);
	/* Free the stale block */
	MemBackendPoolFree(&(*pBackend), pOld);
	return pNew;
}
UNQLITE_PRIVATE void * SyMemBackendPoolRealloc(SyMemBackend *pBackend, void * pOld, sxu32 nByte)
{
	void *pChunk;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) ){
		return 0;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	pChunk = MemBackendPoolRealloc(&(*pBackend), pOld, nByte);
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return pChunk;
}
#endif
UNQLITE_PRIVATE sxi32 SyMemBackendInit(SyMemBackend *pBackend, ProcMemError xMemErr, void * pUserData)
{
#if defined(UNTRUST)
	if( pBackend == 0 ){
		return SXERR_EMPTY;
	}
#endif
	/* Zero the allocator first */
	SyZero(&(*pBackend), sizeof(SyMemBackend));
	pBackend->xMemError = xMemErr;
	pBackend->pUserData = pUserData;
	/* Switch to the OS memory allocator */
	pBackend->pMethods = &sOSAllocMethods;
	if( pBackend->pMethods->xInit ){
		/* Initialize the backend  */
		if( SXRET_OK != pBackend->pMethods->xInit(pBackend->pMethods->pUserData) ){
			return SXERR_ABORT;
		}
	}
#if defined(UNTRUST)
	pBackend->nMagic = SXMEM_BACKEND_MAGIC;
#endif
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyMemBackendInitFromOthers(SyMemBackend *pBackend, const SyMemMethods *pMethods, ProcMemError xMemErr, void * pUserData)
{
#if defined(UNTRUST)
	if( pBackend == 0 || pMethods == 0){
		return SXERR_EMPTY;
	}
#endif
	if( pMethods->xAlloc == 0 || pMethods->xRealloc == 0 || pMethods->xFree == 0 || pMethods->xChunkSize == 0 ){
		/* mandatory methods are missing */
		return SXERR_INVALID;
	}
	/* Zero the allocator first */
	SyZero(&(*pBackend), sizeof(SyMemBackend));
	pBackend->xMemError = xMemErr;
	pBackend->pUserData = pUserData;
	/* Switch to the host application memory allocator */
	pBackend->pMethods = pMethods;
	if( pBackend->pMethods->xInit ){
		/* Initialize the backend  */
		if( SXRET_OK != pBackend->pMethods->xInit(pBackend->pMethods->pUserData) ){
			return SXERR_ABORT;
		}
	}
#if defined(UNTRUST)
	pBackend->nMagic = SXMEM_BACKEND_MAGIC;
#endif
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyMemBackendInitFromParent(SyMemBackend *pBackend,const SyMemBackend *pParent)
{
#if defined(UNTRUST)
	if( pBackend == 0 || SXMEM_BACKEND_CORRUPT(pParent) ){
		return SXERR_CORRUPT;
	}
#endif
	/* Zero the allocator first */
	SyZero(&(*pBackend), sizeof(SyMemBackend));
	pBackend->pMethods  = pParent->pMethods;
	pBackend->xMemError = pParent->xMemError;
	pBackend->pUserData = pParent->pUserData;
#if defined(UNTRUST)
	pBackend->nMagic = SXMEM_BACKEND_MAGIC;
#endif
	return SXRET_OK;
}
static sxi32 MemBackendRelease(SyMemBackend *pBackend)
{
	SyMemBlock *pBlock, *pNext;

	pBlock = pBackend->pBlocks;
	for(;;){
		if( pBackend->nBlock == 0 ){
			break;
		}
		pNext  = pBlock->pNext;
		pBackend->pMethods->xFree(pBlock);
		pBlock = pNext;
		pBackend->nBlock--;
		/* LOOP ONE */
		if( pBackend->nBlock == 0 ){
			break;
		}
		pNext  = pBlock->pNext;
		pBackend->pMethods->xFree(pBlock);
		pBlock = pNext;
		pBackend->nBlock--;
		/* LOOP TWO */
		if( pBackend->nBlock == 0 ){
			break;
		}
		pNext  = pBlock->pNext;
		pBackend->pMethods->xFree(pBlock);
		pBlock = pNext;
		pBackend->nBlock--;
		/* LOOP THREE */
		if( pBackend->nBlock == 0 ){
			break;
		}
		pNext  = pBlock->pNext;
		pBackend->pMethods->xFree(pBlock);
		pBlock = pNext;
		pBackend->nBlock--;
		/* LOOP FOUR */
	}
	if( pBackend->pMethods->xRelease ){
		pBackend->pMethods->xRelease(pBackend->pMethods->pUserData);
	}
	pBackend->pMethods = 0;
	pBackend->pBlocks  = 0;
#if defined(UNTRUST)
	pBackend->nMagic = 0x2626;
#endif
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyMemBackendRelease(SyMemBackend *pBackend)
{
	sxi32 rc;
#if defined(UNTRUST)
	if( SXMEM_BACKEND_CORRUPT(pBackend) ){
		return SXERR_INVALID;
	}
#endif
	if( pBackend->pMutexMethods ){
		SyMutexEnter(pBackend->pMutexMethods, pBackend->pMutex);
	}
	rc = MemBackendRelease(&(*pBackend));
	if( pBackend->pMutexMethods ){
		SyMutexLeave(pBackend->pMutexMethods, pBackend->pMutex);
		SyMutexRelease(pBackend->pMutexMethods, pBackend->pMutex);
	}
	return rc;
}
UNQLITE_PRIVATE void * SyMemBackendDup(SyMemBackend *pBackend, const void *pSrc, sxu32 nSize)
{
	void *pNew;
#if defined(UNTRUST)
	if( pSrc == 0 || nSize <= 0 ){
		return 0;
	}
#endif
	pNew = SyMemBackendAlloc(&(*pBackend), nSize);
	if( pNew ){
		SyMemcpy(pSrc, pNew, nSize);
	}
	return pNew;
}
UNQLITE_PRIVATE sxi32 SyBlobInitFromBuf(SyBlob *pBlob, void *pBuffer, sxu32 nSize)
{
#if defined(UNTRUST)
	if( pBlob == 0 || pBuffer == 0 || nSize < 1 ){
		return SXERR_EMPTY;
	}
#endif
	pBlob->pBlob = pBuffer;
	pBlob->mByte = nSize;
	pBlob->nByte = 0;
	pBlob->pAllocator = 0;
	pBlob->nFlags = SXBLOB_LOCKED|SXBLOB_STATIC;
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyBlobInit(SyBlob *pBlob, SyMemBackend *pAllocator)
{
#if defined(UNTRUST)
	if( pBlob == 0  ){
		return SXERR_EMPTY;
	}
#endif
	pBlob->pBlob = 0;
	pBlob->mByte = pBlob->nByte	= 0;
	pBlob->pAllocator = &(*pAllocator);
	pBlob->nFlags = 0;
	return SXRET_OK;
}
#ifndef SXBLOB_MIN_GROWTH
#define SXBLOB_MIN_GROWTH 16
#endif
static sxi32 BlobPrepareGrow(SyBlob *pBlob, sxu32 *pByte)
{
	sxu32 nByte;
	void *pNew;
	nByte = *pByte;
	if( pBlob->nFlags & (SXBLOB_LOCKED|SXBLOB_STATIC) ){
		if ( SyBlobFreeSpace(pBlob) < nByte ){
			*pByte = SyBlobFreeSpace(pBlob);
			if( (*pByte) == 0 ){
				return SXERR_SHORT;
			}
		}
		return SXRET_OK;
	}
	if( pBlob->nFlags & SXBLOB_RDONLY ){
		/* Make a copy of the read-only item */
		if( pBlob->nByte > 0 ){
			pNew = SyMemBackendDup(pBlob->pAllocator, pBlob->pBlob, pBlob->nByte);
			if( pNew == 0 ){
				return SXERR_MEM;
			}
			pBlob->pBlob = pNew;
			pBlob->mByte = pBlob->nByte;
		}else{
			pBlob->pBlob = 0;
			pBlob->mByte = 0;
		}
		/* Remove the read-only flag */
		pBlob->nFlags &= ~SXBLOB_RDONLY;
	}
	if( SyBlobFreeSpace(pBlob) >= nByte ){
		return SXRET_OK;
	}
	if( pBlob->mByte > 0 ){
		nByte = nByte + pBlob->mByte * 2 + SXBLOB_MIN_GROWTH;
	}else if ( nByte < SXBLOB_MIN_GROWTH ){
		nByte = SXBLOB_MIN_GROWTH;
	}
	pNew = SyMemBackendRealloc(pBlob->pAllocator, pBlob->pBlob, nByte);
	if( pNew == 0 ){
		return SXERR_MEM;
	}
	pBlob->pBlob = pNew;
	pBlob->mByte = nByte;
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyBlobAppend(SyBlob *pBlob, const void *pData, sxu32 nSize)
{
	sxu8 *zBlob;
	sxi32 rc;
	if( nSize < 1 ){
		return SXRET_OK;
	}
	rc = BlobPrepareGrow(&(*pBlob), &nSize);
	if( SXRET_OK != rc ){
		return rc;
	}
	if( pData ){
		zBlob = (sxu8 *)pBlob->pBlob ;
		zBlob = &zBlob[pBlob->nByte];
		pBlob->nByte += nSize;
		SX_MACRO_FAST_MEMCPY(pData, zBlob, nSize);
	}
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyBlobNullAppend(SyBlob *pBlob)
{
	sxi32 rc;
	sxu32 n;
	n = pBlob->nByte;
	rc = SyBlobAppend(&(*pBlob), (const void *)"\0", sizeof(char));
	if (rc == SXRET_OK ){
		pBlob->nByte = n;
	}
	return rc;
}
UNQLITE_PRIVATE sxi32 SyBlobDup(SyBlob *pSrc, SyBlob *pDest)
{
	sxi32 rc = SXRET_OK;
	if( pSrc->nByte > 0 ){
		rc = SyBlobAppend(&(*pDest), pSrc->pBlob, pSrc->nByte);
	}
	return rc;
}
UNQLITE_PRIVATE sxi32 SyBlobReset(SyBlob *pBlob)
{
	pBlob->nByte = 0;
	if( pBlob->nFlags & SXBLOB_RDONLY ){
		/* Read-only (Not malloced chunk) */
		pBlob->pBlob = 0;
		pBlob->mByte = 0;
		pBlob->nFlags &= ~SXBLOB_RDONLY;
	}
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyBlobRelease(SyBlob *pBlob)
{
	if( (pBlob->nFlags & (SXBLOB_STATIC|SXBLOB_RDONLY)) == 0 && pBlob->mByte > 0 ){
		SyMemBackendFree(pBlob->pAllocator, pBlob->pBlob);
	}
	pBlob->pBlob = 0;
	pBlob->nByte = pBlob->mByte = 0;
	pBlob->nFlags = 0;
	return SXRET_OK;
}
/* SyRunTimeApi:sxds.c */
UNQLITE_PRIVATE sxi32 SySetInit(SySet *pSet, SyMemBackend *pAllocator, sxu32 ElemSize)
{
	pSet->nSize = 0 ;
	pSet->nUsed = 0;
	pSet->nCursor = 0;
	pSet->eSize = ElemSize;
	pSet->pAllocator = pAllocator;
	pSet->pBase =  0;
	pSet->pUserData = 0;
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SySetPut(SySet *pSet, const void *pItem)
{
	unsigned char *zbase;
	if( pSet->nUsed >= pSet->nSize ){
		void *pNew;
		if( pSet->pAllocator == 0 ){
			return  SXERR_LOCKED;
		}
		if( pSet->nSize <= 0 ){
			pSet->nSize = 4;
		}
		pNew = SyMemBackendRealloc(pSet->pAllocator, pSet->pBase, pSet->eSize * pSet->nSize * 2);
		if( pNew == 0 ){
			return SXERR_MEM;
		}
		pSet->pBase = pNew;
		pSet->nSize <<= 1;
	}
	zbase = (unsigned char *)pSet->pBase;
	SX_MACRO_FAST_MEMCPY(pItem, &zbase[pSet->nUsed * pSet->eSize], pSet->eSize);
	pSet->nUsed++;	
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SySetRelease(SySet *pSet)
{
	sxi32 rc = SXRET_OK;
	if( pSet->pAllocator && pSet->pBase ){
		rc = SyMemBackendFree(pSet->pAllocator, pSet->pBase);
	}
	pSet->pBase = 0;
	pSet->nUsed = 0;
	pSet->nCursor = 0;
	return rc;
}
/* SyRunTimeApi: sxfmt.c */
#define SXFMT_BUFSIZ 1024 /* Conversion buffer size */
/*
** Conversion types fall into various categories as defined by the
** following enumeration.
*/
#define SXFMT_RADIX       1 /* Integer types.%d, %x, %o, and so forth */
#define SXFMT_FLOAT       2 /* Floating point.%f */
#define SXFMT_EXP         3 /* Exponentional notation.%e and %E */
#define SXFMT_GENERIC     4 /* Floating or exponential, depending on exponent.%g */
#define SXFMT_SIZE        5 /* Total number of characters processed so far.%n */
#define SXFMT_STRING      6 /* Strings.%s */
#define SXFMT_PERCENT     7 /* Percent symbol.%% */
#define SXFMT_CHARX       8 /* Characters.%c */
#define SXFMT_ERROR       9 /* Used to indicate no such conversion type */
/* Extension by Symisc Systems */
#define SXFMT_RAWSTR     13 /* %z Pointer to raw string (SyString *) */
#define SXFMT_UNUSED     15 
/*
** Allowed values for SyFmtInfo.flags
*/
#define SXFLAG_SIGNED	0x01
#define SXFLAG_UNSIGNED 0x02
/* Allowed values for SyFmtConsumer.nType */
#define SXFMT_CONS_PROC		1	/* Consumer is a procedure */
#define SXFMT_CONS_STR		2	/* Consumer is a managed string */
#define SXFMT_CONS_FILE		5	/* Consumer is an open File */
#define SXFMT_CONS_BLOB		6	/* Consumer is a BLOB */
/*
** Each builtin conversion character (ex: the 'd' in "%d") is described
** by an instance of the following structure
*/
typedef struct SyFmtInfo SyFmtInfo;
struct SyFmtInfo
{
  char fmttype;  /* The format field code letter [i.e: 'd', 's', 'x'] */
  sxu8 base;     /* The base for radix conversion */
  int flags;    /* One or more of SXFLAG_ constants below */
  sxu8 type;     /* Conversion paradigm */
  char *charset; /* The character set for conversion */
  char *prefix;  /* Prefix on non-zero values in alt format */
};
typedef struct SyFmtConsumer SyFmtConsumer;
struct SyFmtConsumer
{
	sxu32 nLen; /* Total output length */
	sxi32 nType; /* Type of the consumer see below */
	sxi32 rc;	/* Consumer return value;Abort processing if rc != SXRET_OK */
 union{
	struct{	
	ProcConsumer xUserConsumer;
	void *pUserData;
	}sFunc;  
	SyBlob *pBlob;
 }uConsumer;	
}; 
#ifndef SX_OMIT_FLOATINGPOINT
static int getdigit(sxlongreal *val, int *cnt)
{
  sxlongreal d;
  int digit;

  if( (*cnt)++ >= 16 ){
	  return '0';
  }
  digit = (int)*val;
  d = digit;
   *val = (*val - d)*10.0;
  return digit + '0' ;
}
#endif /* SX_OMIT_FLOATINGPOINT */
/*
 * The following routine was taken from the SQLITE2 source tree and was
 * extended by Symisc Systems to fit its need.
 * Status: Public Domain
 */
static sxi32 InternFormat(ProcConsumer xConsumer, void *pUserData, const char *zFormat, va_list ap)
{
	/*
	 * The following table is searched linearly, so it is good to put the most frequently
	 * used conversion types first.
	 */
static const SyFmtInfo aFmt[] = {
  {  'd', 10, SXFLAG_SIGNED, SXFMT_RADIX, "0123456789", 0    }, 
  {  's',  0, 0, SXFMT_STRING,     0,                  0    }, 
  {  'c',  0, 0, SXFMT_CHARX,      0,                  0    }, 
  {  'x', 16, 0, SXFMT_RADIX,      "0123456789abcdef", "x0" }, 
  {  'X', 16, 0, SXFMT_RADIX,      "0123456789ABCDEF", "X0" }, 
         /* -- Extensions by Symisc Systems -- */
  {  'z',  0, 0, SXFMT_RAWSTR,     0,                   0   }, /* Pointer to a raw string (SyString *) */
  {  'B',  2, 0, SXFMT_RADIX,      "01",                "b0"}, 
         /* -- End of Extensions -- */
  {  'o',  8, 0, SXFMT_RADIX,      "01234567",         "0"  }, 
  {  'u', 10, 0, SXFMT_RADIX,      "0123456789",       0    }, 
#ifndef SX_OMIT_FLOATINGPOINT
  {  'f',  0, SXFLAG_SIGNED, SXFMT_FLOAT,       0,     0    }, 
  {  'e',  0, SXFLAG_SIGNED, SXFMT_EXP,        "e",    0    }, 
  {  'E',  0, SXFLAG_SIGNED, SXFMT_EXP,        "E",    0    }, 
  {  'g',  0, SXFLAG_SIGNED, SXFMT_GENERIC,    "e",    0    }, 
  {  'G',  0, SXFLAG_SIGNED, SXFMT_GENERIC,    "E",    0    }, 
#endif
  {  'i', 10, SXFLAG_SIGNED, SXFMT_RADIX, "0123456789", 0    }, 
  {  'n',  0, 0, SXFMT_SIZE,       0,                  0    }, 
  {  '%',  0, 0, SXFMT_PERCENT,    0,                  0    }, 
  {  'p', 10, 0, SXFMT_RADIX,      "0123456789",       0    }
};
  int c;                     /* Next character in the format string */
  char *bufpt;               /* Pointer to the conversion buffer */
  int precision;             /* Precision of the current field */
  int length;                /* Length of the field */
  int idx;                   /* A general purpose loop counter */
  int width;                 /* Width of the current field */
  sxu8 flag_leftjustify;   /* True if "-" flag is present */
  sxu8 flag_plussign;      /* True if "+" flag is present */
  sxu8 flag_blanksign;     /* True if " " flag is present */
  sxu8 flag_alternateform; /* True if "#" flag is present */
  sxu8 flag_zeropad;       /* True if field width constant starts with zero */
  sxu8 flag_long;          /* True if "l" flag is present */
  sxi64 longvalue;         /* Value for integer types */
  const SyFmtInfo *infop;  /* Pointer to the appropriate info structure */
  char buf[SXFMT_BUFSIZ];  /* Conversion buffer */
  char prefix;             /* Prefix character."+" or "-" or " " or '\0'.*/
  sxu8 errorflag = 0;      /* True if an error is encountered */
  sxu8 xtype;              /* Conversion paradigm */
  static char spaces[] = "                                                  ";
#define etSPACESIZE ((int)sizeof(spaces)-1)
#ifndef SX_OMIT_FLOATINGPOINT
  sxlongreal realvalue;    /* Value for real types */
  int  exp;                /* exponent of real numbers */
  double rounder;          /* Used for rounding floating point values */
  sxu8 flag_dp;            /* True if decimal point should be shown */
  sxu8 flag_rtz;           /* True if trailing zeros should be removed */
  sxu8 flag_exp;           /* True to force display of the exponent */
  int nsd;                 /* Number of significant digits returned */
#endif
  int rc;

  length = 0;
  bufpt = 0;
  for(; (c=(*zFormat))!=0; ++zFormat){
    if( c!='%' ){
      unsigned int amt;
      bufpt = (char *)zFormat;
      amt = 1;
      while( (c=(*++zFormat))!='%' && c!=0 ) amt++;
	  rc = xConsumer((const void *)bufpt, amt, pUserData);
	  if( rc != SXRET_OK ){
		  return SXERR_ABORT; /* Consumer routine request an operation abort */
	  }
      if( c==0 ){
		  return errorflag > 0 ? SXERR_FORMAT : SXRET_OK;
	  }
    }
    if( (c=(*++zFormat))==0 ){
      errorflag = 1;
	  rc = xConsumer("%", sizeof("%")-1, pUserData);
	  if( rc != SXRET_OK ){
		  return SXERR_ABORT; /* Consumer routine request an operation abort */
	  }
      return errorflag > 0 ? SXERR_FORMAT : SXRET_OK;
    }
    /* Find out what flags are present */
    flag_leftjustify = flag_plussign = flag_blanksign = 
     flag_alternateform = flag_zeropad = 0;
    do{
      switch( c ){
        case '-':   flag_leftjustify = 1;     c = 0;   break;
        case '+':   flag_plussign = 1;        c = 0;   break;
        case ' ':   flag_blanksign = 1;       c = 0;   break;
        case '#':   flag_alternateform = 1;   c = 0;   break;
        case '0':   flag_zeropad = 1;         c = 0;   break;
        default:                                       break;
      }
    }while( c==0 && (c=(*++zFormat))!=0 );
    /* Get the field width */
    width = 0;
    if( c=='*' ){
      width = va_arg(ap, int);
      if( width<0 ){
        flag_leftjustify = 1;
        width = -width;
      }
      c = *++zFormat;
    }else{
      while( c>='0' && c<='9' ){
        width = width*10 + c - '0';
        c = *++zFormat;
      }
    }
    if( width > SXFMT_BUFSIZ-10 ){
      width = SXFMT_BUFSIZ-10;
    }
    /* Get the precision */
	precision = -1;
    if( c=='.' ){
      precision = 0;
      c = *++zFormat;
      if( c=='*' ){
        precision = va_arg(ap, int);
        if( precision<0 ) precision = -precision;
        c = *++zFormat;
      }else{
        while( c>='0' && c<='9' ){
          precision = precision*10 + c - '0';
          c = *++zFormat;
        }
      }
    }
    /* Get the conversion type modifier */
	flag_long = 0;
    if( c=='l' || c == 'q' /* BSD quad (expect a 64-bit integer) */ ){
      flag_long = (c == 'q') ? 2 : 1;
      c = *++zFormat;
	  if( c == 'l' ){
		  /* Standard printf emulation 'lld' (expect a 64bit integer) */
		  flag_long = 2;
	  }
    }
    /* Fetch the info entry for the field */
    infop = 0;
    xtype = SXFMT_ERROR;
	for(idx=0; idx< (int)SX_ARRAYSIZE(aFmt); idx++){
      if( c==aFmt[idx].fmttype ){
        infop = &aFmt[idx];
		xtype = infop->type;
        break;
      }
    }

    /*
    ** At this point, variables are initialized as follows:
    **
    **   flag_alternateform          TRUE if a '#' is present.
    **   flag_plussign               TRUE if a '+' is present.
    **   flag_leftjustify            TRUE if a '-' is present or if the
    **                               field width was negative.
    **   flag_zeropad                TRUE if the width began with 0.
    **   flag_long                   TRUE if the letter 'l' (ell) or 'q'(BSD quad) prefixed
    **                               the conversion character.
    **   flag_blanksign              TRUE if a ' ' is present.
    **   width                       The specified field width.This is
    **                               always non-negative.Zero is the default.
    **   precision                   The specified precision.The default
    **                               is -1.
    **   xtype                       The object of the conversion.
    **   infop                       Pointer to the appropriate info struct.
    */
    switch( xtype ){
      case SXFMT_RADIX:
        if( flag_long > 0 ){
			if( flag_long > 1 ){
				/* BSD quad: expect a 64-bit integer */
				longvalue = va_arg(ap, sxi64);
			}else{
				longvalue = va_arg(ap, sxlong);
			}
		}else{
			if( infop->flags & SXFLAG_SIGNED ){
				longvalue = va_arg(ap, sxi32);
			}else{
				longvalue = va_arg(ap, sxu32);
			}
		}
		/* Limit the precision to prevent overflowing buf[] during conversion */
      if( precision>SXFMT_BUFSIZ-40 ) precision = SXFMT_BUFSIZ-40;
#if 1
        /* For the format %#x, the value zero is printed "0" not "0x0".
        ** I think this is stupid.*/
        if( longvalue==0 ) flag_alternateform = 0;
#else
        /* More sensible: turn off the prefix for octal (to prevent "00"), 
        ** but leave the prefix for hex.*/
        if( longvalue==0 && infop->base==8 ) flag_alternateform = 0;
#endif
        if( infop->flags & SXFLAG_SIGNED ){
          if( longvalue<0 ){ 
            longvalue = -longvalue;
			/* Ticket 1433-003 */
			if( longvalue < 0 ){
				/* Overflow */
				longvalue= 0x7FFFFFFFFFFFFFFF;
			}
            prefix = '-';
          }else if( flag_plussign )  prefix = '+';
          else if( flag_blanksign )  prefix = ' ';
          else                       prefix = 0;
        }else{
			if( longvalue<0 ){
				longvalue = -longvalue;
				/* Ticket 1433-003 */
				if( longvalue < 0 ){
					/* Overflow */
					longvalue= 0x7FFFFFFFFFFFFFFF;
				}
			}
			prefix = 0;
		}
        if( flag_zeropad && precision<width-(prefix!=0) ){
          precision = width-(prefix!=0);
        }
        bufpt = &buf[SXFMT_BUFSIZ-1];
        {
          register char *cset;      /* Use registers for speed */
          register int base;
          cset = infop->charset;
          base = infop->base;
          do{                                           /* Convert to ascii */
            *(--bufpt) = cset[longvalue%base];
            longvalue = longvalue/base;
          }while( longvalue>0 );
        }
        length = &buf[SXFMT_BUFSIZ-1]-bufpt;
        for(idx=precision-length; idx>0; idx--){
          *(--bufpt) = '0';                             /* Zero pad */
        }
        if( prefix ) *(--bufpt) = prefix;               /* Add sign */
        if( flag_alternateform && infop->prefix ){      /* Add "0" or "0x" */
          char *pre, x;
          pre = infop->prefix;
          if( *bufpt!=pre[0] ){
            for(pre=infop->prefix; (x=(*pre))!=0; pre++) *(--bufpt) = x;
          }
        }
        length = &buf[SXFMT_BUFSIZ-1]-bufpt;
        break;
      case SXFMT_FLOAT:
      case SXFMT_EXP:
      case SXFMT_GENERIC:
#ifndef SX_OMIT_FLOATINGPOINT
		realvalue = va_arg(ap, double);
        if( precision<0 ) precision = 6;         /* Set default precision */
        if( precision>SXFMT_BUFSIZ-40) precision = SXFMT_BUFSIZ-40;
        if( realvalue<0.0 ){
          realvalue = -realvalue;
          prefix = '-';
        }else{
          if( flag_plussign )          prefix = '+';
          else if( flag_blanksign )    prefix = ' ';
          else                         prefix = 0;
        }
        if( infop->type==SXFMT_GENERIC && precision>0 ) precision--;
        rounder = 0.0;
#if 0
        /* Rounding works like BSD when the constant 0.4999 is used.Wierd! */
        for(idx=precision, rounder=0.4999; idx>0; idx--, rounder*=0.1);
#else
        /* It makes more sense to use 0.5 */
        for(idx=precision, rounder=0.5; idx>0; idx--, rounder*=0.1);
#endif
        if( infop->type==SXFMT_FLOAT ) realvalue += rounder;
        /* Normalize realvalue to within 10.0 > realvalue >= 1.0 */
        exp = 0;
        if( realvalue>0.0 ){
          while( realvalue>=1e8 && exp<=350 ){ realvalue *= 1e-8; exp+=8; }
          while( realvalue>=10.0 && exp<=350 ){ realvalue *= 0.1; exp++; }
          while( realvalue<1e-8 && exp>=-350 ){ realvalue *= 1e8; exp-=8; }
          while( realvalue<1.0 && exp>=-350 ){ realvalue *= 10.0; exp--; }
          if( exp>350 || exp<-350 ){
            bufpt = "NaN";
            length = 3;
            break;
          }
        }
        bufpt = buf;
        /*
        ** If the field type is etGENERIC, then convert to either etEXP
        ** or etFLOAT, as appropriate.
        */
        flag_exp = xtype==SXFMT_EXP;
        if( xtype!=SXFMT_FLOAT ){
          realvalue += rounder;
          if( realvalue>=10.0 ){ realvalue *= 0.1; exp++; }
        }
        if( xtype==SXFMT_GENERIC ){
          flag_rtz = !flag_alternateform;
          if( exp<-4 || exp>precision ){
            xtype = SXFMT_EXP;
          }else{
            precision = precision - exp;
            xtype = SXFMT_FLOAT;
          }
        }else{
          flag_rtz = 0;
        }
        /*
        ** The "exp+precision" test causes output to be of type etEXP if
        ** the precision is too large to fit in buf[].
        */
        nsd = 0;
        if( xtype==SXFMT_FLOAT && exp+precision<SXFMT_BUFSIZ-30 ){
          flag_dp = (precision>0 || flag_alternateform);
          if( prefix ) *(bufpt++) = prefix;         /* Sign */
          if( exp<0 )  *(bufpt++) = '0';            /* Digits before "." */
          else for(; exp>=0; exp--) *(bufpt++) = (char)getdigit(&realvalue, &nsd);
          if( flag_dp ) *(bufpt++) = '.';           /* The decimal point */
          for(exp++; exp<0 && precision>0; precision--, exp++){
            *(bufpt++) = '0';
          }
          while( (precision--)>0 ) *(bufpt++) = (char)getdigit(&realvalue, &nsd);
          *(bufpt--) = 0;                           /* Null terminate */
          if( flag_rtz && flag_dp ){     /* Remove trailing zeros and "." */
            while( bufpt>=buf && *bufpt=='0' ) *(bufpt--) = 0;
            if( bufpt>=buf && *bufpt=='.' ) *(bufpt--) = 0;
          }
          bufpt++;                            /* point to next free slot */
        }else{    /* etEXP or etGENERIC */
          flag_dp = (precision>0 || flag_alternateform);
          if( prefix ) *(bufpt++) = prefix;   /* Sign */
          *(bufpt++) = (char)getdigit(&realvalue, &nsd);  /* First digit */
          if( flag_dp ) *(bufpt++) = '.';     /* Decimal point */
          while( (precision--)>0 ) *(bufpt++) = (char)getdigit(&realvalue, &nsd);
          bufpt--;                            /* point to last digit */
          if( flag_rtz && flag_dp ){          /* Remove tail zeros */
            while( bufpt>=buf && *bufpt=='0' ) *(bufpt--) = 0;
            if( bufpt>=buf && *bufpt=='.' ) *(bufpt--) = 0;
          }
          bufpt++;                            /* point to next free slot */
          if( exp || flag_exp ){
            *(bufpt++) = infop->charset[0];
            if( exp<0 ){ *(bufpt++) = '-'; exp = -exp; } /* sign of exp */
            else       { *(bufpt++) = '+'; }
            if( exp>=100 ){
              *(bufpt++) = (char)((exp/100)+'0');                /* 100's digit */
              exp %= 100;
            }
            *(bufpt++) = (char)(exp/10+'0');                     /* 10's digit */
            *(bufpt++) = (char)(exp%10+'0');                     /* 1's digit */
          }
        }
        /* The converted number is in buf[] and zero terminated.Output it.
        ** Note that the number is in the usual order, not reversed as with
        ** integer conversions.*/
        length = bufpt-buf;
        bufpt = buf;

        /* Special case:  Add leading zeros if the flag_zeropad flag is
        ** set and we are not left justified */
        if( flag_zeropad && !flag_leftjustify && length < width){
          int i;
          int nPad = width - length;
          for(i=width; i>=nPad; i--){
            bufpt[i] = bufpt[i-nPad];
          }
          i = prefix!=0;
          while( nPad-- ) bufpt[i++] = '0';
          length = width;
        }
#else
         bufpt = " ";
		 length = (int)sizeof(" ") - 1;
#endif /* SX_OMIT_FLOATINGPOINT */
        break;
      case SXFMT_SIZE:{
		 int *pSize = va_arg(ap, int *);
		 *pSize = ((SyFmtConsumer *)pUserData)->nLen;
		 length = width = 0;
					  }
        break;
      case SXFMT_PERCENT:
        buf[0] = '%';
        bufpt = buf;
        length = 1;
        break;
      case SXFMT_CHARX:
        c = va_arg(ap, int);
		buf[0] = (char)c;
		/* Limit the precision to prevent overflowing buf[] during conversion */
		if( precision>SXFMT_BUFSIZ-40 ) precision = SXFMT_BUFSIZ-40;
        if( precision>=0 ){
          for(idx=1; idx<precision; idx++) buf[idx] = (char)c;
          length = precision;
        }else{
          length =1;
        }
        bufpt = buf;
        break;
      case SXFMT_STRING:
        bufpt = va_arg(ap, char*);
        if( bufpt==0 ){
          bufpt = " ";
		  length = (int)sizeof(" ")-1;
		  break;
        }
		length = precision;
		if( precision < 0 ){
			/* Symisc extension */
			length = (int)SyStrlen(bufpt);
		}
        if( precision>=0 && precision<length ) length = precision;
        break;
	case SXFMT_RAWSTR:{
		/* Symisc extension */
		SyString *pStr = va_arg(ap, SyString *);
		if( pStr == 0 || pStr->zString == 0 ){
			 bufpt = " ";
		     length = (int)sizeof(char);
		     break;
		}
		bufpt = (char *)pStr->zString;
		length = (int)pStr->nByte;
		break;
					  }
      case SXFMT_ERROR:
        buf[0] = '?';
        bufpt = buf;
		length = (int)sizeof(char);
        if( c==0 ) zFormat--;
        break;
    }/* End switch over the format type */
    /*
    ** The text of the conversion is pointed to by "bufpt" and is
    ** "length" characters long.The field width is "width".Do
    ** the output.
    */
    if( !flag_leftjustify ){
      register int nspace;
      nspace = width-length;
      if( nspace>0 ){
        while( nspace>=etSPACESIZE ){
			rc = xConsumer(spaces, etSPACESIZE, pUserData);
			if( rc != SXRET_OK ){
				return SXERR_ABORT; /* Consumer routine request an operation abort */
			}
			nspace -= etSPACESIZE;
        }
        if( nspace>0 ){
			rc = xConsumer(spaces, (unsigned int)nspace, pUserData);
			if( rc != SXRET_OK ){
				return SXERR_ABORT; /* Consumer routine request an operation abort */
			}
		}
      }
    }
    if( length>0 ){
		rc = xConsumer(bufpt, (unsigned int)length, pUserData);
		if( rc != SXRET_OK ){
		  return SXERR_ABORT; /* Consumer routine request an operation abort */
		}
    }
    if( flag_leftjustify ){
      register int nspace;
      nspace = width-length;
      if( nspace>0 ){
        while( nspace>=etSPACESIZE ){
			rc = xConsumer(spaces, etSPACESIZE, pUserData);
			if( rc != SXRET_OK ){
				return SXERR_ABORT; /* Consumer routine request an operation abort */
			}
			nspace -= etSPACESIZE;
        }
        if( nspace>0 ){
			rc = xConsumer(spaces, (unsigned int)nspace, pUserData);
			if( rc != SXRET_OK ){
				return SXERR_ABORT; /* Consumer routine request an operation abort */
			}
		}
      }
    }
  }/* End for loop over the format string */
  return errorflag ? SXERR_FORMAT : SXRET_OK;
} 
static sxi32 FormatConsumer(const void *pSrc, unsigned int nLen, void *pData)
{
	SyFmtConsumer *pConsumer = (SyFmtConsumer *)pData;
	sxi32 rc = SXERR_ABORT;
	switch(pConsumer->nType){
	case SXFMT_CONS_PROC:
			/* User callback */
			rc = pConsumer->uConsumer.sFunc.xUserConsumer(pSrc, nLen, pConsumer->uConsumer.sFunc.pUserData);
			break;
	case SXFMT_CONS_BLOB:
			/* Blob consumer */
			rc = SyBlobAppend(pConsumer->uConsumer.pBlob, pSrc, (sxu32)nLen);
			break;
		default: 
			/* Unknown consumer */
			break;
	}
	/* Update total number of bytes consumed so far */
	pConsumer->nLen += nLen;
	pConsumer->rc = rc;
	return rc;	
}
static sxi32 FormatMount(sxi32 nType, void *pConsumer, ProcConsumer xUserCons, void *pUserData, sxu32 *pOutLen, const char *zFormat, va_list ap)
{
	SyFmtConsumer sCons;
	sCons.nType = nType;
	sCons.rc = SXRET_OK;
	sCons.nLen = 0;
	if( pOutLen ){
		*pOutLen = 0;
	}
	switch(nType){
	case SXFMT_CONS_PROC:
#if defined(UNTRUST)
			if( xUserCons == 0 ){
				return SXERR_EMPTY;
			}
#endif
			sCons.uConsumer.sFunc.xUserConsumer = xUserCons;
			sCons.uConsumer.sFunc.pUserData	    = pUserData;
		break;
		case SXFMT_CONS_BLOB:
			sCons.uConsumer.pBlob = (SyBlob *)pConsumer;
			break;
		default: 
			return SXERR_UNKNOWN;
	}
	InternFormat(FormatConsumer, &sCons, zFormat, ap); 
	if( pOutLen ){
		*pOutLen = sCons.nLen;
	}
	return sCons.rc;
}
UNQLITE_PRIVATE sxu32 SyBlobFormatAp(SyBlob *pBlob, const char *zFormat, va_list ap)
{
	sxu32 n = 0; /* cc warning */
#if defined(UNTRUST)	
	if( SX_EMPTY_STR(zFormat) ){
		return 0;
	}
#endif	
	FormatMount(SXFMT_CONS_BLOB, &(*pBlob), 0, 0, &n, zFormat, ap);
	return n;
}
UNQLITE_PRIVATE sxu32 SyBufferFormat(char *zBuf, sxu32 nLen, const char *zFormat, ...)
{
	SyBlob sBlob;
	va_list ap;
	sxu32 n;
#if defined(UNTRUST)	
	if( SX_EMPTY_STR(zFormat) ){
		return 0;
	}
#endif	
	if( SXRET_OK != SyBlobInitFromBuf(&sBlob, zBuf, nLen - 1) ){
		return 0;
	}		
	va_start(ap, zFormat);
	FormatMount(SXFMT_CONS_BLOB, &sBlob, 0, 0, 0, zFormat, ap);
	va_end(ap);
	n = SyBlobLength(&sBlob);
	/* Append the null terminator */
	sBlob.mByte++;
	SyBlobAppend(&sBlob, "\0", sizeof(char));
	return n;
}
/*
 * Psuedo Random Number Generator (PRNG)
 * @authors: SQLite authors <http://www.sqlite.org/>
 * @status: Public Domain
 * NOTE:
 *  Nothing in this file or anywhere else in the library does any kind of
 *  encryption.The RC4 algorithm is being used as a PRNG (pseudo-random
 *  number generator) not as an encryption device.
 */
#define SXPRNG_MAGIC	0x13C4
#ifdef __UNIXES__
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <sys/time.h>
#endif
static sxi32 SyOSUtilRandomSeed(void *pBuf, sxu32 nLen, void *pUnused)
{
	char *zBuf = (char *)pBuf;
#ifdef __WINNT__
	DWORD nProcessID; /* Yes, keep it uninitialized when compiling using the MinGW32 builds tools */
#elif defined(__UNIXES__)
	pid_t pid;
	int fd;
#else
	char zGarbage[128]; /* Yes, keep this buffer uninitialized */
#endif
	SXUNUSED(pUnused);
#ifdef __WINNT__
#ifndef __MINGW32__
	nProcessID = GetProcessId(GetCurrentProcess());
#endif
	SyMemcpy((const void *)&nProcessID, zBuf, SXMIN(nLen, sizeof(DWORD)));
	if( (sxu32)(&zBuf[nLen] - &zBuf[sizeof(DWORD)]) >= sizeof(SYSTEMTIME)  ){
		GetSystemTime((LPSYSTEMTIME)&zBuf[sizeof(DWORD)]);
	}
#elif defined(__UNIXES__)
	fd = open("/dev/urandom", O_RDONLY);
	if (fd >= 0 ){
		if( read(fd, zBuf, nLen) > 0 ){
			close(fd);
			return SXRET_OK;
		}
		/* FALL THRU */
		close(fd);
	}
	pid = getpid();
	SyMemcpy((const void *)&pid, zBuf, SXMIN(nLen, sizeof(pid_t)));
	if( &zBuf[nLen] - &zBuf[sizeof(pid_t)] >= (int)sizeof(struct timeval)  ){
		gettimeofday((struct timeval *)&zBuf[sizeof(pid_t)], 0);
	}
#else
	/* Fill with uninitialized data */
	SyMemcpy(zGarbage, zBuf, SXMIN(nLen, sizeof(zGarbage)));
#endif
	return SXRET_OK;
}
UNQLITE_PRIVATE sxi32 SyRandomnessInit(SyPRNGCtx *pCtx, ProcRandomSeed xSeed, void * pUserData)
{
	char zSeed[256];
	sxu8 t;
	sxi32 rc;
	sxu32 i;
	if( pCtx->nMagic == SXPRNG_MAGIC ){
		return SXRET_OK; /* Already initialized */
	}
 /* Initialize the state of the random number generator once, 
  ** the first time this routine is called.The seed value does
  ** not need to contain a lot of randomness since we are not
  ** trying to do secure encryption or anything like that...
  */	
	if( xSeed == 0 ){
		xSeed = SyOSUtilRandomSeed;
	}
	rc = xSeed(zSeed, sizeof(zSeed), pUserData);
	if( rc != SXRET_OK ){
		return rc;
	}
	pCtx->i = pCtx->j = 0;
	for(i=0; i < SX_ARRAYSIZE(pCtx->s) ; i++){
		pCtx->s[i] = (unsigned char)i;
    }
    for(i=0; i < sizeof(zSeed) ; i++){
      pCtx->j += pCtx->s[i] + zSeed[i];
      t = pCtx->s[pCtx->j];
      pCtx->s[pCtx->j] = pCtx->s[i];
      pCtx->s[i] = t;
    }
	pCtx->nMagic = SXPRNG_MAGIC;
	
	return SXRET_OK;
}
/*
 * Get a single 8-bit random value using the RC4 PRNG.
 */
static sxu8 randomByte(SyPRNGCtx *pCtx)
{
  sxu8 t;
  
  /* Generate and return single random byte */
  pCtx->i++;
  t = pCtx->s[pCtx->i];
  pCtx->j += t;
  pCtx->s[pCtx->i] = pCtx->s[pCtx->j];
  pCtx->s[pCtx->j] = t;
  t += pCtx->s[pCtx->i];
  return pCtx->s[t];
}
UNQLITE_PRIVATE sxi32 SyRandomness(SyPRNGCtx *pCtx, void *pBuf, sxu32 nLen)
{
	unsigned char *zBuf = (unsigned char *)pBuf;
	unsigned char *zEnd = &zBuf[nLen];
#if defined(UNTRUST)
	if( pCtx == 0 || pBuf == 0 || nLen <= 0 ){
		return SXERR_EMPTY;
	}
#endif
	if(pCtx->nMagic != SXPRNG_MAGIC ){
		return SXERR_CORRUPT;
	}
	for(;;){
		if( zBuf >= zEnd ){break;}	zBuf[0] = randomByte(pCtx);	zBuf++;	
		if( zBuf >= zEnd ){break;}	zBuf[0] = randomByte(pCtx);	zBuf++;	
		if( zBuf >= zEnd ){break;}	zBuf[0] = randomByte(pCtx);	zBuf++;	
		if( zBuf >= zEnd ){break;}	zBuf[0] = randomByte(pCtx);	zBuf++;	
	}
	return SXRET_OK;  
}
UNQLITE_PRIVATE void SyBigEndianPack32(unsigned char *buf,sxu32 nb)
{
	buf[3] = nb & 0xFF ; nb >>=8;
	buf[2] = nb & 0xFF ; nb >>=8;
	buf[1] = nb & 0xFF ; nb >>=8;
	buf[0] = (unsigned char)nb ;
}
UNQLITE_PRIVATE void SyBigEndianUnpack32(const unsigned char *buf,sxu32 *uNB)
{
	*uNB = buf[3] + (buf[2] << 8) + (buf[1] << 16) + (buf[0] << 24);
}
UNQLITE_PRIVATE void SyBigEndianPack16(unsigned char *buf,sxu16 nb)
{
	buf[1] = nb & 0xFF ; nb >>=8;
	buf[0] = (unsigned char)nb ;
}
UNQLITE_PRIVATE void SyBigEndianUnpack16(const unsigned char *buf,sxu16 *uNB)
{
	*uNB = buf[1] + (buf[0] << 8);
}
UNQLITE_PRIVATE void SyBigEndianPack64(unsigned char *buf,sxu64 n64)
{
	buf[7] = n64 & 0xFF; n64 >>=8;
	buf[6] = n64 & 0xFF; n64 >>=8;
	buf[5] = n64 & 0xFF; n64 >>=8;
	buf[4] = n64 & 0xFF; n64 >>=8;
	buf[3] = n64 & 0xFF; n64 >>=8;
	buf[2] = n64 & 0xFF; n64 >>=8;
	buf[1] = n64 & 0xFF; n64 >>=8;
	buf[0] = (sxu8)n64 ; 
}
UNQLITE_PRIVATE void SyBigEndianUnpack64(const unsigned char *buf,sxu64 *n64)
{
	sxu32 u1,u2;
	u1 = buf[7] + (buf[6] << 8) + (buf[5] << 16) + (buf[4] << 24);
	u2 = buf[3] + (buf[2] << 8) + (buf[1] << 16) + (buf[0] << 24);
	*n64 = (((sxu64)u2) << 32) | u1;
}
UNQLITE_PRIVATE void SyTimeFormatToDos(Sytm *pFmt,sxu32 *pOut)
{
	sxi32 nDate,nTime;
	nDate = ((pFmt->tm_year - 1980) << 9) + (pFmt->tm_mon << 5) + pFmt->tm_mday;
	nTime = (pFmt->tm_hour << 11) + (pFmt->tm_min << 5)+ (pFmt->tm_sec >> 1);
	*pOut = (nDate << 16) | nTime;
}
UNQLITE_PRIVATE void SyDosTimeFormat(sxu32 nDosDate, Sytm *pOut)
{
	sxu16 nDate;
	sxu16 nTime;
	nDate = nDosDate >> 16;
	nTime = nDosDate & 0xFFFF;
	pOut->tm_isdst  = 0;
	pOut->tm_year 	= 1980 + (nDate >> 9);
	pOut->tm_mon	= (nDate % (1<<9))>>5;
	pOut->tm_mday	= (nDate % (1<<9))&0x1F;
	pOut->tm_hour	= nTime >> 11;
	pOut->tm_min	= (nTime % (1<<11)) >> 5;
	pOut->tm_sec	= ((nTime % (1<<11))& 0x1F )<<1;
}
/*
 * ----------------------------------------------------------
 * File: lhash_kv.c
 * ID: 581b07ce2984fd95740677285d8a11d3
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: lhash_kv.c v1.7 Solaris 2013-01-14 12:56 stable <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* 
 * This file implements disk based hashtable using the linear hashing algorithm.
 * This implementation is the one decribed in the paper:
 *  LINEAR HASHING : A NEW TOOL FOR FILE AND TABLE ADDRESSING. Witold Litwin. I. N. Ft. I. A.. 78 150 Le Chesnay, France.
 * Plus a smart extension called Virtual Bucket Table. (contact devel@symisc.net for additional information).
 */
/* Magic number identifying a valid storage image */
#define L_HASH_MAGIC 0xFA782DCB
/*
 * Magic word to hash to identify a valid hash function.
 */
#define L_HASH_WORD "chm@symisc"
/*
 * Cell size on disk. 
 */
#define L_HASH_CELL_SZ (4/*Hash*/+4/*Key*/+8/*Data*/+2/* Offset of the next cell */+8/*Overflow*/)
/*
 * Primary page (not overflow pages) header size on disk.
 */
#define L_HASH_PAGE_HDR_SZ (2/* Cell offset*/+2/* Free block offset*/+8/*Slave page number*/)
/*
 * The maximum amount of payload (in bytes) that can be stored locally for
 * a database entry.  If the entry contains more data than this, the
 * extra goes onto overflow pages.
*/
#define L_HASH_MX_PAYLOAD(PageSize)  (PageSize-(L_HASH_PAGE_HDR_SZ+L_HASH_CELL_SZ))
/*
 * Maxium free space on a single page.
 */
#define L_HASH_MX_FREE_SPACE(PageSize) (PageSize - (L_HASH_PAGE_HDR_SZ))
/*
** The maximum number of bytes of payload allowed on a single overflow page.
*/
#define L_HASH_OVERFLOW_SIZE(PageSize) (PageSize-8)
/* Forward declaration */
typedef struct lhash_kv_engine lhash_kv_engine;
typedef struct lhpage lhpage;
/*
 * Each record in the database is identified either in-memory or in
 * disk by an instance of the following structure.
 */
typedef struct lhcell lhcell;
struct lhcell
{
	/* Disk-data (Big-Endian) */
	sxu32 nHash;   /* Hash of the key: 4 bytes */
	sxu32 nKey;    /* Key length: 4 bytes */
	sxu64 nData;   /* Data length: 8 bytes */
	sxu16 iNext;   /* Offset of the next cell: 2 bytes */
	pgno iOvfl;    /* Overflow page number if any: 8 bytes */
	/* In-memory data only */
	lhpage *pPage;     /* Page this cell belongs */
	sxu16 iStart;      /* Offset of this cell */
	pgno iDataPage;    /* Data page number when overflow */
	sxu16 iDataOfft;   /* Offset of the data in iDataPage */
	SyBlob sKey;       /* Record key for fast lookup (Kept in-memory if < 256KB ) */
	lhcell *pNext,*pPrev;         /* Linked list of the loaded memory cells */
	lhcell *pNextCol,*pPrevCol;   /* Collison chain  */
};
/*
** Each database page has a header that is an instance of this
** structure.
*/
typedef struct lhphdr lhphdr;
struct lhphdr 
{
  sxu16 iOfft; /* Offset of the first cell */
  sxu16 iFree; /* Offset of the first free block*/
  pgno iSlave; /* Slave page number */
};
/*
 * Each loaded primary disk page is represented in-memory using
 * an instance of the following structure.
 */
struct lhpage
{
	lhash_kv_engine *pHash;  /* KV Storage engine that own this page */
	unqlite_page *pRaw;      /* Raw page contents */
	lhphdr sHdr;             /* Processed page header */
	lhcell **apCell;         /* Cell buckets */
	lhcell *pList,*pFirst;   /* Linked list of cells */
	sxu32 nCell;             /* Total number of cells */
	sxu32 nCellSize;         /* apCell[] size */
	lhpage *pMaster;         /* Master page in case we are dealing with a slave page */
	lhpage *pSlave;          /* List of slave pages */
	lhpage *pNextSlave;      /* Next slave page on the list */
	sxi32 iSlave;            /* Total number of slave pages */
	sxu16 nFree;             /* Amount of free space available in the page */
};
/*
 * A Bucket map record which is used to map logical bucket number to real
 * bucket number is represented by an instance of the following structure.
 */
typedef struct lhash_bmap_rec lhash_bmap_rec;
struct lhash_bmap_rec
{
	pgno iLogic;                   /* Logical bucket number */
	pgno iReal;                    /* Real bucket number */
	lhash_bmap_rec *pNext,*pPrev;  /* Link to other bucket map */     
	lhash_bmap_rec *pNextCol,*pPrevCol; /* Collision links */
};
typedef struct lhash_bmap_page lhash_bmap_page;
struct lhash_bmap_page
{
	pgno iNum;   /* Page number where this entry is stored */
	sxu16 iPtr;  /* Offset to start reading/writing from */
	sxu32 nRec;  /* Total number of records in this page */
	pgno iNext;  /* Next map page */
};
/*
 * An in memory linear hash implemenation is represented by in an isntance
 * of the following structure.
 */
struct lhash_kv_engine
{
	const unqlite_kv_io *pIo;     /* IO methods: Must be first */
	/* Private fields */
	SyMemBackend sAllocator;      /* Private memory backend */
	ProcHash xHash;               /* Default hash function */
	ProcCmp xCmp;                 /* Default comparison function */
	unqlite_page *pHeader;        /* Page one to identify a valid implementation */
	lhash_bmap_rec **apMap;       /* Buckets map records */
	sxu32 nBuckRec;               /* Total number of bucket map records */
	sxu32 nBuckSize;              /* apMap[] size  */
	lhash_bmap_rec *pList;        /* List of bucket map records */
	lhash_bmap_rec *pFirst;       /* First record*/
	lhash_bmap_page sPageMap;     /* Primary bucket map */
	int iPageSize;                /* Page size */
	pgno nFreeList;               /* List of free pages */
	pgno split_bucket;            /* Current split bucket: MUST BE A POWER OF TWO */
	pgno max_split_bucket;        /* Maximum split bucket: MUST BE A POWER OF TWO */
	pgno nmax_split_nucket;       /* Next maximum split bucket (1 << nMsb): In-memory only */
	sxu32 nMagic;                 /* Magic number to identify a valid linear hash disk database */
};
/*
 * Given a logical bucket number, return the record associated with it.
 */
static lhash_bmap_rec * lhMapFindBucket(lhash_kv_engine *pEngine,pgno iLogic)
{
	lhash_bmap_rec *pRec;
	if( pEngine->nBuckRec < 1 ){
		/* Don't bother */
		return 0;
	}
	pRec = pEngine->apMap[iLogic & (pEngine->nBuckSize - 1)];
	for(;;){
		if( pRec == 0 ){
			break;
		}
		if( pRec->iLogic == iLogic ){
			return pRec;
		}
		/* Point to the next entry */
		pRec = pRec->pNextCol;
	}
	/* No such record */
	return 0;
}
/*
 * Install a new bucket map record.
 */
static int lhMapInstallBucket(lhash_kv_engine *pEngine,pgno iLogic,pgno iReal)
{
	lhash_bmap_rec *pRec;
	sxu32 iBucket;
	/* Allocate a new instance */
	pRec = (lhash_bmap_rec *)SyMemBackendPoolAlloc(&pEngine->sAllocator,sizeof(lhash_bmap_rec));
	if( pRec == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pRec,sizeof(lhash_bmap_rec));
	/* Fill in the structure */
	pRec->iLogic = iLogic;
	pRec->iReal = iReal;
	iBucket = iLogic & (pEngine->nBuckSize - 1);
	pRec->pNextCol = pEngine->apMap[iBucket];
	if( pEngine->apMap[iBucket] ){
		pEngine->apMap[iBucket]->pPrevCol = pRec;
	}
	pEngine->apMap[iBucket] = pRec;
	/* Link */
	if( pEngine->pFirst == 0 ){
		pEngine->pFirst = pEngine->pList = pRec;
	}else{
		MACRO_LD_PUSH(pEngine->pList,pRec);
	}
	pEngine->nBuckRec++;
	if( (pEngine->nBuckRec >= pEngine->nBuckSize * 3) && pEngine->nBuckRec < 100000 ){
		/* Allocate a new larger table */
		sxu32 nNewSize = pEngine->nBuckSize << 1;
		lhash_bmap_rec *pEntry;
		lhash_bmap_rec **apNew;
		sxu32 n;
		
		apNew = (lhash_bmap_rec **)SyMemBackendAlloc(&pEngine->sAllocator, nNewSize * sizeof(lhash_bmap_rec *));
		if( apNew ){
			/* Zero the new table */
			SyZero((void *)apNew, nNewSize * sizeof(lhash_bmap_rec *));
			/* Rehash all entries */
			n = 0;
			pEntry = pEngine->pList;
			for(;;){
				/* Loop one */
				if( n >= pEngine->nBuckRec ){
					break;
				}
				pEntry->pNextCol = pEntry->pPrevCol = 0;
				/* Install in the new bucket */
				iBucket = pEntry->iLogic & (nNewSize - 1);
				pEntry->pNextCol = apNew[iBucket];
				if( apNew[iBucket] ){
					apNew[iBucket]->pPrevCol = pEntry;
				}
				apNew[iBucket] = pEntry;
				/* Point to the next entry */
				pEntry = pEntry->pNext;
				n++;
			}
			/* Release the old table and reflect the change */
			SyMemBackendFree(&pEngine->sAllocator,(void *)pEngine->apMap);
			pEngine->apMap = apNew;
			pEngine->nBuckSize  = nNewSize;
		}
	}
	return UNQLITE_OK;
}
/*
 * Process a raw bucket map record.
 */
static int lhMapLoadPage(lhash_kv_engine *pEngine,lhash_bmap_page *pMap,const unsigned char *zRaw)
{
	const unsigned char *zEnd = &zRaw[pEngine->iPageSize];
	const unsigned char *zPtr = zRaw;
	pgno iLogic,iReal;
	sxu32 n;
	int rc;
	if( pMap->iPtr == 0 ){
		/* Read the map header */
		SyBigEndianUnpack64(zRaw,&pMap->iNext);
		zRaw += 8;
		SyBigEndianUnpack32(zRaw,&pMap->nRec);
		zRaw += 4;
	}else{
		/* Mostly page one of the database */
		zRaw += pMap->iPtr;
	}
	/* Start processing */
	for( n = 0; n < pMap->nRec ; ++n ){
		if( zRaw >= zEnd ){
			break;
		}
		/* Extract the logical and real bucket number */
		SyBigEndianUnpack64(zRaw,&iLogic);
		zRaw += 8;
		SyBigEndianUnpack64(zRaw,&iReal);
		zRaw += 8;
		/* Install the record in the map */
		rc = lhMapInstallBucket(pEngine,iLogic,iReal);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	pMap->iPtr = (sxu16)(zRaw-zPtr);
	/* All done */
	return UNQLITE_OK;
}
/* 
 * Allocate a new cell instance.
 */
static lhcell * lhNewCell(lhash_kv_engine *pEngine,lhpage *pPage)
{
	lhcell *pCell;
	pCell = (lhcell *)SyMemBackendPoolAlloc(&pEngine->sAllocator,sizeof(lhcell));
	if( pCell == 0 ){
		return 0;
	}
	/* Zero the structure */
	SyZero(pCell,sizeof(lhcell));
	/* Fill in the structure */
	SyBlobInit(&pCell->sKey,&pEngine->sAllocator);
	pCell->pPage = pPage;
	return pCell;
}
/*
 * Discard a cell from the page table.
 */
static void lhCellDiscard(lhcell *pCell)
{
	lhpage *pPage = pCell->pPage->pMaster;	
	
	if( pCell->pPrevCol ){
		pCell->pPrevCol->pNextCol = pCell->pNextCol;
	}else{
		pPage->apCell[pCell->nHash & (pPage->nCellSize - 1)] = pCell->pNextCol;
	}
	if( pCell->pNextCol ){
		pCell->pNextCol->pPrevCol = pCell->pPrevCol;
	}
	MACRO_LD_REMOVE(pPage->pList,pCell);
	if( pCell == pPage->pFirst ){
		pPage->pFirst = pCell->pPrev;
	}
	pPage->nCell--;
	/* Release the cell */
	SyBlobRelease(&pCell->sKey);
	SyMemBackendPoolFree(&pPage->pHash->sAllocator,pCell);
}
/*
 * Install a cell in the page table.
 */
static int lhInstallCell(lhcell *pCell)
{
	lhpage *pPage = pCell->pPage->pMaster;
	sxu32 iBucket;
	if( pPage->nCell < 1 ){
		sxu32 nTableSize = 32; /* Must be a power of two */
		lhcell **apTable;
		/* Allocate a new cell table */
		apTable = (lhcell **)SyMemBackendAlloc(&pPage->pHash->sAllocator, nTableSize * sizeof(lhcell *));
		if( apTable == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Zero the new table */
		SyZero((void *)apTable, nTableSize * sizeof(lhcell *));
		/* Install it */
		pPage->apCell = apTable;
		pPage->nCellSize = nTableSize;
	}
	iBucket = pCell->nHash & (pPage->nCellSize - 1);
	pCell->pNextCol = pPage->apCell[iBucket];
	if( pPage->apCell[iBucket] ){
		pPage->apCell[iBucket]->pPrevCol = pCell;
	}
	pPage->apCell[iBucket] = pCell;
	if( pPage->pFirst == 0 ){
		pPage->pFirst = pPage->pList = pCell;
	}else{
		MACRO_LD_PUSH(pPage->pList,pCell);
	}
	pPage->nCell++;
	if( (pPage->nCell >= pPage->nCellSize * 3) && pPage->nCell < 100000 ){
		/* Allocate a new larger table */
		sxu32 nNewSize = pPage->nCellSize << 1;
		lhcell *pEntry;
		lhcell **apNew;
		sxu32 n;
		
		apNew = (lhcell **)SyMemBackendAlloc(&pPage->pHash->sAllocator, nNewSize * sizeof(lhcell *));
		if( apNew ){
			/* Zero the new table */
			SyZero((void *)apNew, nNewSize * sizeof(lhcell *));
			/* Rehash all entries */
			n = 0;
			pEntry = pPage->pList;
			for(;;){
				/* Loop one */
				if( n >= pPage->nCell ){
					break;
				}
				pEntry->pNextCol = pEntry->pPrevCol = 0;
				/* Install in the new bucket */
				iBucket = pEntry->nHash & (nNewSize - 1);
				pEntry->pNextCol = apNew[iBucket];
				if( apNew[iBucket]  ){
					apNew[iBucket]->pPrevCol = pEntry;
				}
				apNew[iBucket] = pEntry;
				/* Point to the next entry */
				pEntry = pEntry->pNext;
				n++;
			}
			/* Release the old table and reflect the change */
			SyMemBackendFree(&pPage->pHash->sAllocator,(void *)pPage->apCell);
			pPage->apCell = apNew;
			pPage->nCellSize  = nNewSize;
		}
	}
	return UNQLITE_OK;
}
/*
 * Private data of lhKeyCmp().
 */
struct lhash_key_cmp
{
	const char *zIn;  /* Start of the stream */
	const char *zEnd; /* End of the stream */
	ProcCmp xCmp;     /* Comparison function */
};
/*
 * Comparsion callback for large key > 256 KB
 */
static int lhKeyCmp(const void *pData,sxu32 nLen,void *pUserData)
{
	struct lhash_key_cmp *pCmp = (struct lhash_key_cmp *)pUserData;
	int rc;
	if( pCmp->zIn >= pCmp->zEnd ){
		if( nLen > 0 ){
			return UNQLITE_ABORT;
		}
		return UNQLITE_OK;
	}
	/* Perform the comparison */
	rc = pCmp->xCmp((const void *)pCmp->zIn,pData,nLen);
	if( rc != 0 ){
		/* Abort comparison */
		return UNQLITE_ABORT;
	}
	/* Advance the cursor */
	pCmp->zIn += nLen;
	return UNQLITE_OK;
}
/* Forward declaration */
static int lhConsumeCellkey(lhcell *pCell,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData,int offt_only);
/*
 * given a key, return the cell associated with it on success. NULL otherwise.
 */
static lhcell * lhFindCell(
	lhpage *pPage,    /* Target page */
	const void *pKey, /* Lookup key */
	sxu32 nByte,      /* Key length */
	sxu32 nHash       /* Hash of the key */
	)
{
	lhcell *pEntry;
	if( pPage->nCell < 1 ){
		/* Don't bother hashing */
		return 0;
	}
	/* Point to the corresponding bucket */
	pEntry = pPage->apCell[nHash & (pPage->nCellSize - 1)];
	for(;;){
		if( pEntry == 0 ){
			break;
		}
		if( pEntry->nHash == nHash && pEntry->nKey == nByte ){
			if( SyBlobLength(&pEntry->sKey) < 1 ){
				/* Large key (> 256 KB) are not kept in-memory */
				struct lhash_key_cmp sCmp;
				int rc;
				/* Fill-in the structure */
				sCmp.zIn = (const char *)pKey;
				sCmp.zEnd = &sCmp.zIn[nByte];
				sCmp.xCmp = pPage->pHash->xCmp;
				/* Fetch the key from disk and perform the comparison */
				rc = lhConsumeCellkey(pEntry,lhKeyCmp,&sCmp,0);
				if( rc == UNQLITE_OK ){
					/* Cell found */
					return pEntry;
				}
			}else if ( pPage->pHash->xCmp(pKey,SyBlobData(&pEntry->sKey),nByte) == 0 ){
				/* Cell found */
				return pEntry;
			}
		}
		/* Point to the next entry */
		pEntry = pEntry->pNextCol;
	}
	/* No such entry */
	return 0;
}
/*
 * Parse a raw cell fetched from disk.
 */
static int lhParseOneCell(lhpage *pPage,const unsigned char *zRaw,const unsigned char *zEnd,lhcell **ppOut)
{
	sxu16 iNext,iOfft;
	sxu32 iHash,nKey;
	lhcell *pCell;
	sxu64 nData;
	int rc;
	/* Offset this cell is stored */
	iOfft = (sxu16)(zRaw - (const unsigned char *)pPage->pRaw->zData);
	/* 4 byte hash number */
	SyBigEndianUnpack32(zRaw,&iHash);
	zRaw += 4;	
	/* 4 byte key length  */
	SyBigEndianUnpack32(zRaw,&nKey);
	zRaw += 4;	
	/* 8 byte data length */
	SyBigEndianUnpack64(zRaw,&nData);
	zRaw += 8;
	/* 2 byte offset of the next cell */
	SyBigEndianUnpack16(zRaw,&iNext);
	/* Perform a sanity check */
	if( iNext > 0 && &pPage->pRaw->zData[iNext] >= zEnd ){
		return UNQLITE_CORRUPT;
	}
	zRaw += 2;
	pCell = lhNewCell(pPage->pHash,pPage);
	if( pCell == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Fill in the structure */
	pCell->iNext = iNext;
	pCell->nKey  = nKey;
	pCell->nData = nData;
	pCell->nHash = iHash;
	/* Overflow page if any */
	SyBigEndianUnpack64(zRaw,&pCell->iOvfl);
	zRaw += 8;
	/* Cell offset */
	pCell->iStart = iOfft;
	/* Consume the key */
	rc = lhConsumeCellkey(pCell,unqliteDataConsumer,&pCell->sKey,pCell->nKey > 262144 /* 256 KB */? 1 : 0);
	if( rc != UNQLITE_OK ){
		/* TICKET: 14-32-chm@symisc.net: Key too large for memory */
		SyBlobRelease(&pCell->sKey);
	}
	/* Finally install the cell */
	rc = lhInstallCell(pCell);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( ppOut ){
		*ppOut = pCell;
	}
	return UNQLITE_OK;
}
/*
 * Compute the total number of free space on a given page.
 */
static int lhPageFreeSpace(lhpage *pPage)
{
	const unsigned char *zEnd,*zRaw = pPage->pRaw->zData;
	lhphdr *pHdr = &pPage->sHdr;
	sxu16 iNext,iAmount;
	sxu16 nFree = 0;
	if( pHdr->iFree < 1 ){
		/* Don't bother processing, the page is full */
		pPage->nFree = 0;
		return UNQLITE_OK;
	}
	/* Point to first free block */
	zEnd = &zRaw[pPage->pHash->iPageSize];
	zRaw += pHdr->iFree;
	for(;;){
		/* Offset of the next free block */
		SyBigEndianUnpack16(zRaw,&iNext);
		zRaw += 2;
		/* Available space on this block */
		SyBigEndianUnpack16(zRaw,&iAmount);
		nFree += iAmount;
		if( iNext < 1 ){
			/* No more free blocks */
			break;
		}
		/* Point to the next free block*/
		zRaw = &pPage->pRaw->zData[iNext];
		if( zRaw >= zEnd ){
			/* Corrupt page */
			return UNQLITE_CORRUPT;
		}
	}
	/* Save the amount of free space */
	pPage->nFree = nFree;
	return UNQLITE_OK;
}
/*
 * Given a primary page, load all its cell.
 */
static int lhLoadCells(lhpage *pPage)
{
	const unsigned char *zEnd,*zRaw = pPage->pRaw->zData;
	lhphdr *pHdr = &pPage->sHdr;
	lhcell *pCell = 0; /* cc warning */
	int rc;
	/* Calculate the amount of free space available first */
	rc = lhPageFreeSpace(pPage);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pHdr->iOfft < 1 ){
		/* Don't bother processing, the page is empty */
		return UNQLITE_OK;
	}
	/* Point to first cell */
	zRaw += pHdr->iOfft;
	zEnd = &zRaw[pPage->pHash->iPageSize];
	for(;;){
		/* Parse a single cell */
		rc = lhParseOneCell(pPage,zRaw,zEnd,&pCell);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		if( pCell->iNext < 1 ){
			/* No more cells */
			break;
		}
		/* Point to the next cell */
		zRaw = &pPage->pRaw->zData[pCell->iNext];
		if( zRaw >= zEnd ){
			/* Corrupt page */
			return UNQLITE_CORRUPT;
		}
	}
	/* All done */
	return UNQLITE_OK;
}
/*
 * Given a page, parse its raw headers.
 */
static int lhParsePageHeader(lhpage *pPage)
{
	const unsigned char *zRaw = pPage->pRaw->zData;
	lhphdr *pHdr = &pPage->sHdr;
	/* Offset of the first cell */
	SyBigEndianUnpack16(zRaw,&pHdr->iOfft);
	zRaw += 2;
	/* Offset of the first free block */
	SyBigEndianUnpack16(zRaw,&pHdr->iFree);
	zRaw += 2;
	/* Slave page number */
	SyBigEndianUnpack64(zRaw,&pHdr->iSlave);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Allocate a new page instance.
 */
static lhpage * lhNewPage(
	lhash_kv_engine *pEngine, /* KV store which own this instance */
	unqlite_page *pRaw,       /* Raw page contents */
	lhpage *pMaster           /* Master page in case we are dealing with a slave page */
	)
{
	lhpage *pPage;
	/* Allocate a new instance */
	pPage = (lhpage *)SyMemBackendPoolAlloc(&pEngine->sAllocator,sizeof(lhpage));
	if( pPage == 0 ){
		return 0;
	}
	/* Zero the structure */
	SyZero(pPage,sizeof(lhpage));
	/* Fill-in the structure */
	pPage->pHash = pEngine;
	pPage->pRaw = pRaw;
	pPage->pMaster = pMaster ? pMaster /* Slave page */ : pPage /* Master page */ ;
	if( pPage->pMaster != pPage ){
		/* Slave page, attach it to its master */
		pPage->pNextSlave = pMaster->pSlave;
		pMaster->pSlave = pPage;
		pMaster->iSlave++;
	}
	/* Save this instance for future fast lookup */
	pRaw->pUserData = pPage;
	/* All done */
	return pPage;
}
/*
 * Load a primary and its associated slave pages from disk.
 */
static int lhLoadPage(lhash_kv_engine *pEngine,pgno pnum,lhpage *pMaster,lhpage **ppOut,int iNest)
{
	unqlite_page *pRaw;
	lhpage *pPage = 0; /* cc warning */
	int rc;
	/* Aquire the page from the pager first */
	rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pnum,&pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pRaw->pUserData ){
		/* The page is already parsed and loaded in memory. Point to it */
		pPage = (lhpage *)pRaw->pUserData;
	}else{
		/* Allocate a new page */
		pPage = lhNewPage(pEngine,pRaw,pMaster);
		if( pPage == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Process the page */
		rc = lhParsePageHeader(pPage);
		if( rc == UNQLITE_OK ){
			/* Load cells */
			rc = lhLoadCells(pPage);
		}
		if( rc != UNQLITE_OK ){
			pEngine->pIo->xPageUnref(pPage->pRaw); /* pPage will be released inside this call */
			return rc;
		}
		if( pPage->sHdr.iSlave > 0 && iNest < 128 ){
			if( pMaster == 0 ){
				pMaster = pPage;
			}
			/* Slave page. Not a fatal error if something goes wrong here */
			lhLoadPage(pEngine,pPage->sHdr.iSlave,pMaster,0,iNest++);
		}
	}
	if( ppOut ){
		*ppOut = pPage;
	}
	return UNQLITE_OK;
}
/*
 * Given a cell, Consume its key by invoking the given callback for each extracted chunk.
 */
static int lhConsumeCellkey(
	lhcell *pCell, /* Target cell */
	int (*xConsumer)(const void *,unsigned int,void *), /* Consumer callback */
	void *pUserData, /* Last argument to xConsumer() */
	int offt_only
	)
{
	lhpage *pPage = pCell->pPage;
	const unsigned char *zRaw = pPage->pRaw->zData;
	const unsigned char *zPayload;
	int rc;
	/* Point to the payload area */
	zPayload = &zRaw[pCell->iStart];
	if( pCell->iOvfl == 0 ){
		/* Best scenario, consume the key directly without any overflow page */
		zPayload += L_HASH_CELL_SZ;
		rc = xConsumer((const void *)zPayload,pCell->nKey,pUserData);
		if( rc != UNQLITE_OK ){
			rc = UNQLITE_ABORT;
		}
	}else{
		lhash_kv_engine *pEngine = pPage->pHash;
		sxu32 nByte,nData = pCell->nKey;
		unqlite_page *pOvfl;
		int data_offset = 0;
		pgno iOvfl;
		/* Overflow page */
		iOvfl = pCell->iOvfl;
		/* Total usable bytes in an overflow page */
		nByte = L_HASH_OVERFLOW_SIZE(pEngine->iPageSize);
		for(;;){
			if( iOvfl == 0 || nData < 1 ){
				/* no more overflow page */
				break;
			}
			/* Point to the overflow page */
			rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,iOvfl,&pOvfl);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			zPayload = &pOvfl->zData[8];
			/* Point to the raw content */
			if( !data_offset ){
				/* Get the data page and offset */
				SyBigEndianUnpack64(zPayload,&pCell->iDataPage);
				zPayload += 8;
				SyBigEndianUnpack16(zPayload,&pCell->iDataOfft);
				zPayload += 2;
				if( offt_only ){
					/* Key too large, grab the data offset and return */
					pEngine->pIo->xPageUnref(pOvfl);
					return UNQLITE_OK;
				}
				data_offset = 1;
			}
			/* Consume the key */
			if( nData <= nByte ){
				rc = xConsumer((const void *)zPayload,nData,pUserData);
				if( rc != UNQLITE_OK ){
					pEngine->pIo->xPageUnref(pOvfl);
					return UNQLITE_ABORT;
				}
				nData = 0;
			}else{
				rc = xConsumer((const void *)zPayload,nByte,pUserData);
				if( rc != UNQLITE_OK ){
					pEngine->pIo->xPageUnref(pOvfl);
					return UNQLITE_ABORT;
				}
				nData -= nByte;
			}
			/* Next overflow page in the chain */
			SyBigEndianUnpack64(pOvfl->zData,&iOvfl);
			/* Unref the page */
			pEngine->pIo->xPageUnref(pOvfl);
		}
		rc = UNQLITE_OK;
	}
	return rc;
}
/*
 * Given a cell, Consume its data by invoking the given callback for each extracted chunk.
 */
static int lhConsumeCellData(
	lhcell *pCell, /* Target cell */
	int (*xConsumer)(const void *,unsigned int,void *), /* Data consumer callback */
	void *pUserData /* Last argument to xConsumer() */
	)
{
	lhpage *pPage = pCell->pPage;
	const unsigned char *zRaw = pPage->pRaw->zData;
	const unsigned char *zPayload;
	int rc;
	/* Point to the payload area */
	zPayload = &zRaw[pCell->iStart];
	if( pCell->iOvfl == 0 ){
		/* Best scenario, consume the data directly without any overflow page */
		zPayload += L_HASH_CELL_SZ + pCell->nKey;
		rc = xConsumer((const void *)zPayload,(sxu32)pCell->nData,pUserData);
		if( rc != UNQLITE_OK ){
			rc = UNQLITE_ABORT;
		}
	}else{
		lhash_kv_engine *pEngine = pPage->pHash;
		sxu64 nData = pCell->nData;
		unqlite_page *pOvfl;
		int fix_offset = 0;
		sxu32 nByte;
		pgno iOvfl;
		/* Overflow page where data is stored */
		iOvfl = pCell->iDataPage;
		for(;;){
			if( iOvfl == 0 || nData < 1 ){
				/* no more overflow page */
				break;
			}
			/* Point to the overflow page */
			rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,iOvfl,&pOvfl);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Point to the raw content */
			zPayload = pOvfl->zData;
			if( !fix_offset ){
				/* Point to the data */
				zPayload += pCell->iDataOfft;
				nByte = pEngine->iPageSize - pCell->iDataOfft;
				fix_offset = 1;
			}else{
				zPayload += 8;
				/* Total usable bytes in an overflow page */
				nByte = L_HASH_OVERFLOW_SIZE(pEngine->iPageSize);
			}
			/* Consume the data */
			if( nData <= (sxu64)nByte ){
				rc = xConsumer((const void *)zPayload,(unsigned int)nData,pUserData);
				if( rc != UNQLITE_OK ){
					pEngine->pIo->xPageUnref(pOvfl);
					return UNQLITE_ABORT;
				}
				nData = 0;
			}else{
				if( nByte > 0 ){
					rc = xConsumer((const void *)zPayload,nByte,pUserData);
					if( rc != UNQLITE_OK ){
						pEngine->pIo->xPageUnref(pOvfl);
						return UNQLITE_ABORT;
					}
					nData -= nByte;
				}
			}
			/* Next overflow page in the chain */
			SyBigEndianUnpack64(pOvfl->zData,&iOvfl);
			/* Unref the page */
			pEngine->pIo->xPageUnref(pOvfl);
		}
		rc = UNQLITE_OK;
	}
	return rc;
}
/*
 * Read the linear hash header (Page one of the database).
 */
static int lhash_read_header(lhash_kv_engine *pEngine,unqlite_page *pHeader)
{
	const unsigned char *zRaw = pHeader->zData;
	lhash_bmap_page *pMap;
	sxu32 nHash;
	int rc;
	pEngine->pHeader = pHeader;
	/* 4 byte magic number */
	SyBigEndianUnpack32(zRaw,&pEngine->nMagic);
	zRaw += 4;
	if( pEngine->nMagic != L_HASH_MAGIC ){
		/* Corrupt implementation */
		return UNQLITE_CORRUPT;
	}
	/* 4 byte hash value to identify a valid hash function */
	SyBigEndianUnpack32(zRaw,&nHash);
	zRaw += 4;
	/* Sanity check */
	if( pEngine->xHash(L_HASH_WORD,sizeof(L_HASH_WORD)-1) != nHash ){
		/* Different hash function */
		pEngine->pIo->xErr(pEngine->pIo->pHandle,"Invalid hash function");
		return UNQLITE_INVALID;
	}
	/* List of free pages */
	SyBigEndianUnpack64(zRaw,&pEngine->nFreeList);
	zRaw += 8;
	/* Current split bucket */
	SyBigEndianUnpack64(zRaw,&pEngine->split_bucket);
	zRaw += 8;
	/* Maximum split bucket */
	SyBigEndianUnpack64(zRaw,&pEngine->max_split_bucket);
	zRaw += 8;
	/* Next generation */
	pEngine->nmax_split_nucket = pEngine->max_split_bucket << 1;
	/* Initialiaze the bucket map */
	pMap = &pEngine->sPageMap;
	/* Fill in the structure */
	pMap->iNum = pHeader->pgno;
	/* Next page in the bucket map */
	SyBigEndianUnpack64(zRaw,&pMap->iNext);
	zRaw += 8;
	/* Total number of records in the bucket map (This page only) */
	SyBigEndianUnpack32(zRaw,&pMap->nRec);
	zRaw += 4;
	pMap->iPtr = (sxu16)(zRaw - pHeader->zData);
	/* Load the map in memory */
	rc = lhMapLoadPage(pEngine,pMap,pHeader->zData);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Load the bucket map chain if any */
	for(;;){
		pgno iNext = pMap->iNext;
		unqlite_page *pPage;
		if( iNext == 0 ){
			/* No more map pages */
			break;
		}
		/* Point to the target page */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,iNext,&pPage);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Fill in the structure */
		pMap->iNum = iNext;
		pMap->iPtr = 0;
		/* Load the map in memory */
		rc = lhMapLoadPage(pEngine,pMap,pPage->zData);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	/* All done */
	return UNQLITE_OK;
}
/*
 * Perform a record lookup.
 */
static int lhRecordLookup(
	lhash_kv_engine *pEngine, /* KV storage engine */
	const void *pKey,         /* Lookup key */
	sxu32 nByte,              /* Key length */
	lhcell **ppCell           /* OUT: Target cell on success */
	)
{
	lhash_bmap_rec *pRec;
	lhpage *pPage;
	lhcell *pCell;
	pgno iBucket;
	sxu32 nHash;
	int rc;
	/* Acquire the first page (hash Header) so that everything gets loaded automatically */
	rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,1,0);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Compute the hash of the key first */
	nHash = pEngine->xHash(pKey,nByte);
	/* Extract the logical (i.e. not real) page number */
	iBucket = nHash & (pEngine->nmax_split_nucket - 1);
	if( iBucket >= (pEngine->split_bucket + pEngine->max_split_bucket) ){
		/* Low mask */
		iBucket = nHash & (pEngine->max_split_bucket - 1);
	}
	/* Map the logical bucket number to real page number */
	pRec = lhMapFindBucket(pEngine,iBucket);
	if( pRec == 0 ){
		/* No such entry */
		return UNQLITE_NOTFOUND;
	}
	/* Load the master page and it's slave page in-memory  */
	rc = lhLoadPage(pEngine,pRec->iReal,0,&pPage,0);
	if( rc != UNQLITE_OK ){
		/* IO error, unlikely scenario */
		return rc;
	}
	/* Lookup for the cell */
	pCell = lhFindCell(pPage,pKey,nByte,nHash);
	if( pCell == 0 ){
		/* No such entry */
		return UNQLITE_NOTFOUND;
	}
	if( ppCell ){
		*ppCell = pCell;
	}
	return UNQLITE_OK;
}
/*
 * Acquire a new page either from the free list or ask the pager
 * for a new one.
 */
static int lhAcquirePage(lhash_kv_engine *pEngine,unqlite_page **ppOut)
{
	unqlite_page *pPage;
	int rc;
	if( pEngine->nFreeList != 0 ){
		/* Acquire one from the free list */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pEngine->nFreeList,&pPage);
		if( rc == UNQLITE_OK ){
			/* Point to the next free page */
			SyBigEndianUnpack64(pPage->zData,&pEngine->nFreeList);
			/* Update the database header */
			rc = pEngine->pIo->xWrite(pEngine->pHeader);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			SyBigEndianPack64(&pEngine->pHeader->zData[4/*Magic*/+4/*Hash*/],pEngine->nFreeList);
			/* Tell the pager do not journal this page */
			pEngine->pIo->xDontJournal(pPage);
			/* Return to the caller */
			*ppOut = pPage;
			/* All done */
			return UNQLITE_OK;
		}
	}
	/* Acquire a new page */
	rc = pEngine->pIo->xNew(pEngine->pIo->pHandle,&pPage);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Point to the target page */
	*ppOut = pPage;
	return UNQLITE_OK;
}
/*
 * Write a bucket map record to disk.
 */
static int lhMapWriteRecord(lhash_kv_engine *pEngine,pgno iLogic,pgno iReal)
{
	lhash_bmap_page *pMap = &pEngine->sPageMap;
	unqlite_page *pPage = 0;
	int rc;
	if( pMap->iPtr > (pEngine->iPageSize - 16) /* 8 byte logical bucket number + 8 byte real bucket number */ ){
		unqlite_page *pOld;
		/* Point to the old page */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pMap->iNum,&pOld);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Acquire a new page */
		rc = lhAcquirePage(pEngine,&pPage);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Reflect the change  */
		pMap->iNext = 0;
		pMap->iNum = pPage->pgno;
		pMap->nRec = 0;
		pMap->iPtr = 8/* Next page number */+4/* Total records in the map*/;
		/* Link this page */
		rc = pEngine->pIo->xWrite(pOld);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		if( pOld->pgno == pEngine->pHeader->pgno ){
			/* First page (Hash header) */
			SyBigEndianPack64(&pOld->zData[4/*magic*/+4/*hash*/+8/* Free page */+8/*current split bucket*/+8/*Maximum split bucket*/],pPage->pgno);
		}else{
			/* Link the new page */
			SyBigEndianPack64(pOld->zData,pPage->pgno);
			/* Unref */
			pEngine->pIo->xPageUnref(pOld);
		}
		/* Assume the last bucket map page */
		rc = pEngine->pIo->xWrite(pPage);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		SyBigEndianPack64(pPage->zData,0); /* Next bucket map page on the list */
	}
	if( pPage == 0){
		/* Point to the current map page */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pMap->iNum,&pPage);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	/* Make page writable */
	rc = pEngine->pIo->xWrite(pPage);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Write the data */
	SyBigEndianPack64(&pPage->zData[pMap->iPtr],iLogic);
	pMap->iPtr += 8;
	SyBigEndianPack64(&pPage->zData[pMap->iPtr],iReal);
	pMap->iPtr += 8;
	/* Install the bucket map */
	rc = lhMapInstallBucket(pEngine,iLogic,iReal);
	if( rc == UNQLITE_OK ){
		/* Total number of records */
		pMap->nRec++;
		if( pPage->pgno == pEngine->pHeader->pgno ){
			/* Page one: Always writable */
			SyBigEndianPack32(
				&pPage->zData[4/*magic*/+4/*hash*/+8/* Free page */+8/*current split bucket*/+8/*Maximum split bucket*/+8/*Next map page*/],
				pMap->nRec);
		}else{
			/* Make page writable */
			rc = pEngine->pIo->xWrite(pPage);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			SyBigEndianPack32(&pPage->zData[8],pMap->nRec);
		}
	}
	return rc;
}
/*
 * Defragment a page.
 */
static int lhPageDefragment(lhpage *pPage)
{
	lhash_kv_engine *pEngine = pPage->pHash;
	unsigned char *zTmp,*zPtr,*zEnd,*zPayload;
	lhcell *pCell;
	/* Get a temporary page from the pager. This operation never fail */
	zTmp = pEngine->pIo->xTmpPage(pEngine->pIo->pHandle);
	/* Move the target cells to the beginning */
	pCell = pPage->pMaster->pList;
	/* Write the slave page number */
	SyBigEndianPack64(&zTmp[2/*Offset of the first cell */+2/*Offset of the first free block */],pPage->sHdr.iSlave);
	zPtr = &zTmp[L_HASH_PAGE_HDR_SZ]; /* Offset to start writing from */
	zEnd = &zTmp[pEngine->iPageSize];
	pPage->sHdr.iOfft = 0; /* Offset of the first cell */
	for(;;){
		if( pCell == 0 ){
			/* No more cells */
			break;
		}
		if( pCell->pPage->pRaw->pgno == pPage->pRaw->pgno ){
			/* Cell payload if locally stored */
			zPayload = 0;
			if( pCell->iOvfl == 0 ){
				zPayload = &pCell->pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ];
			}
			/* Move the cell */
			pCell->iNext = pPage->sHdr.iOfft;
			pCell->iStart = (sxu16)(zPtr - zTmp); /* Offset where this cell start */
			pPage->sHdr.iOfft = pCell->iStart;
			/* Write the cell header */
			/* 4 byte hash number */
			SyBigEndianPack32(zPtr,pCell->nHash);
			zPtr += 4;
			/* 4 byte ley length */
			SyBigEndianPack32(zPtr,pCell->nKey);
			zPtr += 4;
			/* 8 byte data length */
			SyBigEndianPack64(zPtr,pCell->nData);
			zPtr += 8;
			/* 2 byte offset of the next cell */
			SyBigEndianPack16(zPtr,pCell->iNext);
			zPtr += 2;
			/* 8 byte overflow page number */
			SyBigEndianPack64(zPtr,pCell->iOvfl);
			zPtr += 8;
			if( zPayload ){
				/* Local payload */
				SyMemcpy((const void *)zPayload,zPtr,(sxu32)(pCell->nKey + pCell->nData));
				zPtr += pCell->nKey + pCell->nData;
			}
			if( zPtr >= zEnd ){
				/* Can't happen */
				break;
			}
		}
		/* Point to the next page */
		pCell = pCell->pNext;
	}
	/* Mark the free block */
	pPage->nFree = (sxu16)(zEnd - zPtr); /* Block length */
	if( pPage->nFree > 3 ){
		pPage->sHdr.iFree = (sxu16)(zPtr - zTmp); /* Offset of the free block */
		/* Mark the block */
		SyBigEndianPack16(zPtr,0); /* Offset of the next free block */
		SyBigEndianPack16(&zPtr[2],pPage->nFree); /* Block length */
	}else{
		/* Block of length less than 4 bytes are simply discarded */
		pPage->nFree = 0;
		pPage->sHdr.iFree = 0;
	}
	/* Reflect the change */
	SyBigEndianPack16(zTmp,pPage->sHdr.iOfft);     /* Offset of the first cell */
	SyBigEndianPack16(&zTmp[2],pPage->sHdr.iFree); /* Offset of the first free block */
	SyMemcpy((const void *)zTmp,pPage->pRaw->zData,pEngine->iPageSize);
	/* All done */
	return UNQLITE_OK;
}
/*
** Allocate nByte bytes of space on a page.
**
** Return the index into pPage->pRaw->zData[] of the first byte of
** the new allocation. Or return 0 if there is not enough free
** space on the page to satisfy the allocation request.
**
** If the page contains nBytes of free space but does not contain
** nBytes of contiguous free space, then this routine automatically
** calls defragementPage() to consolidate all free space before 
** allocating the new chunk.
*/
static int lhAllocateSpace(lhpage *pPage,sxu64 nAmount,sxu16 *pOfft)
{
	const unsigned char *zEnd,*zPtr;
	sxu16 iNext,iBlksz,nByte;
	unsigned char *zPrev;
	int rc;
	if( (sxu64)pPage->nFree < nAmount ){
		/* Don't bother looking for a free chunk */
		return UNQLITE_FULL;
	}
	if( pPage->nCell < 10 && ((int)nAmount >= (pPage->pHash->iPageSize / 2)) ){
		/* Big chunk need an overflow page for its data */
		return UNQLITE_FULL;
	}
	zPtr = &pPage->pRaw->zData[pPage->sHdr.iFree];
	zEnd = &pPage->pRaw->zData[pPage->pHash->iPageSize];
	nByte = (sxu16)nAmount;
	zPrev = 0;
	iBlksz = 0; /* cc warning */
	/* Perform the lookup */
	for(;;){
		if( zPtr >= zEnd ){
			return UNQLITE_FULL;
		}
		/* Offset of the next free block */
		SyBigEndianUnpack16(zPtr,&iNext);
		/* Block size */
		SyBigEndianUnpack16(&zPtr[2],&iBlksz);
		if( iBlksz >= nByte ){
			/* Got one */
			break;
		}
		zPrev = (unsigned char *)zPtr;
		if( iNext == 0 ){
			/* No more free blocks, defragment the page */
			rc = lhPageDefragment(pPage);
			if( rc == UNQLITE_OK && pPage->nFree >= nByte) {
				/* Free blocks are merged together */
				iNext = 0;
				zPtr = &pPage->pRaw->zData[pPage->sHdr.iFree];
				iBlksz = pPage->nFree;
				zPrev = 0;
				break;
			}else{
				return UNQLITE_FULL;
			}
		}
		/* Point to the next free block */
		zPtr = &pPage->pRaw->zData[iNext];
	}
	/* Acquire writer lock on this page */
	rc = pPage->pHash->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Save block offset */
	*pOfft = (sxu16)(zPtr - pPage->pRaw->zData);
	/* Fix pointers */
	if( iBlksz >= nByte && (iBlksz - nByte) > 3 ){
		unsigned char *zBlock = &pPage->pRaw->zData[(*pOfft) + nByte];
		/* Create a new block */
		zPtr = zBlock;
		SyBigEndianPack16(zBlock,iNext); /* Offset of the next block */
		SyBigEndianPack16(&zBlock[2],iBlksz-nByte); /* Block size*/
		/* Offset of the new block */
		iNext = (sxu16)(zPtr - pPage->pRaw->zData);
		iBlksz = nByte;
	}
	/* Fix offsets */
	if( zPrev ){
		SyBigEndianPack16(zPrev,iNext);
	}else{
		/* First block */
		pPage->sHdr.iFree = iNext;
		/* Reflect on the page header */
		SyBigEndianPack16(&pPage->pRaw->zData[2/* Offset of the first cell1*/],iNext);
	}
	/* All done */
	pPage->nFree -= iBlksz;
	return UNQLITE_OK;
}
/*
 * Write the cell header into the corresponding offset.
 */
static int lhCellWriteHeader(lhcell *pCell)
{
	lhpage *pPage = pCell->pPage;
	unsigned char *zRaw = pPage->pRaw->zData;
	/* Seek to the desired location */
	zRaw += pCell->iStart;
	/* 4 byte hash number */
	SyBigEndianPack32(zRaw,pCell->nHash);
	zRaw += 4;
	/* 4 byte key length */
	SyBigEndianPack32(zRaw,pCell->nKey);
	zRaw += 4;
	/* 8 byte data length */
	SyBigEndianPack64(zRaw,pCell->nData);
	zRaw += 8;
	/* 2 byte offset of the next cell */
	pCell->iNext = pPage->sHdr.iOfft;
	SyBigEndianPack16(zRaw,pCell->iNext);
	zRaw += 2;
	/* 8 byte overflow page number */
	SyBigEndianPack64(zRaw,pCell->iOvfl);
	/* Update the page header */
	pPage->sHdr.iOfft = pCell->iStart;
	/* pEngine->pIo->xWrite() has been successfully called on this page */
	SyBigEndianPack16(pPage->pRaw->zData,pCell->iStart);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Write local payload.
 */
static int lhCellWriteLocalPayload(lhcell *pCell,
	const void *pKey,sxu32 nKeylen,
	const void *pData,unqlite_int64 nDatalen
	)
{
	/* A writer lock have been acquired on this page */
	lhpage *pPage = pCell->pPage;
	unsigned char *zRaw = pPage->pRaw->zData;
	/* Seek to the desired location */
	zRaw += pCell->iStart + L_HASH_CELL_SZ;
	/* Write the key */
	SyMemcpy(pKey,(void *)zRaw,nKeylen);
	zRaw += nKeylen;
	if( nDatalen > 0 ){
		/* Write the Data */
		SyMemcpy(pData,(void *)zRaw,(sxu32)nDatalen);
	}
	return UNQLITE_OK;
}
/*
 * Allocate as much overflow page we need to store the cell payload.
 */
static int lhCellWriteOvflPayload(lhcell *pCell,const void *pKey,sxu32 nKeylen,...)
{
	lhpage *pPage = pCell->pPage;
	lhash_kv_engine *pEngine = pPage->pHash;
	unqlite_page *pOvfl,*pFirst,*pNew;
	const unsigned char *zPtr,*zEnd;
	unsigned char *zRaw,*zRawEnd;
	sxu32 nAvail;
	va_list ap;
	int rc;
	/* Acquire a new overflow page */
	rc = lhAcquirePage(pEngine,&pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Acquire a writer lock */
	rc = pEngine->pIo->xWrite(pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	pFirst = pOvfl;
	/* Link */
	pCell->iOvfl = pOvfl->pgno;
	/* Update the cell header */
	SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4/*Hash*/ + 4/*Key*/ + 8/*Data*/ + 2 /*Next cell*/],pCell->iOvfl);
	/* Start the write process */
	zPtr = (const unsigned char *)pKey;
	zEnd = &zPtr[nKeylen];
	SyBigEndianPack64(pOvfl->zData,0); /* Next overflow page on the chain */
	zRaw = &pOvfl->zData[8/* Next ovfl page*/ + 8 /* Data page */ + 2 /* Data offset*/];
	zRawEnd = &pOvfl->zData[pEngine->iPageSize];
	pNew = pOvfl;
	/* Write the key */
	for(;;){
		if( zPtr >= zEnd ){
			break;
		}
		if( zRaw >= zRawEnd ){
			/* Acquire a new page */
			rc = lhAcquirePage(pEngine,&pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			rc = pEngine->pIo->xWrite(pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Link */
			SyBigEndianPack64(pOvfl->zData,pNew->pgno);
			pEngine->pIo->xPageUnref(pOvfl);
			SyBigEndianPack64(pNew->zData,0); /* Next overflow page on the chain */
			pOvfl = pNew;
			zRaw = &pNew->zData[8];
			zRawEnd = &pNew->zData[pEngine->iPageSize];
		}
		nAvail = (sxu32)(zRawEnd-zRaw);
		nKeylen = (sxu32)(zEnd-zPtr);
		if( nKeylen > nAvail ){
			nKeylen = nAvail;
		}
		SyMemcpy((const void *)zPtr,(void *)zRaw,nKeylen);
		/* Synchronize pointers */
		zPtr += nKeylen;
		zRaw += nKeylen;
	}
	rc = UNQLITE_OK;
	va_start(ap,nKeylen);
	pCell->iDataPage = pNew->pgno;
	pCell->iDataOfft = (sxu16)(zRaw-pNew->zData);
	/* Write the data page and its offset */
	SyBigEndianPack64(&pFirst->zData[8/*Next ovfl*/],pCell->iDataPage);
	SyBigEndianPack16(&pFirst->zData[8/*Next ovfl*/+8/*Data page*/],pCell->iDataOfft);
	/* Write data */
	for(;;){
		const void *pData;
		sxu32 nDatalen;
		sxu64 nData;
		pData = va_arg(ap,const void *);
		nData = va_arg(ap,sxu64);
		if( pData == 0 ){
			/* No more chunks */
			break;
		}
		/* Write this chunk */
		zPtr = (const unsigned char *)pData;
		zEnd = &zPtr[nData];
		for(;;){
			if( zPtr >= zEnd ){
				break;
			}
			if( zRaw >= zRawEnd ){
				/* Acquire a new page */
				rc = lhAcquirePage(pEngine,&pNew);
				if( rc != UNQLITE_OK ){
					va_end(ap);
					return rc;
				}
				rc = pEngine->pIo->xWrite(pNew);
				if( rc != UNQLITE_OK ){
					va_end(ap);
					return rc;
				}
				/* Link */
				SyBigEndianPack64(pOvfl->zData,pNew->pgno);
				pEngine->pIo->xPageUnref(pOvfl);
				SyBigEndianPack64(pNew->zData,0); /* Next overflow page on the chain */
				pOvfl = pNew;
				zRaw = &pNew->zData[8];
				zRawEnd = &pNew->zData[pEngine->iPageSize];
			}
			nAvail = (sxu32)(zRawEnd-zRaw);
			nDatalen = (sxu32)(zEnd-zPtr);
			if( nDatalen > nAvail ){
				nDatalen = nAvail;
			}
			SyMemcpy((const void *)zPtr,(void *)zRaw,nDatalen);
			/* Synchronize pointers */
			zPtr += nDatalen;
			zRaw += nDatalen;
		}
	}
	/* Unref the overflow page */
	pEngine->pIo->xPageUnref(pOvfl);
	va_end(ap);
	return UNQLITE_OK;
}
/*
 * Restore a page to the free list.
 */
static int lhRestorePage(lhash_kv_engine *pEngine,unqlite_page *pPage)
{
	int rc;
	rc = pEngine->pIo->xWrite(pEngine->pHeader);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	rc = pEngine->pIo->xWrite(pPage);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Link to the list of free page */
	SyBigEndianPack64(pPage->zData,pEngine->nFreeList);
	pEngine->nFreeList = pPage->pgno;
	SyBigEndianPack64(&pEngine->pHeader->zData[4/*Magic*/+4/*Hash*/],pEngine->nFreeList);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Restore cell space and mark it as a free block.
 */
static int lhRestoreSpace(lhpage *pPage,sxu16 iOfft,sxu16 nByte)
{
	unsigned char *zRaw;
	if( nByte < 4 ){
		/* At least 4 bytes of freespace must form a valid block */
		return UNQLITE_OK;
	}
	/* pEngine->pIo->xWrite() has been successfully called on this page */
	zRaw = &pPage->pRaw->zData[iOfft];
	/* Mark as a free block */
	SyBigEndianPack16(zRaw,pPage->sHdr.iFree); /* Offset of the next free block */
	zRaw += 2;
	SyBigEndianPack16(zRaw,nByte);
	/* Link */
	SyBigEndianPack16(&pPage->pRaw->zData[2/* offset of the first cell */],iOfft);
	pPage->sHdr.iFree = iOfft;
	pPage->nFree += nByte;
	return UNQLITE_OK;
}
/* Forward declaration */
static lhcell * lhFindSibeling(lhcell *pCell);
/*
 * Unlink a cell.
 */
static int lhUnlinkCell(lhcell *pCell)
{
	lhash_kv_engine *pEngine = pCell->pPage->pHash;
	lhpage *pPage = pCell->pPage;
	sxu16 nByte = L_HASH_CELL_SZ;
	lhcell *pPrev;
	int rc;
	rc = pEngine->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Bring the link */
	pPrev = lhFindSibeling(pCell);
	if( pPrev ){
		pPrev->iNext = pCell->iNext;
		/* Fix offsets in the page header */
		SyBigEndianPack16(&pPage->pRaw->zData[pPrev->iStart + 4/*Hash*/+4/*Key*/+8/*Data*/],pCell->iNext);
	}else{
		/* First entry on this page (either master or slave) */
		pPage->sHdr.iOfft = pCell->iNext;
		/* Update the page header */
		SyBigEndianPack16(pPage->pRaw->zData,pCell->iNext);
	}
	/* Restore cell space */
	if( pCell->iOvfl == 0 ){
		nByte += (sxu16)(pCell->nData + pCell->nKey);
	}
	lhRestoreSpace(pPage,pCell->iStart,nByte);
	/* Discard the cell from the in-memory hashtable */
	lhCellDiscard(pCell);
	return UNQLITE_OK;
}
/*
 * Remove a cell and its paylod (key + data).
 */
static int lhRecordRemove(lhcell *pCell)
{
	lhash_kv_engine *pEngine = pCell->pPage->pHash;
	int rc;
	if( pCell->iOvfl > 0){
		/* Discard overflow pages */
		unqlite_page *pOvfl;
		pgno iNext = pCell->iOvfl;
		for(;;){
			/* Point to the overflow page */
			rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,iNext,&pOvfl);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Next page on the chain */
			SyBigEndianUnpack64(pOvfl->zData,&iNext);
			/* Restore the page to the free list */
			rc = lhRestorePage(pEngine,pOvfl);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Unref */
			pEngine->pIo->xPageUnref(pOvfl);
			if( iNext == 0 ){
				break;
			}
		}
	}
	/* Unlink the cell */
	rc = lhUnlinkCell(pCell);
	return rc;
}
/*
 * Find cell sibeling.
 */
static lhcell * lhFindSibeling(lhcell *pCell)
{
	lhpage *pPage = pCell->pPage->pMaster;
	lhcell *pEntry;
	pEntry = pPage->pFirst; 
	while( pEntry ){
		if( pEntry->pPage == pCell->pPage && pEntry->iNext == pCell->iStart ){
			/* Sibeling found */
			return pEntry;
		}
		/* Point to the previous entry */
		pEntry = pEntry->pPrev; 
	}
	/* Last inserted cell */
	return 0;
}
/*
 * Move a cell to a new location with its new data.
 */
static int lhMoveLocalCell(
	lhcell *pCell,
	sxu16 iOfft,
	const void *pData,
	unqlite_int64 nData
	)
{
	sxu16 iKeyOfft = pCell->iStart + L_HASH_CELL_SZ;
	lhpage *pPage = pCell->pPage;
	lhcell *pSibeling;
	pSibeling = lhFindSibeling(pCell);
	if( pSibeling ){
		/* Fix link */
		SyBigEndianPack16(&pPage->pRaw->zData[pSibeling->iStart + 4/*Hash*/+4/*Key*/+8/*Data*/],pCell->iNext);
		pSibeling->iNext = pCell->iNext;
	}else{
		/* First cell, update page header only */
		SyBigEndianPack16(pPage->pRaw->zData,pCell->iNext);
		pPage->sHdr.iOfft = pCell->iNext;
	}
	/* Set the new offset */
	pCell->iStart = iOfft;
	pCell->nData = (sxu64)nData;
	/* Write the cell payload */
	lhCellWriteLocalPayload(pCell,(const void *)&pPage->pRaw->zData[iKeyOfft],pCell->nKey,pData,nData);
	/* Finally write the cell header */
	lhCellWriteHeader(pCell);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Overwrite an existing record.
 */
static int lhRecordOverwrite(
	lhcell *pCell,
	const void *pData,unqlite_int64 nByte
	)
{
	lhash_kv_engine *pEngine = pCell->pPage->pHash;
	unsigned char *zRaw,*zRawEnd,*zPayload;
	const unsigned char *zPtr,*zEnd;
	unqlite_page *pOvfl,*pOld,*pNew;
	lhpage *pPage = pCell->pPage;
	sxu32 nAvail;
	pgno iOvfl;
	int rc;
	/* Acquire a writer lock on this page */
	rc = pEngine->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pCell->iOvfl == 0 ){
		/* Local payload, try to deal with the free space issues */
		zPayload = &pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ + pCell->nKey];
		if( pCell->nData == (sxu64)nByte ){
			/* Best scenario, simply a memcpy operation */
			SyMemcpy(pData,(void *)zPayload,(sxu32)nByte);
		}else if( (sxu64)nByte < pCell->nData ){
			/* Shorter data, not so ugly */
			SyMemcpy(pData,(void *)zPayload,(sxu32)nByte);
			/* Update the cell header */
			SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4 /* Hash */ + 4 /* Key */],nByte);
			/* Restore freespace */
			lhRestoreSpace(pPage,(sxu16)(pCell->iStart + L_HASH_CELL_SZ + pCell->nKey + nByte),(sxu16)(pCell->nData - nByte));
			/* New data size */
			pCell->nData = (sxu64)nByte;
		}else{
			sxu16 iOfft = 0; /* cc warning */
			/* Check if another chunk is available for this cell */
			rc = lhAllocateSpace(pPage,L_HASH_CELL_SZ + pCell->nKey + nByte,&iOfft);
			if( rc != UNQLITE_OK ){
				/* Transfer the payload to an overflow page */
				rc = lhCellWriteOvflPayload(pCell,&pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ],pCell->nKey,pData,nByte,(const void *)0);
				if( rc != UNQLITE_OK ){
					return rc;
				}
				/* Update the cell header */
				SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4 /* Hash */ + 4 /* Key */],(sxu64)nByte);
				/* Restore freespace */
				lhRestoreSpace(pPage,(sxu16)(pCell->iStart + L_HASH_CELL_SZ),(sxu16)(pCell->nKey + pCell->nData));
				/* New data size */
				pCell->nData = (sxu64)nByte;
			}else{
				sxu16 iOldOfft = pCell->iStart;
				sxu32 iOld = (sxu32)pCell->nData;
				/* Space is available, transfer the cell */
				lhMoveLocalCell(pCell,iOfft,pData,nByte);
				/* Restore cell space */
				lhRestoreSpace(pPage,iOldOfft,(sxu16)(L_HASH_CELL_SZ + pCell->nKey + iOld));
			}
		}
		return UNQLITE_OK;
	}
	/* Point to the overflow page */
	rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pCell->iDataPage,&pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Release all old overflow pages first */
	SyBigEndianUnpack64(pOvfl->zData,&iOvfl);
	pOld = pOvfl;
	for(;;){
		if( iOvfl == 0 ){
			/* No more overflow pages on the chain */
			break;
		}
		/* Point to the target page */
		if( UNQLITE_OK != pEngine->pIo->xGet(pEngine->pIo->pHandle,iOvfl,&pOld) ){
			/* Not so fatal if something goes wrong here */
			break;
		}
		/* Next overflow page to be released */
		SyBigEndianUnpack64(pOld->zData,&iOvfl);
		if( pOld != pOvfl ){ /* xx: chm is maniac */
			/* Restore the page to the free list */
			lhRestorePage(pEngine,pOld);
			/* Unref */
			pEngine->pIo->xPageUnref(pOld);
		}
	}
	/* Point to the data offset */
	zRaw = &pOvfl->zData[pCell->iDataOfft];
	zRawEnd = &pOvfl->zData[pEngine->iPageSize];
	/* The data to be stored */
	zPtr = (const unsigned char *)pData;
	zEnd = &zPtr[nByte];
	/* Start the overwrite process */
	/* Acquire a writer lock */
	rc = pEngine->pIo->xWrite(pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	SyBigEndianPack64(pOvfl->zData,0);
	for(;;){
		sxu32 nLen;
		if( zPtr >= zEnd ){
			break;
		}
		if( zRaw >= zRawEnd ){
			/* Acquire a new page */
			rc = lhAcquirePage(pEngine,&pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			rc = pEngine->pIo->xWrite(pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Link */
			SyBigEndianPack64(pOvfl->zData,pNew->pgno);
			pEngine->pIo->xPageUnref(pOvfl);
			SyBigEndianPack64(pNew->zData,0); /* Next overflow page on the chain */
			pOvfl = pNew;
			zRaw = &pNew->zData[8];
			zRawEnd = &pNew->zData[pEngine->iPageSize];
		}
		nAvail = (sxu32)(zRawEnd-zRaw);
		nLen = (sxu32)(zEnd-zPtr);
		if( nLen > nAvail ){
			nLen = nAvail;
		}
		SyMemcpy((const void *)zPtr,(void *)zRaw,nLen);
		/* Synchronize pointers */
		zPtr += nLen;
		zRaw += nLen;
	}
	/* Unref the last overflow page */
	pEngine->pIo->xPageUnref(pOvfl);
	/* Finally, update the cell header */
	pCell->nData = (sxu64)nByte;
	SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4 /* Hash */ + 4 /* Key */],pCell->nData);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Append data to an existing record.
 */
static int lhRecordAppend(
	lhcell *pCell,
	const void *pData,unqlite_int64 nByte
	)
{
	lhash_kv_engine *pEngine = pCell->pPage->pHash;
	const unsigned char *zPtr,*zEnd;
	lhpage *pPage = pCell->pPage;
	unsigned char *zRaw,*zRawEnd;
	unqlite_page *pOvfl,*pNew;
	sxu64 nDatalen;
	sxu32 nAvail;
	pgno iOvfl;
	int rc;
	if( pCell->nData + nByte < pCell->nData ){
		/* Overflow */
		pEngine->pIo->xErr(pEngine->pIo->pHandle,"Append operation will cause data overflow");
		return UNQLITE_LIMIT;
	}
	/* Acquire a writer lock on this page */
	rc = pEngine->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pCell->iOvfl == 0 ){
		sxu16 iOfft = 0; /* cc warning */
		/* Local payload, check for a bigger place */
		rc = lhAllocateSpace(pPage,L_HASH_CELL_SZ + pCell->nKey + pCell->nData + nByte,&iOfft);
		if( rc != UNQLITE_OK ){
			/* Transfer the payload to an overflow page */
			rc = lhCellWriteOvflPayload(pCell,
				&pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ],pCell->nKey,
				(const void *)&pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ + pCell->nKey],pCell->nData,
				pData,nByte,
				(const void *)0);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Update the cell header */
			SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4 /* Hash */ + 4 /* Key */],pCell->nData + nByte);
			/* Restore freespace */
			lhRestoreSpace(pPage,(sxu16)(pCell->iStart + L_HASH_CELL_SZ),(sxu16)(pCell->nKey + pCell->nData));
			/* New data size */
			pCell->nData += nByte;
		}else{
			sxu16 iOldOfft = pCell->iStart;
			sxu32 iOld = (sxu32)pCell->nData;
			SyBlob sWorker;
			SyBlobInit(&sWorker,&pEngine->sAllocator);
			/* Copy the old data */
			rc = SyBlobAppend(&sWorker,(const void *)&pPage->pRaw->zData[pCell->iStart + L_HASH_CELL_SZ + pCell->nKey],(sxu32)pCell->nData);
			if( rc == SXRET_OK ){
				/* Append the new data */
				rc = SyBlobAppend(&sWorker,pData,(sxu32)nByte);
			}
			if( rc != UNQLITE_OK ){
				SyBlobRelease(&sWorker);
				return rc;
			}
			/* Space is available, transfer the cell */
			lhMoveLocalCell(pCell,iOfft,SyBlobData(&sWorker),(unqlite_int64)SyBlobLength(&sWorker));
			/* Restore cell space */
			lhRestoreSpace(pPage,iOldOfft,(sxu16)(L_HASH_CELL_SZ + pCell->nKey + iOld));
			/* All done */
			SyBlobRelease(&sWorker);
		}
		return UNQLITE_OK;
	}
	/* Point to the overflow page which hold the data */
	rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,pCell->iDataPage,&pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Next overflow page in the chain */
	SyBigEndianUnpack64(pOvfl->zData,&iOvfl);
	/* Point to the end of the chunk */
	zRaw = &pOvfl->zData[pCell->iDataOfft];
	zRawEnd = &pOvfl->zData[pEngine->iPageSize];
	nDatalen = pCell->nData;
	nAvail = (sxu32)(zRawEnd - zRaw);
	for(;;){
		if( zRaw >= zRawEnd ){
			if( iOvfl == 0 ){
				/* Cant happen */
				pEngine->pIo->xErr(pEngine->pIo->pHandle,"Corrupt overflow page");
				return UNQLITE_CORRUPT;
			}
			rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,iOvfl,&pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Next overflow page on the chain */
			SyBigEndianUnpack64(pNew->zData,&iOvfl);
			/* Unref the previous overflow page */
			pEngine->pIo->xPageUnref(pOvfl);
			/* Point to the new chunk */
			zRaw = &pNew->zData[8];
			zRawEnd = &pNew->zData[pCell->pPage->pHash->iPageSize];
			nAvail = L_HASH_OVERFLOW_SIZE(pCell->pPage->pHash->iPageSize);
			pOvfl = pNew;
		}
		if( (sxu64)nAvail > nDatalen ){
			zRaw += nDatalen;
			break;
		}else{
			nDatalen -= nAvail;
		}
		zRaw += nAvail;
	}
	/* Start the append process */
	zPtr = (const unsigned char *)pData;
	zEnd = &zPtr[nByte];
	/* Acquire a writer lock */
	rc = pEngine->pIo->xWrite(pOvfl);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	for(;;){
		sxu32 nLen;
		if( zPtr >= zEnd ){
			break;
		}
		if( zRaw >= zRawEnd ){
			/* Acquire a new page */
			rc = lhAcquirePage(pEngine,&pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			rc = pEngine->pIo->xWrite(pNew);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			/* Link */
			SyBigEndianPack64(pOvfl->zData,pNew->pgno);
			pEngine->pIo->xPageUnref(pOvfl);
			SyBigEndianPack64(pNew->zData,0); /* Next overflow page on the chain */
			pOvfl = pNew;
			zRaw = &pNew->zData[8];
			zRawEnd = &pNew->zData[pEngine->iPageSize];
		}
		nAvail = (sxu32)(zRawEnd-zRaw);
		nLen = (sxu32)(zEnd-zPtr);
		if( nLen > nAvail ){
			nLen = nAvail;
		}
		SyMemcpy((const void *)zPtr,(void *)zRaw,nLen);
		/* Synchronize pointers */
		zPtr += nLen;
		zRaw += nLen;
	}
	/* Unref the last overflow page */
	pEngine->pIo->xPageUnref(pOvfl);
	/* Finally, update the cell header */
	pCell->nData += nByte;
	SyBigEndianPack64(&pPage->pRaw->zData[pCell->iStart + 4 /* Hash */ + 4 /* Key */],pCell->nData);
	/* All done */
	return UNQLITE_OK;
}
/*
 * A write privilege have been acquired on this page.
 * Mark it as an empty page (No cells).
 */
static int lhSetEmptyPage(lhpage *pPage)
{
	unsigned char *zRaw = pPage->pRaw->zData;
	lhphdr *pHeader = &pPage->sHdr;
	sxu16 nByte;
	int rc;
	/* Acquire a writer lock */
	rc = pPage->pHash->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Offset of the first cell */
	SyBigEndianPack16(zRaw,0);
	zRaw += 2;
	/* Offset of the first free block */
	pHeader->iFree = L_HASH_PAGE_HDR_SZ;
	SyBigEndianPack16(zRaw,L_HASH_PAGE_HDR_SZ);
	zRaw += 2;
	/* Slave page number */
	SyBigEndianPack64(zRaw,0);
	zRaw += 8;
	/* Fill the free block */
	SyBigEndianPack16(zRaw,0); /* Offset of the next free block */
	zRaw += 2;
	nByte = (sxu16)L_HASH_MX_FREE_SPACE(pPage->pHash->iPageSize);
	SyBigEndianPack16(zRaw,nByte);
	pPage->nFree = nByte;
	/* Do not add this page to the hot dirty list */
	pPage->pHash->pIo->xDontMkHot(pPage->pRaw);
	return UNQLITE_OK;
}
/* Forward declaration */
static int lhSlaveStore(
	lhpage *pPage,
	const void *pKey,sxu32 nKeyLen,
	const void *pData,unqlite_int64 nDataLen,
	sxu32 nHash
	);
/*
 * Store a cell and its payload in a given page.
 */
static int lhStoreCell(
	lhpage *pPage, /* Target page */
	const void *pKey,sxu32 nKeyLen, /* Payload: Key */
	const void *pData,unqlite_int64 nDataLen, /* Payload: Data */
	sxu32 nHash, /* Hash of the key */
	int auto_append /* Auto append a slave page if full */
	)
{
	lhash_kv_engine *pEngine = pPage->pHash;
	int iNeedOvfl = 0; /* Need overflow page for this cell and its payload*/
	lhcell *pCell;
	sxu16 nOfft;
	int rc;
	/* Acquire a writer lock on this page first */
	rc = pEngine->pIo->xWrite(pPage->pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Check for a free block  */
	rc = lhAllocateSpace(pPage,L_HASH_CELL_SZ+nKeyLen+nDataLen,&nOfft);
	if( rc != UNQLITE_OK ){
		/* Check for a free block to hold a single cell only (without payload) */
		rc = lhAllocateSpace(pPage,L_HASH_CELL_SZ,&nOfft);
		if( rc != UNQLITE_OK ){
			if( !auto_append ){
				/* A split must be done */
				return UNQLITE_FULL;
			}else{
				/* Store this record in a slave page */
				rc = lhSlaveStore(pPage,pKey,nKeyLen,pData,nDataLen,nHash);
				return rc;
			}
		}
		iNeedOvfl = 1;
	}
	/* Allocate a new cell instance */
	pCell = lhNewCell(pEngine,pPage);
	if( pCell == 0 ){
		pEngine->pIo->xErr(pEngine->pIo->pHandle,"KV store is running out of memory");
		return UNQLITE_NOMEM;
	}
	/* Fill-in the structure */
	pCell->iStart = nOfft;
	pCell->nKey = nKeyLen;
	pCell->nData = (sxu64)nDataLen;
	pCell->nHash = nHash;
	if( nKeyLen < 262144 /* 256 KB */ ){
		/* Keep the key in-memory for fast lookup */
		SyBlobAppend(&pCell->sKey,pKey,nKeyLen);
	}
	/* Link the cell */
	rc = lhInstallCell(pCell);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Write the payload */
	if( iNeedOvfl ){
		rc = lhCellWriteOvflPayload(pCell,pKey,nKeyLen,pData,nDataLen,(const void *)0);
		if( rc != UNQLITE_OK ){
			lhCellDiscard(pCell);
			return rc;
		}
	}else{
		lhCellWriteLocalPayload(pCell,pKey,nKeyLen,pData,nDataLen);
	}
	/* Finally, Write the cell header */
	lhCellWriteHeader(pCell);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Find a slave page capable of hosting the given amount.
 */
static int lhFindSlavePage(lhpage *pPage,sxu64 nAmount,sxu16 *pOfft,lhpage **ppSlave)
{
	lhash_kv_engine *pEngine = pPage->pHash;
	lhpage *pMaster = pPage->pMaster;
	lhpage *pSlave = pMaster->pSlave;
	unqlite_page *pRaw;
	lhpage *pNew;
	sxu16 iOfft;
	sxi32 i;
	int rc;
	/* Look for an already attached slave page */
	for( i = 0 ; i < pMaster->iSlave ; ++i ){
		/* Find a free chunk big enough */
		sxu16 size = (sxu16)(L_HASH_CELL_SZ + nAmount);
		rc = lhAllocateSpace(pSlave,size,&iOfft);
		if( rc != UNQLITE_OK ){
			/* A space for cell header only */
			size = L_HASH_CELL_SZ;
			rc = lhAllocateSpace(pSlave,size,&iOfft);
		}
		if( rc == UNQLITE_OK ){
			/* All done */
			if( pOfft ){
				*pOfft = iOfft;
			}else{
				rc = lhRestoreSpace(pSlave, iOfft, size);
			}
			*ppSlave = pSlave;
			return rc;
		}
		/* Point to the next slave page */
		pSlave = pSlave->pNextSlave;
	}
	/* Acquire a new slave page */
	rc = lhAcquirePage(pEngine,&pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Last slave page */
	pSlave = pMaster->pSlave;
	if( pSlave == 0 ){
		/* First slave page */
		pSlave = pMaster;
	}
	/* Initialize the page */
	pNew = lhNewPage(pEngine,pRaw,pMaster);
	if( pNew == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Mark as an empty page */
	rc = lhSetEmptyPage(pNew);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	if( pOfft ){
		/* Look for a free block */
		if( UNQLITE_OK != lhAllocateSpace(pNew,L_HASH_CELL_SZ+nAmount,&iOfft) ){
			/* Cell header only */
			lhAllocateSpace(pNew,L_HASH_CELL_SZ,&iOfft); /* Never fail */
		}	
		*pOfft = iOfft;
	}
	/* Link this page to the previous slave page */
	rc = pEngine->pIo->xWrite(pSlave->pRaw);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Reflect in the page header */
	SyBigEndianPack64(&pSlave->pRaw->zData[2/*Cell offset*/+2/*Free block offset*/],pRaw->pgno);
	pSlave->sHdr.iSlave = pRaw->pgno;
	/* All done */
	*ppSlave = pNew;
	return UNQLITE_OK;
fail:
	pEngine->pIo->xPageUnref(pNew->pRaw); /* pNew will be released in this call */
	return rc;

}
/*
 * Perform a store operation in a slave page.
 */
static int lhSlaveStore(
	lhpage *pPage, /* Master page */
	const void *pKey,sxu32 nKeyLen, /* Payload: key */
	const void *pData,unqlite_int64 nDataLen, /* Payload: data */
	sxu32 nHash /* Hash of the key */
	)
{
	lhpage *pSlave;
	int rc;
	/* Find a slave page */
	rc = lhFindSlavePage(pPage,nKeyLen + nDataLen,0,&pSlave);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Perform the insertion in the slave page */
	rc = lhStoreCell(pSlave,pKey,nKeyLen,pData,nDataLen,nHash,1);
	return rc;
}
/*
 * Transfer a cell to a new page (either a master or slave).
 */
static int lhTransferCell(lhcell *pTarget,lhpage *pPage)
{
	lhcell *pCell;
	sxu16 nOfft;
	int rc;
	/* Check for a free block to hold a single cell only */
	rc = lhAllocateSpace(pPage,L_HASH_CELL_SZ,&nOfft);
	if( rc != UNQLITE_OK ){
		/* Store in a slave page */
		rc = lhFindSlavePage(pPage,L_HASH_CELL_SZ,&nOfft,&pPage);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	/* Allocate a new cell instance */
	pCell = lhNewCell(pPage->pHash,pPage);
	if( pCell == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Fill-in the structure */
	pCell->iStart = nOfft;
	pCell->nData  = pTarget->nData;
	pCell->nKey   = pTarget->nKey;
	pCell->iOvfl  = pTarget->iOvfl;
	pCell->iDataOfft = pTarget->iDataOfft;
	pCell->iDataPage = pTarget->iDataPage;
	pCell->nHash = pTarget->nHash;
	SyBlobDup(&pTarget->sKey,&pCell->sKey);
	/* Link the cell */
	rc = lhInstallCell(pCell);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Finally, Write the cell header */
	lhCellWriteHeader(pCell);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Perform a page split.
 */
static int lhPageSplit(
	lhpage *pOld,      /* Page to be split */
	lhpage *pNew,      /* New page */
	pgno split_bucket, /* Current split bucket */
	pgno high_mask     /* High mask (Max split bucket - 1) */
	)
{
	lhcell *pCell,*pNext;
	SyBlob sWorker;
	pgno iBucket;
	int rc; 
	SyBlobInit(&sWorker,&pOld->pHash->sAllocator);
	/* Perform the split */
	pCell = pOld->pList;
	for( ;; ){
		if( pCell == 0 ){
			/* No more cells */
			break;
		}
		/* Obtain the new logical bucket */
		iBucket = pCell->nHash & high_mask;
		pNext =  pCell->pNext;
		if( iBucket != split_bucket){
			rc = UNQLITE_OK;
			if( pCell->iOvfl ){
				/* Transfer the cell only */
				rc = lhTransferCell(pCell,pNew);
			}else{
				/* Transfer the cell and its payload */
				SyBlobReset(&sWorker);
				if( SyBlobLength(&pCell->sKey) < 1 ){
					/* Consume the key */
					rc = lhConsumeCellkey(pCell,unqliteDataConsumer,&pCell->sKey,0);
					if( rc != UNQLITE_OK ){
						goto fail;
					}
				}
				/* Consume the data (Very small data < 65k) */
				rc = lhConsumeCellData(pCell,unqliteDataConsumer,&sWorker);
				if( rc != UNQLITE_OK ){
					goto fail;
				}
				/* Perform the transfer */
				rc = lhStoreCell(
					pNew,
					SyBlobData(&pCell->sKey),(int)SyBlobLength(&pCell->sKey),
					SyBlobData(&sWorker),SyBlobLength(&sWorker),
					pCell->nHash,
					1
					);
			}
			if( rc != UNQLITE_OK ){
				goto fail;
			}
			/* Discard the cell from the old page */
			lhUnlinkCell(pCell);
		}
		/* Point to the next cell */
		pCell = pNext;
	}
	/* All done */
	rc = UNQLITE_OK;
fail:
	SyBlobRelease(&sWorker);
	return rc;
}
/*
 * Perform the infamous linear hash split operation.
 */
static int lhSplit(lhpage *pTarget,int *pRetry)
{
	lhash_kv_engine *pEngine = pTarget->pHash;
	lhash_bmap_rec *pRec;
	lhpage *pOld,*pNew;
	unqlite_page *pRaw;
	int rc;
	/* Get the real page number of the bucket to split */
	pRec = lhMapFindBucket(pEngine,pEngine->split_bucket);
	if( pRec == 0 ){
		/* Can't happen */
		return UNQLITE_CORRUPT;
	}
	/* Load the page to be split */
	rc = lhLoadPage(pEngine,pRec->iReal,0,&pOld,0);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Request a new page */
	rc = lhAcquirePage(pEngine,&pRaw);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Initialize the page */
	pNew = lhNewPage(pEngine,pRaw,0);
	if( pNew == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Mark as an empty page */
	rc = lhSetEmptyPage(pNew);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Install and write the logical map record */
	rc = lhMapWriteRecord(pEngine,
		pEngine->split_bucket + pEngine->max_split_bucket,
		pRaw->pgno
		);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	if( pTarget->pRaw->pgno == pOld->pRaw->pgno ){
		*pRetry = 1;
	}
	/* Perform the split */
	rc = lhPageSplit(pOld,pNew,pEngine->split_bucket,pEngine->nmax_split_nucket - 1);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Update the database header */
	pEngine->split_bucket++;
	/* Acquire a writer lock on the first page */
	rc = pEngine->pIo->xWrite(pEngine->pHeader);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pEngine->split_bucket >= pEngine->max_split_bucket ){
		/* Increment the generation number */
		pEngine->split_bucket = 0;
		pEngine->max_split_bucket = pEngine->nmax_split_nucket;
		pEngine->nmax_split_nucket <<= 1;
		if( !pEngine->nmax_split_nucket ){
			/* If this happen to your installation, please tell us <chm@symisc.net> */
			pEngine->pIo->xErr(pEngine->pIo->pHandle,"Database page (64-bit integer) limit reached");
			return UNQLITE_LIMIT;
		}
		/* Reflect in the page header */
		SyBigEndianPack64(&pEngine->pHeader->zData[4/*Magic*/+4/*Hash*/+8/*Free list*/],pEngine->split_bucket);
		SyBigEndianPack64(&pEngine->pHeader->zData[4/*Magic*/+4/*Hash*/+8/*Free list*/+8/*Split bucket*/],pEngine->max_split_bucket);
	}else{
		/* Modify only the split bucket */
		SyBigEndianPack64(&pEngine->pHeader->zData[4/*Magic*/+4/*Hash*/+8/*Free list*/],pEngine->split_bucket);
	}
	/* All done */
	return UNQLITE_OK;
fail:
	pEngine->pIo->xPageUnref(pNew->pRaw);
	return rc;
}
/*
 * Store a record in the target page.
 */
static int lhRecordInstall(
	  lhpage *pPage, /* Target page */
	  sxu32 nHash,   /* Hash of the key */
	  const void *pKey,sxu32 nKeyLen,          /* Payload: Key */
	  const void *pData,unqlite_int64 nDataLen /* Payload: Data */
	  )
{
	int rc;
	rc = lhStoreCell(pPage,pKey,nKeyLen,pData,nDataLen,nHash,0);
	if( rc == UNQLITE_FULL ){
		int do_retry = 0;
		/* Split */
		rc = lhSplit(pPage,&do_retry);
		if( rc == UNQLITE_OK ){
			if( do_retry ){
				/* Re-calculate logical bucket number */
				return SXERR_RETRY;
			}
			/* Perform the store */
			rc = lhStoreCell(pPage,pKey,nKeyLen,pData,nDataLen,nHash,1);
		}
	}
	return rc;
}
/*
 * Insert a record (Either overwrite or append operation) in our database.
 */
static int lh_record_insert(
	  unqlite_kv_engine *pKv,         /* KV store */
	  const void *pKey,sxu32 nKeyLen, /* Payload: Key */
	  const void *pData,unqlite_int64 nDataLen, /* Payload: data */
	  int is_append /* True for an append operation */
	  )
{
	lhash_kv_engine *pEngine = (lhash_kv_engine *)pKv;
	lhash_bmap_rec *pRec;
	unqlite_page *pRaw;
	lhpage *pPage;
	lhcell *pCell;
	pgno iBucket;
	sxu32 nHash;
	int iCnt;
	int rc;

	/* Acquire the first page (DB hash Header) so that everything gets loaded automatically */
	rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,1,0);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	iCnt = 0;
	/* Compute the hash of the key first */
	nHash = pEngine->xHash(pKey,(sxu32)nKeyLen);
retry:
	/* Extract the logical bucket number */
	iBucket = nHash & (pEngine->nmax_split_nucket - 1);
	if( iBucket >= pEngine->split_bucket + pEngine->max_split_bucket ){
		/* Low mask */
		iBucket = nHash & (pEngine->max_split_bucket - 1);
	}
	/* Map the logical bucket number to real page number */
	pRec = lhMapFindBucket(pEngine,iBucket);
	if( pRec == 0 ){
		/* Request a new page */
		rc = lhAcquirePage(pEngine,&pRaw);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Initialize the page */
		pPage = lhNewPage(pEngine,pRaw,0);
		if( pPage == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Mark as an empty page */
		rc = lhSetEmptyPage(pPage);
		if( rc != UNQLITE_OK ){
			pEngine->pIo->xPageUnref(pRaw); /* pPage will be released during this call */
			return rc;
		}
		/* Store the cell */
		rc = lhStoreCell(pPage,pKey,nKeyLen,pData,nDataLen,nHash,1);
		if( rc == UNQLITE_OK ){
			/* Install and write the logical map record */
			rc = lhMapWriteRecord(pEngine,iBucket,pRaw->pgno);
		}
		pEngine->pIo->xPageUnref(pRaw);
		return rc;
	}else{
		/* Load the page */
		rc = lhLoadPage(pEngine,pRec->iReal,0,&pPage,0);
		if( rc != UNQLITE_OK ){
			/* IO error, unlikely scenario */
			return rc;
		}
		/* Do not add this page to the hot dirty list */
		pEngine->pIo->xDontMkHot(pPage->pRaw);
		/* Lookup for the cell */
		pCell = lhFindCell(pPage,pKey,(sxu32)nKeyLen,nHash);
		if( pCell == 0 ){
			/* Create the record */
			rc = lhRecordInstall(pPage,nHash,pKey,nKeyLen,pData,nDataLen);
			if( rc == SXERR_RETRY && iCnt++ < 2 ){
				rc = UNQLITE_OK;
				goto retry;
			}
		}else{
			if( is_append ){
				/* Append operation */
				rc = lhRecordAppend(pCell,pData,nDataLen);
			}else{
				/* Overwrite old value */
				rc = lhRecordOverwrite(pCell,pData,nDataLen);
			}
		}
		pEngine->pIo->xPageUnref(pPage->pRaw);
	}
	return rc;
}
/*
 * Replace method.
 */
static int lhash_kv_replace(
	  unqlite_kv_engine *pKv,
	  const void *pKey,int nKeyLen,
	  const void *pData,unqlite_int64 nDataLen
	  )
{
	int rc;
	rc = lh_record_insert(pKv,pKey,(sxu32)nKeyLen,pData,nDataLen,0);
	return rc;
}
/*
 * Append method.
 */
static int lhash_kv_append(
	  unqlite_kv_engine *pKv,
	  const void *pKey,int nKeyLen,
	  const void *pData,unqlite_int64 nDataLen
	  )
{
	int rc;
	rc = lh_record_insert(pKv,pKey,(sxu32)nKeyLen,pData,nDataLen,1);
	return rc;
}
/*
 * Write the hash header (Page one).
 */
static int lhash_write_header(lhash_kv_engine *pEngine,unqlite_page *pHeader)
{
	unsigned char *zRaw = pHeader->zData;
	lhash_bmap_page *pMap;

	pEngine->pHeader = pHeader;
	/* 4 byte magic number */
	SyBigEndianPack32(zRaw,pEngine->nMagic);
	zRaw += 4;
	/* 4 byte hash value to identify a valid hash function */
	SyBigEndianPack32(zRaw,pEngine->xHash(L_HASH_WORD,sizeof(L_HASH_WORD)-1));
	zRaw += 4;
	/* List of free pages: Empty */
	SyBigEndianPack64(zRaw,0);
	zRaw += 8;
	/* Current split bucket */
	SyBigEndianPack64(zRaw,pEngine->split_bucket);
	zRaw += 8;
	/* Maximum split bucket */
	SyBigEndianPack64(zRaw,pEngine->max_split_bucket);
	zRaw += 8;
	/* Initialize the bucket map */
	pMap = &pEngine->sPageMap;
	/* Fill in the structure */
	pMap->iNum = pHeader->pgno;
	/* Next page in the bucket map */
	SyBigEndianPack64(zRaw,0);
	zRaw += 8;
	/* Total number of records in the bucket map */
	SyBigEndianPack32(zRaw,0);
	zRaw += 4;
	pMap->iPtr = (sxu16)(zRaw - pHeader->zData);
	/* All done */
	return UNQLITE_OK;
 }
/*
 * Exported: xOpen() method.
 */
static int lhash_kv_open(unqlite_kv_engine *pEngine,pgno dbSize)
{
	lhash_kv_engine *pHash = (lhash_kv_engine *)pEngine;
	unqlite_page *pHeader;
	int rc;
	if( dbSize < 1 ){
		/* A new database, create the header */
		rc = pEngine->pIo->xNew(pEngine->pIo->pHandle,&pHeader);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Acquire a writer lock */
		rc = pEngine->pIo->xWrite(pHeader);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Write the hash header */
		rc = lhash_write_header(pHash,pHeader);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}else{
		/* Acquire the page one of the database */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,1,&pHeader);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		/* Read the database header */
		rc = lhash_read_header(pHash,pHeader);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	return UNQLITE_OK;
}
/*
 * Release a master or slave page. (xUnpin callback).
 */
static void lhash_page_release(void *pUserData)
{
	lhpage *pPage = (lhpage *)pUserData;
	lhash_kv_engine *pEngine = pPage->pHash;
	lhcell *pNext,*pCell = pPage->pList;
	unqlite_page *pRaw = pPage->pRaw;
	sxu32 n;
	/* Drop in-memory cells */
	for( n = 0 ; n < pPage->nCell ; ++n ){
		pNext = pCell->pNext;
		SyBlobRelease(&pCell->sKey);
		/* Release the cell instance */
		SyMemBackendPoolFree(&pEngine->sAllocator,(void *)pCell);
		/* Point to the next entry */
		pCell = pNext;
	}
	if( pPage->apCell ){
		/* Release the cell table */
		SyMemBackendFree(&pEngine->sAllocator,(void *)pPage->apCell);
	}
	/* Finally, release the whole page */
	SyMemBackendPoolFree(&pEngine->sAllocator,pPage);
	pRaw->pUserData = 0;
}
/*
 * Default hash function (DJB).
 */
static sxu32 lhash_bin_hash(const void *pSrc,sxu32 nLen)
{
	 unsigned char *zIn = (unsigned char *)pSrc;
	unsigned char *zEnd;
	sxu32 nH = 5381;
	if( nLen > 2048 /* 2K */ ){
		nLen = 2048;
	}
	zEnd = &zIn[nLen];
	for(;;){
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
	}	
	return nH;
}
/*
 * Exported: xInit() method.
 * Initialize the Key value storage engine.
 */
static int lhash_kv_init(unqlite_kv_engine *pEngine,int iPageSize)
{
	lhash_kv_engine *pHash = (lhash_kv_engine *)pEngine;
	int rc;

	/* This structure is always zeroed, go to the initialization directly */
	SyMemBackendInitFromParent(&pHash->sAllocator,unqliteExportMemBackend());
	pHash->iPageSize = iPageSize;
	/* Default hash function */
	pHash->xHash = lhash_bin_hash;
	/* Default comparison function */
	pHash->xCmp = SyMemcmp;
	/* Allocate a new record map */
	pHash->nBuckSize = 32;
	pHash->apMap = (lhash_bmap_rec **)SyMemBackendAlloc(&pHash->sAllocator,pHash->nBuckSize *sizeof(lhash_bmap_rec *));
	if( pHash->apMap == 0 ){
		rc = UNQLITE_NOMEM;
		goto err;
	}
	/* Zero the table */
	SyZero(pHash->apMap,pHash->nBuckSize * sizeof(lhash_bmap_rec *));
	/* Linear hashing components */
	pHash->split_bucket = 0; /* Logical not real bucket number */
	pHash->max_split_bucket = 1;
	pHash->nmax_split_nucket = 2;
	pHash->nMagic = L_HASH_MAGIC;
	/* Install the cache unpin and reload callbacks */
	pHash->pIo->xSetUnpin(pHash->pIo->pHandle,lhash_page_release);
	pHash->pIo->xSetReload(pHash->pIo->pHandle,lhash_page_release);
	return UNQLITE_OK;
err:
	SyMemBackendRelease(&pHash->sAllocator);
	return rc;
}
/*
 * Exported: xRelease() method.
 * Release the Key value storage engine.
 */
static void lhash_kv_release(unqlite_kv_engine *pEngine)
{
	lhash_kv_engine *pHash = (lhash_kv_engine *)pEngine;
	/* Release the private memory backend */
	SyMemBackendRelease(&pHash->sAllocator);
}
/*
 *  Exported: xConfig() method.
 *  Configure the linear hash KV store.
 */
static int lhash_kv_config(unqlite_kv_engine *pEngine,int op,va_list ap)
{
	lhash_kv_engine *pHash = (lhash_kv_engine *)pEngine;
	int rc = UNQLITE_OK;
	switch(op){
	case UNQLITE_KV_CONFIG_HASH_FUNC: {
		/* Default hash function */
		if( pHash->nBuckRec > 0 ){
			/* Locked operation */
			rc = UNQLITE_LOCKED;
		}else{
			ProcHash xHash = va_arg(ap,ProcHash);
			if( xHash ){
				pHash->xHash = xHash;
			}
		}
		break;
									  }
	case UNQLITE_KV_CONFIG_CMP_FUNC: {
		/* Default comparison function */
		ProcCmp xCmp = va_arg(ap,ProcCmp);
		if( xCmp ){
			pHash->xCmp  = xCmp;
		}
		break;
									 }
	default:
		/* Unknown OP */
		rc = UNQLITE_UNKNOWN;
		break;
	}
	return rc;
}
/*
 * Each public cursor is identified by an instance of this structure.
 */
typedef struct lhash_kv_cursor lhash_kv_cursor;
struct lhash_kv_cursor
{
	unqlite_kv_engine *pStore; /* Must be first */
	/* Private fields */
	int iState;           /* Current state of the cursor */
	int is_first;         /* True to read the database header */
	lhcell *pCell;        /* Current cell we are processing */
	unqlite_page *pRaw;   /* Raw disk page */
	lhash_bmap_rec *pRec; /* Logical to real bucket map */
};
/* 
 * Possible state of the cursor
 */
#define L_HASH_CURSOR_STATE_NEXT_PAGE 1 /* Next page in the list */
#define L_HASH_CURSOR_STATE_CELL      2 /* Processing Cell */
#define L_HASH_CURSOR_STATE_DONE      3 /* Cursor does not point to anything */
/*
 * Initialize the cursor.
 */
static void lhInitCursor(unqlite_kv_cursor *pPtr)
{
	 lhash_kv_engine *pEngine = (lhash_kv_engine *)pPtr->pStore;
	 lhash_kv_cursor *pCur = (lhash_kv_cursor *)pPtr;
	 /* Init */
	 pCur->iState = L_HASH_CURSOR_STATE_NEXT_PAGE;
	 pCur->pCell = 0;
	 pCur->pRec = pEngine->pFirst;
	 pCur->pRaw = 0;
	 pCur->is_first = 1;
}
/*
 * Point to the next page on the database.
 */
static int lhCursorNextPage(lhash_kv_cursor *pPtr)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pPtr;
	lhash_bmap_rec *pRec;
	lhpage *pPage;
	int rc;
	for(;;){
		pRec = pCur->pRec;
		if( pRec == 0 ){
			pCur->iState = L_HASH_CURSOR_STATE_DONE;
			return UNQLITE_DONE;
		}
		if( pPtr->iState == L_HASH_CURSOR_STATE_CELL && pPtr->pRaw ){
			/* Unref this page */
			pCur->pStore->pIo->xPageUnref(pPtr->pRaw);
			pPtr->pRaw = 0;
		}
		/* Advance the map cursor */
		pCur->pRec = pRec->pPrev; /* Not a bug, reverse link */
		/* Load the next page on the list */
		rc = lhLoadPage((lhash_kv_engine *)pCur->pStore,pRec->iReal,0,&pPage,0);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		if( pPage->pList ){
			/* Reflect the change */
			pCur->pCell = pPage->pList;
			pCur->iState = L_HASH_CURSOR_STATE_CELL;
			pCur->pRaw = pPage->pRaw;
			break;
		}
		/* Empty page, discard this page and continue */
		pPage->pHash->pIo->xPageUnref(pPage->pRaw);
	}
	return UNQLITE_OK;
}
/*
 * Point to the previous page on the database.
 */
static int lhCursorPrevPage(lhash_kv_cursor *pPtr)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pPtr;
	lhash_bmap_rec *pRec;
	lhpage *pPage;
	int rc;
	for(;;){
		pRec = pCur->pRec;
		if( pRec == 0 ){
			pCur->iState = L_HASH_CURSOR_STATE_DONE;
			return UNQLITE_DONE;
		}
		if( pPtr->iState == L_HASH_CURSOR_STATE_CELL && pPtr->pRaw ){
			/* Unref this page */
			pCur->pStore->pIo->xPageUnref(pPtr->pRaw);
			pPtr->pRaw = 0;
		}
		/* Advance the map cursor */
		pCur->pRec = pRec->pNext; /* Not a bug, reverse link */
		/* Load the previous page on the list */
		rc = lhLoadPage((lhash_kv_engine *)pCur->pStore,pRec->iReal,0,&pPage,0);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		if( pPage->pFirst ){
			/* Reflect the change */
			pCur->pCell = pPage->pFirst;
			pCur->iState = L_HASH_CURSOR_STATE_CELL;
			pCur->pRaw = pPage->pRaw;
			break;
		}
		/* Discard this page and continue */
		pPage->pHash->pIo->xPageUnref(pPage->pRaw);
	}
	return UNQLITE_OK;
}
/*
 * Is a valid cursor.
 */
static int lhCursorValid(unqlite_kv_cursor *pPtr)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pPtr;
	return (pCur->iState == L_HASH_CURSOR_STATE_CELL) && pCur->pCell;
}
/*
 * Point to the first record.
 */
static int lhCursorFirst(unqlite_kv_cursor *pCursor)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhash_kv_engine *pEngine = (lhash_kv_engine *)pCursor->pStore;
	int rc;
	if( pCur->is_first ){
		/* Read the database header first */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,1,0);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		pCur->is_first = 0;
	}
	/* Point to the first map record */
	pCur->pRec = pEngine->pFirst;
	/* Load the cells */
	rc = lhCursorNextPage(pCur);
	return rc;
}
/*
 * Point to the last record.
 */
static int lhCursorLast(unqlite_kv_cursor *pCursor)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhash_kv_engine *pEngine = (lhash_kv_engine *)pCursor->pStore;
	int rc;
	if( pCur->is_first ){
		/* Read the database header first */
		rc = pEngine->pIo->xGet(pEngine->pIo->pHandle,1,0);
		if( rc != UNQLITE_OK ){
			return rc;
		}
		pCur->is_first = 0;
	}
	/* Point to the last map record */
	pCur->pRec = pEngine->pList;
	/* Load the cells */
	rc = lhCursorPrevPage(pCur);
	return rc;
}
/*
 * Reset the cursor.
 */
static void lhCursorReset(unqlite_kv_cursor *pCursor)
{
	lhCursorFirst(pCursor);
}
/*
 * Point to the next record.
 */
static int lhCursorNext(unqlite_kv_cursor *pCursor)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	int rc;
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Load the cells of the next page  */
		rc = lhCursorNextPage(pCur);
		return rc;
	}
	pCell = pCur->pCell;
	pCur->pCell = pCell->pNext;
	if( pCur->pCell == 0 ){
		/* Load the cells of the next page  */
		rc = lhCursorNextPage(pCur);
		return rc;
	}
	return UNQLITE_OK;
}
/*
 * Point to the previous record.
 */
static int lhCursorPrev(unqlite_kv_cursor *pCursor)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	int rc;
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Load the cells of the previous page  */
		rc = lhCursorPrevPage(pCur);
		return rc;
	}
	pCell = pCur->pCell;
	pCur->pCell = pCell->pPrev;
	if( pCur->pCell == 0 ){
		/* Load the cells of the previous page  */
		rc = lhCursorPrevPage(pCur);
		return rc;
	}
	return UNQLITE_OK;
}
/*
 * Return key length.
 */
static int lhCursorKeyLength(unqlite_kv_cursor *pCursor,int *pLen)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Invalid state */
		return UNQLITE_INVALID;
	}
	/* Point to the target cell */
	pCell = pCur->pCell;
	/* Return key length */
	*pLen = (int)pCell->nKey;
	return UNQLITE_OK;
}
/*
 * Return data length.
 */
static int lhCursorDataLength(unqlite_kv_cursor *pCursor,unqlite_int64 *pLen)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Invalid state */
		return UNQLITE_INVALID;
	}
	/* Point to the target cell */
	pCell = pCur->pCell;
	/* Return data length */
	*pLen = (unqlite_int64)pCell->nData;
	return UNQLITE_OK;
}
/*
 * Consume the key.
 */
static int lhCursorKey(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	int rc;
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Invalid state */
		return UNQLITE_INVALID;
	}
	/* Point to the target cell */
	pCell = pCur->pCell;
	if( SyBlobLength(&pCell->sKey) > 0 ){
		/* Consume the key directly */
		rc = xConsumer(SyBlobData(&pCell->sKey),SyBlobLength(&pCell->sKey),pUserData);
	}else{
		/* Very large key */
		rc = lhConsumeCellkey(pCell,xConsumer,pUserData,0);
	}
	return rc;
}
/*
 * Consume the data.
 */
static int lhCursorData(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	int rc;
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Invalid state */
		return UNQLITE_INVALID;
	}
	/* Point to the target cell */
	pCell = pCur->pCell;
	/* Consume the data */
	rc = lhConsumeCellData(pCell,xConsumer,pUserData);
	return rc;
}
/*
 * Find a particular record.
 */
static int lhCursorSeek(unqlite_kv_cursor *pCursor,const void *pKey,int nByte,int iPos)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	int rc;
	/* Perform a lookup */
	rc = lhRecordLookup((lhash_kv_engine *)pCur->pStore,pKey,nByte,&pCur->pCell);
	if( rc != UNQLITE_OK ){
		SXUNUSED(iPos);
		pCur->pCell = 0;
		pCur->iState = L_HASH_CURSOR_STATE_DONE;
		return rc;
	}
	pCur->iState = L_HASH_CURSOR_STATE_CELL;
	return UNQLITE_OK;
}
/*
 * Remove a particular record.
 */
static int lhCursorDelete(unqlite_kv_cursor *pCursor)
{
	lhash_kv_cursor *pCur = (lhash_kv_cursor *)pCursor;
	lhcell *pCell;
	int rc;
	if( pCur->iState != L_HASH_CURSOR_STATE_CELL || pCur->pCell == 0 ){
		/* Invalid state */
		return UNQLITE_INVALID;
	}
	/* Point to the target cell  */
	pCell = pCur->pCell;
	/* Point to the next entry */
	pCur->pCell = pCell->pNext;
	/* Perform the deletion */
	rc = lhRecordRemove(pCell);
	return rc;
}
/*
 * Export the linear-hash storage engine.
 */
UNQLITE_PRIVATE const unqlite_kv_methods * unqliteExportDiskKvStorage(void)
{
	static const unqlite_kv_methods sDiskStore = {
		"hash",                     /* zName */
		sizeof(lhash_kv_engine),    /* szKv */
		sizeof(lhash_kv_cursor),    /* szCursor */
		1,                          /* iVersion */
		lhash_kv_init,              /* xInit */
		lhash_kv_release,           /* xRelease */
		lhash_kv_config,            /* xConfig */
		lhash_kv_open,              /* xOpen */
		lhash_kv_replace,           /* xReplace */
		lhash_kv_append,            /* xAppend */
		lhInitCursor,               /* xCursorInit */
		lhCursorSeek,               /* xSeek */
		lhCursorFirst,              /* xFirst */
		lhCursorLast,               /* xLast */
		lhCursorValid,              /* xValid */
		lhCursorNext,               /* xNext */
		lhCursorPrev,               /* xPrev */
		lhCursorDelete,             /* xDelete */
		lhCursorKeyLength,          /* xKeyLength */
		lhCursorKey,                /* xKey */
		lhCursorDataLength,         /* xDataLength */
		lhCursorData,               /* xData */
		lhCursorReset,              /* xReset */
		0                           /* xRelease */                        
	};
	return &sDiskStore;
}
/*
 * ----------------------------------------------------------
 * File: mem_kv.c
 * ID: 32e2610c95f53038114d9566f0d0489e
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: mem_kv.c v1.7 Win7 2012-11-28 01:41 stable <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* 
 * This file implements an in-memory key value storage engine for unQLite.
 * Note that this storage engine does not support transactions.
 *
 * Normaly, I (chm@symisc.net) planned to implement a red-black tree
 * which is suitable for this kind of operation, but due to the lack
 * of time, I decided to implement a tunned hashtable which everybody
 * know works very well for this kind of operation.
 * Again, I insist on a red-black tree implementation for future version
 * of Unqlite.
 */
/* Forward declaration */
typedef struct mem_hash_kv_engine mem_hash_kv_engine;
/*
 * Each record is storead in an instance of the following structure.
 */
typedef struct mem_hash_record mem_hash_record;
struct mem_hash_record
{
	mem_hash_kv_engine *pEngine;    /* Storage engine */
	sxu32 nHash;                    /* Hash of the key */
	const void *pKey;               /* Key */
	sxu32 nKeyLen;                  /* Key size (Max 1GB) */
	const void *pData;              /* Data */
	sxu32 nDataLen;                 /* Data length (Max 4GB) */
	mem_hash_record *pNext,*pPrev;  /* Link to other records */
	mem_hash_record *pNextHash,*pPrevHash; /* Collision link */
};
/*
 * Each in-memory KV engine is represented by an instance
 * of the following structure.
 */
struct mem_hash_kv_engine
{
	const unqlite_kv_io *pIo; /* IO methods: MUST be first */
	/* Private data */
	SyMemBackend sAlloc;        /* Private memory allocator */
	ProcHash    xHash;          /* Default hash function */
	ProcCmp     xCmp;           /* Default comparison function */
	sxu32 nRecord;              /* Total number of records  */
	sxu32 nBucket;              /* Bucket size: Must be a power of two */
	mem_hash_record **apBucket; /* Hash bucket */
	mem_hash_record *pFirst;    /* First inserted entry */
	mem_hash_record *pLast;     /* Last inserted entry */
};
/*
 * Allocate a new hash record.
 */
static mem_hash_record * MemHashNewRecord(
	mem_hash_kv_engine *pEngine,
	const void *pKey,int nKey,
	const void *pData,unqlite_int64 nData,
	sxu32 nHash
	)
{
	SyMemBackend *pAlloc = &pEngine->sAlloc;
	mem_hash_record *pRecord;
	void *pDupData;
	sxu32 nByte;
	char *zPtr;
	
	/* Total number of bytes to alloc */
	nByte = sizeof(mem_hash_record) + nKey;
	/* Allocate a new instance */
	pRecord = (mem_hash_record *)SyMemBackendAlloc(pAlloc,nByte);
	if( pRecord == 0 ){
		return 0;
	}
	pDupData = (void *)SyMemBackendAlloc(pAlloc,(sxu32)nData);
	if( pDupData == 0 ){
		SyMemBackendFree(pAlloc,pRecord);
		return 0;
	}
	zPtr = (char *)pRecord;
	zPtr += sizeof(mem_hash_record);
	/* Zero the structure */
	SyZero(pRecord,sizeof(mem_hash_record));
	/* Fill in the structure */
	pRecord->pEngine = pEngine;
	pRecord->nDataLen = (sxu32)nData;
	pRecord->nKeyLen = (sxu32)nKey;
	pRecord->nHash = nHash;
	SyMemcpy(pKey,zPtr,pRecord->nKeyLen);
	pRecord->pKey = (const void *)zPtr;
	SyMemcpy(pData,pDupData,pRecord->nDataLen);
	pRecord->pData = pDupData;
	/* All done */
	return pRecord;
}
/*
 * Install a given record in the hashtable.
 */
static void MemHashLinkRecord(mem_hash_kv_engine *pEngine,mem_hash_record *pRecord)
{
	sxu32 nBucket = pRecord->nHash & (pEngine->nBucket - 1);
	pRecord->pNextHash = pEngine->apBucket[nBucket];
	if( pEngine->apBucket[nBucket] ){
		pEngine->apBucket[nBucket]->pPrevHash = pRecord;
	}
	pEngine->apBucket[nBucket] = pRecord;
	if( pEngine->pFirst == 0 ){
		pEngine->pFirst = pEngine->pLast = pRecord;
	}else{
		MACRO_LD_PUSH(pEngine->pLast,pRecord);
	}
	pEngine->nRecord++;
}
/*
 * Unlink a given record from the hashtable.
 */
static void MemHashUnlinkRecord(mem_hash_kv_engine *pEngine,mem_hash_record *pEntry)
{
	sxu32 nBucket = pEntry->nHash & (pEngine->nBucket - 1);
	SyMemBackend *pAlloc = &pEngine->sAlloc;
	if( pEntry->pPrevHash == 0 ){
		pEngine->apBucket[nBucket] = pEntry->pNextHash;
	}else{
		pEntry->pPrevHash->pNextHash = pEntry->pNextHash;
	}
	if( pEntry->pNextHash ){
		pEntry->pNextHash->pPrevHash = pEntry->pPrevHash;
	}
	MACRO_LD_REMOVE(pEngine->pLast,pEntry);
	if( pEntry == pEngine->pFirst ){
		pEngine->pFirst = pEntry->pPrev;
	}
	pEngine->nRecord--;
	/* Release the entry */
	SyMemBackendFree(pAlloc,(void *)pEntry->pData);
	SyMemBackendFree(pAlloc,pEntry); /* Key is also stored here */
}
/*
 * Perform a lookup for a given entry.
 */
static mem_hash_record * MemHashGetEntry(
	mem_hash_kv_engine *pEngine,
	const void *pKey,int nKeyLen
	)
{
	mem_hash_record *pEntry;
	sxu32 nHash,nBucket;
	/* Hash the entry */
	nHash = pEngine->xHash(pKey,(sxu32)nKeyLen);
	nBucket = nHash & (pEngine->nBucket - 1);
	pEntry = pEngine->apBucket[nBucket];
	for(;;){
		if( pEntry == 0 ){
			break;
		}
		if( pEntry->nHash == nHash && pEntry->nKeyLen == (sxu32)nKeyLen && 
			pEngine->xCmp(pEntry->pKey,pKey,pEntry->nKeyLen) == 0 ){
				return pEntry;
		}
		pEntry = pEntry->pNextHash;
	}
	/* No such entry */
	return 0;
}
/*
 * Rehash all the entries in the given table.
 */
static int MemHashGrowTable(mem_hash_kv_engine *pEngine)
{
	sxu32 nNewSize = pEngine->nBucket << 1;
	mem_hash_record *pEntry;
	mem_hash_record **apNew;
	sxu32 n,iBucket;
	/* Allocate a new larger table */
	apNew = (mem_hash_record **)SyMemBackendAlloc(&pEngine->sAlloc, nNewSize * sizeof(mem_hash_record *));
	if( apNew == 0 ){
		/* Not so fatal, simply a performance hit */
		return UNQLITE_OK;
	}
	/* Zero the new table */
	SyZero((void *)apNew, nNewSize * sizeof(mem_hash_record *));
	/* Rehash all entries */
	n = 0;
	pEntry = pEngine->pLast;
	for(;;){
		
		/* Loop one */
		if( n >= pEngine->nRecord ){
			break;
		}
		pEntry->pNextHash = pEntry->pPrevHash = 0;
		/* Install in the new bucket */
		iBucket = pEntry->nHash & (nNewSize - 1);
		pEntry->pNextHash = apNew[iBucket];
		if( apNew[iBucket] ){
			apNew[iBucket]->pPrevHash = pEntry;
		}
		apNew[iBucket] = pEntry;
		/* Point to the next entry */
		pEntry = pEntry->pNext;
		n++;

		/* Loop two */
		if( n >= pEngine->nRecord ){
			break;
		}
		pEntry->pNextHash = pEntry->pPrevHash = 0;
		/* Install in the new bucket */
		iBucket = pEntry->nHash & (nNewSize - 1);
		pEntry->pNextHash = apNew[iBucket];
		if( apNew[iBucket] ){
			apNew[iBucket]->pPrevHash = pEntry;
		}
		apNew[iBucket] = pEntry;
		/* Point to the next entry */
		pEntry = pEntry->pNext;
		n++;

		/* Loop three */
		if( n >= pEngine->nRecord ){
			break;
		}
		pEntry->pNextHash = pEntry->pPrevHash = 0;
		/* Install in the new bucket */
		iBucket = pEntry->nHash & (nNewSize - 1);
		pEntry->pNextHash = apNew[iBucket];
		if( apNew[iBucket] ){
			apNew[iBucket]->pPrevHash = pEntry;
		}
		apNew[iBucket] = pEntry;
		/* Point to the next entry */
		pEntry = pEntry->pNext;
		n++;

		/* Loop four */
		if( n >= pEngine->nRecord ){
			break;
		}
		pEntry->pNextHash = pEntry->pPrevHash = 0;
		/* Install in the new bucket */
		iBucket = pEntry->nHash & (nNewSize - 1);
		pEntry->pNextHash = apNew[iBucket];
		if( apNew[iBucket] ){
			apNew[iBucket]->pPrevHash = pEntry;
		}
		apNew[iBucket] = pEntry;
		/* Point to the next entry */
		pEntry = pEntry->pNext;
		n++;
	}
	/* Release the old table and reflect the change */
	SyMemBackendFree(&pEngine->sAlloc,(void *)pEngine->apBucket);
	pEngine->apBucket = apNew;
	pEngine->nBucket  = nNewSize;
	return UNQLITE_OK;
}
/*
 * Exported Interfaces.
 */
/*
 * Each public cursor is identified by an instance of this structure.
 */
typedef struct mem_hash_cursor mem_hash_cursor;
struct mem_hash_cursor
{
	unqlite_kv_engine *pStore; /* Must be first */
	/* Private fields */
	mem_hash_record *pCur;     /* Current hash record */
};
/*
 * Initialize the cursor.
 */
static void MemHashInitCursor(unqlite_kv_cursor *pCursor)
{
	 mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pCursor->pStore;
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 /* Point to the first inserted entry */
	 pMem->pCur = pEngine->pFirst;
}
/*
 * Point to the first entry.
 */
static int MemHashCursorFirst(unqlite_kv_cursor *pCursor)
{
	 mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pCursor->pStore;
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 pMem->pCur = pEngine->pFirst;
	 return UNQLITE_OK;
}
/*
 * Point to the last entry.
 */
static int MemHashCursorLast(unqlite_kv_cursor *pCursor)
{
	 mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pCursor->pStore;
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 pMem->pCur = pEngine->pLast;
	 return UNQLITE_OK;
}
/*
 * is a Valid Cursor.
 */
static int MemHashCursorValid(unqlite_kv_cursor *pCursor)
{
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 return pMem->pCur != 0 ? 1 : 0;
}
/*
 * Point to the next entry.
 */
static int MemHashCursorNext(unqlite_kv_cursor *pCursor)
{
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 if( pMem->pCur == 0){
		 return UNQLITE_EOF;
	 }
	 pMem->pCur = pMem->pCur->pPrev; /* Reverse link: Not a Bug */
	 return UNQLITE_OK;
}
/*
 * Point to the previous entry.
 */
static int MemHashCursorPrev(unqlite_kv_cursor *pCursor)
{
	 mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	 if( pMem->pCur == 0){
		 return UNQLITE_EOF;
	 }
	 pMem->pCur = pMem->pCur->pNext; /* Reverse link: Not a Bug */
	 return UNQLITE_OK;
}
/*
 * Return key length.
 */
static int MemHashCursorKeyLength(unqlite_kv_cursor *pCursor,int *pLen)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	if( pMem->pCur == 0){
		 return UNQLITE_EOF;
	}
	*pLen = (int)pMem->pCur->nKeyLen;
	return UNQLITE_OK;
}
/*
 * Return data length.
 */
static int MemHashCursorDataLength(unqlite_kv_cursor *pCursor,unqlite_int64 *pLen)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	if( pMem->pCur == 0 ){
		 return UNQLITE_EOF;
	}
	*pLen = pMem->pCur->nDataLen;
	return UNQLITE_OK;
}
/*
 * Consume the key.
 */
static int MemHashCursorKey(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	int rc;
	if( pMem->pCur == 0){
		 return UNQLITE_EOF;
	}
	/* Invoke the callback */
	rc = xConsumer(pMem->pCur->pKey,pMem->pCur->nKeyLen,pUserData);
	/* Callback result */
	return rc;
}
/*
 * Consume the data.
 */
static int MemHashCursorData(unqlite_kv_cursor *pCursor,int (*xConsumer)(const void *,unsigned int,void *),void *pUserData)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	int rc;
	if( pMem->pCur == 0){
		 return UNQLITE_EOF;
	}
	/* Invoke the callback */
	rc = xConsumer(pMem->pCur->pData,pMem->pCur->nDataLen,pUserData);
	/* Callback result */
	return rc;
}
/*
 * Reset the cursor.
 */
static void MemHashCursorReset(unqlite_kv_cursor *pCursor)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	pMem->pCur = ((mem_hash_kv_engine *)pCursor->pStore)->pFirst;
}
/*
 * Remove a particular record.
 */
static int MemHashCursorDelete(unqlite_kv_cursor *pCursor)
{
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	mem_hash_record *pNext;
	if( pMem->pCur == 0 ){
		/* Cursor does not point to anything */
		return UNQLITE_NOTFOUND;
	}
	pNext = pMem->pCur->pPrev;
	/* Perform the deletion */
	MemHashUnlinkRecord(pMem->pCur->pEngine,pMem->pCur);
	/* Point to the next entry */
	pMem->pCur = pNext;
	return UNQLITE_OK;
}
/*
 * Find a particular record.
 */
static int MemHashCursorSeek(unqlite_kv_cursor *pCursor,const void *pKey,int nByte,int iPos)
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pCursor->pStore;
	mem_hash_cursor *pMem = (mem_hash_cursor *)pCursor;
	/* Perform the lookup */
	pMem->pCur = MemHashGetEntry(pEngine,pKey,nByte);
	if( pMem->pCur == 0 ){
		if( iPos != UNQLITE_CURSOR_MATCH_EXACT ){
			/* noop; */
		}
		/* No such record */
		return UNQLITE_NOTFOUND;
	}
	return UNQLITE_OK;
}
/*
 * Builtin hash function.
 */
static sxu32 MemHashFunc(const void *pSrc,sxu32 nLen)
{
	 unsigned char *zIn = (unsigned char *)pSrc;
	unsigned char *zEnd;
	sxu32 nH = 5381;
	zEnd = &zIn[nLen];
	for(;;){
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
		if( zIn >= zEnd ){ break; } nH = nH * 33 + zIn[0] ; zIn++;
	}	
	return nH;
}
/* Default bucket size */
#define MEM_HASH_BUCKET_SIZE 64
/* Default fill factor */
#define MEM_HASH_FILL_FACTOR 4 /* or 3 */
/*
 * Initialize the in-memory storage engine.
 */
static int MemHashInit(unqlite_kv_engine *pKvEngine,int iPageSize)
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pKvEngine;
	/* Note that this instance is already zeroed */	
	/* Memory backend */
	SyMemBackendInitFromParent(&pEngine->sAlloc,unqliteExportMemBackend());
	/* Default hash & comparison function */
	pEngine->xHash = MemHashFunc;
	pEngine->xCmp = SyMemcmp;
	/* Allocate a new bucket */
	pEngine->apBucket = (mem_hash_record **)SyMemBackendAlloc(&pEngine->sAlloc,MEM_HASH_BUCKET_SIZE * sizeof(mem_hash_record *));
	if( pEngine->apBucket == 0 ){
		SXUNUSED(iPageSize); /* cc warning */
		return UNQLITE_NOMEM;
	}
	/* Zero the bucket */
	SyZero(pEngine->apBucket,MEM_HASH_BUCKET_SIZE * sizeof(mem_hash_record *));
	pEngine->nRecord = 0;
	pEngine->nBucket = MEM_HASH_BUCKET_SIZE;
	return UNQLITE_OK;
}
/*
 * Release the in-memory storage engine.
 */
static void MemHashRelease(unqlite_kv_engine *pKvEngine)
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pKvEngine;
	/* Release the private memory backend */
	SyMemBackendRelease(&pEngine->sAlloc);
}
/*
 * Configure the in-memory storage engine.
 */
static int MemHashConfigure(unqlite_kv_engine *pKvEngine,int iOp,va_list ap)
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pKvEngine;
	int rc = UNQLITE_OK;
	switch(iOp){
	case UNQLITE_KV_CONFIG_HASH_FUNC:{
		/* Use a default hash function */
		if( pEngine->nRecord > 0 ){
			rc = UNQLITE_LOCKED;
		}else{
			ProcHash xHash = va_arg(ap,ProcHash);
			if( xHash ){
				pEngine->xHash = xHash;
			}
		}
		break;
									 }
	case UNQLITE_KV_CONFIG_CMP_FUNC: {
		/* Default comparison function */
		ProcCmp xCmp = va_arg(ap,ProcCmp);
		if( xCmp ){
			pEngine->xCmp = xCmp;
		}
		break;
									 }
	default:
		/* Unknown configuration option */
		rc = UNQLITE_UNKNOWN;
	}
	return rc;
}
/*
 * Replace method.
 */
static int MemHashReplace(
	  unqlite_kv_engine *pKv,
	  const void *pKey,int nKeyLen,
	  const void *pData,unqlite_int64 nDataLen
	  )
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pKv;
	mem_hash_record *pRecord;
	if( nDataLen > SXU32_HIGH ){
		/* Database limit */
		pEngine->pIo->xErr(pEngine->pIo->pHandle,"Record size limit reached");
		return UNQLITE_LIMIT;
	}
	/* Fetch the record first */
	pRecord = MemHashGetEntry(pEngine,pKey,nKeyLen);
	if( pRecord == 0 ){
		/* Allocate a new record */
		pRecord = MemHashNewRecord(pEngine,
			pKey,nKeyLen,
			pData,nDataLen,
			pEngine->xHash(pKey,nKeyLen)
			);
		if( pRecord == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Link the entry */
		MemHashLinkRecord(pEngine,pRecord);
		if( (pEngine->nRecord >= pEngine->nBucket * MEM_HASH_FILL_FACTOR) && pEngine->nRecord < 100000 ){
			/* Rehash the table */
			MemHashGrowTable(pEngine);
		}
	}else{
		sxu32 nData = (sxu32)nDataLen;
		void *pNew;
		/* Replace an existing record */
		if( nData == pRecord->nDataLen ){
			/* No need to free the old chunk */
			pNew = (void *)pRecord->pData;
		}else{
			pNew = SyMemBackendAlloc(&pEngine->sAlloc,nData);
			if( pNew == 0 ){
				return UNQLITE_NOMEM;
			}
			/* Release the old data */
			SyMemBackendFree(&pEngine->sAlloc,(void *)pRecord->pData);
		}
		/* Reflect the change */
		pRecord->nDataLen = nData;
		SyMemcpy(pData,pNew,nData);
		pRecord->pData = pNew;
	}
	return UNQLITE_OK;
}
/*
 * Append method.
 */
static int MemHashAppend(
	  unqlite_kv_engine *pKv,
	  const void *pKey,int nKeyLen,
	  const void *pData,unqlite_int64 nDataLen
	  )
{
	mem_hash_kv_engine *pEngine = (mem_hash_kv_engine *)pKv;
	mem_hash_record *pRecord;
	if( nDataLen > SXU32_HIGH ){
		/* Database limit */
		pEngine->pIo->xErr(pEngine->pIo->pHandle,"Record size limit reached");
		return UNQLITE_LIMIT;
	}
	/* Fetch the record first */
	pRecord = MemHashGetEntry(pEngine,pKey,nKeyLen);
	if( pRecord == 0 ){
		/* Allocate a new record */
		pRecord = MemHashNewRecord(pEngine,
			pKey,nKeyLen,
			pData,nDataLen,
			pEngine->xHash(pKey,nKeyLen)
			);
		if( pRecord == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Link the entry */
		MemHashLinkRecord(pEngine,pRecord);
		if( pEngine->nRecord * MEM_HASH_FILL_FACTOR >= pEngine->nBucket && pEngine->nRecord < 100000 ){
			/* Rehash the table */
			MemHashGrowTable(pEngine);
		}
	}else{
		unqlite_int64 nNew = pRecord->nDataLen + nDataLen;
		void *pOld = (void *)pRecord->pData;
		sxu32 nData;
		char *zNew;
		/* Append data to the existing record */
		if( nNew > SXU32_HIGH ){
			/* Overflow */
			pEngine->pIo->xErr(pEngine->pIo->pHandle,"Append operation will cause data overflow");	
			return UNQLITE_LIMIT;
		}
		nData = (sxu32)nNew;
		/* Allocate bigger chunk */
		zNew = (char *)SyMemBackendRealloc(&pEngine->sAlloc,pOld,nData);
		if( zNew == 0 ){
			return UNQLITE_NOMEM;
		}
		/* Reflect the change */
		SyMemcpy(pData,&zNew[pRecord->nDataLen],(sxu32)nDataLen);
		pRecord->pData = (const void *)zNew;
		pRecord->nDataLen = nData;
	}
	return UNQLITE_OK;
}
/*
 * Export the in-memory storage engine.
 */
UNQLITE_PRIVATE const unqlite_kv_methods * unqliteExportMemKvStorage(void)
{
	static const unqlite_kv_methods sMemStore = {
		"mem",                      /* zName */
		sizeof(mem_hash_kv_engine), /* szKv */
		sizeof(mem_hash_cursor),    /* szCursor */
		1,                          /* iVersion */
		MemHashInit,                /* xInit */
		MemHashRelease,             /* xRelease */
		MemHashConfigure,           /* xConfig */
		0,                          /* xOpen */
		MemHashReplace,             /* xReplace */
		MemHashAppend,              /* xAppend */
		MemHashInitCursor,          /* xCursorInit */
		MemHashCursorSeek,          /* xSeek */
		MemHashCursorFirst,         /* xFirst */
		MemHashCursorLast,          /* xLast */
		MemHashCursorValid,         /* xValid */
		MemHashCursorNext,          /* xNext */
		MemHashCursorPrev,          /* xPrev */
		MemHashCursorDelete,        /* xDelete */
		MemHashCursorKeyLength,     /* xKeyLength */
		MemHashCursorKey,           /* xKey */
		MemHashCursorDataLength,    /* xDataLength */
		MemHashCursorData,          /* xData */
		MemHashCursorReset,         /* xReset */
		0        /* xRelease */                        
	};
	return &sMemStore;
}
/*
 * ----------------------------------------------------------
 * File: os.c
 * ID: e7ad243c3cd9e6aac5fba406eedb7766
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: os.c v1.0 FreeBSD 2012-11-12 21:27 devel <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* OS interfaces abstraction layers: Mostly SQLite3 source tree */
/*
** The following routines are convenience wrappers around methods
** of the unqlite_file object.  This is mostly just syntactic sugar. All
** of this would be completely automatic if UnQLite were coded using
** C++ instead of plain old C.
*/
UNQLITE_PRIVATE int unqliteOsRead(unqlite_file *id, void *pBuf, unqlite_int64 amt, unqlite_int64 offset)
{
  return id->pMethods->xRead(id, pBuf, amt, offset);
}
UNQLITE_PRIVATE int unqliteOsWrite(unqlite_file *id, const void *pBuf, unqlite_int64 amt, unqlite_int64 offset)
{
  return id->pMethods->xWrite(id, pBuf, amt, offset);
}
UNQLITE_PRIVATE int unqliteOsTruncate(unqlite_file *id, unqlite_int64 size)
{
  return id->pMethods->xTruncate(id, size);
}
UNQLITE_PRIVATE int unqliteOsSync(unqlite_file *id, int flags)
{
  return id->pMethods->xSync(id, flags);
}
UNQLITE_PRIVATE int unqliteOsFileSize(unqlite_file *id, unqlite_int64 *pSize)
{
  return id->pMethods->xFileSize(id, pSize);
}
UNQLITE_PRIVATE int unqliteOsLock(unqlite_file *id, int lockType)
{
  return id->pMethods->xLock(id, lockType);
}
UNQLITE_PRIVATE int unqliteOsUnlock(unqlite_file *id, int lockType)
{
  return id->pMethods->xUnlock(id, lockType);
}
UNQLITE_PRIVATE int unqliteOsCheckReservedLock(unqlite_file *id, int *pResOut)
{
  return id->pMethods->xCheckReservedLock(id, pResOut);
}
UNQLITE_PRIVATE int unqliteOsSectorSize(unqlite_file *id)
{
  if( id->pMethods->xSectorSize ){
	  return id->pMethods->xSectorSize(id);
  }
  return  UNQLITE_DEFAULT_SECTOR_SIZE;
}
/*
** The next group of routines are convenience wrappers around the
** VFS methods.
*/
UNQLITE_PRIVATE int unqliteOsOpen(
  unqlite_vfs *pVfs,
  SyMemBackend *pAlloc,
  const char *zPath, 
  unqlite_file **ppOut, 
  unsigned int flags 
)
{
	unqlite_file *pFile;
	int rc;
	*ppOut = 0;
	if( zPath == 0 ){
		/* May happen if dealing with an in-memory database */
		return SXERR_EMPTY;
	}
	/* Allocate a new instance */
	pFile = (unqlite_file *)SyMemBackendAlloc(pAlloc,sizeof(unqlite_file)+pVfs->szOsFile);
	if( pFile == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pFile,sizeof(unqlite_file)+pVfs->szOsFile);
	/* Invoke the xOpen method of the underlying VFS */
	rc = pVfs->xOpen(pVfs, zPath, pFile, flags);
	if( rc != UNQLITE_OK ){
		SyMemBackendFree(pAlloc,pFile);
		pFile = 0;
	}
	*ppOut = pFile;
	return rc;
}
UNQLITE_PRIVATE int unqliteOsCloseFree(SyMemBackend *pAlloc,unqlite_file *pId)
{
	int rc = UNQLITE_OK;
	if( pId ){
		rc = pId->pMethods->xClose(pId);
		SyMemBackendFree(pAlloc,pId);
	}
	return rc;
}
UNQLITE_PRIVATE int unqliteOsDelete(unqlite_vfs *pVfs, const char *zPath, int dirSync){
  return pVfs->xDelete(pVfs, zPath, dirSync);
}
UNQLITE_PRIVATE int unqliteOsAccess(
  unqlite_vfs *pVfs, 
  const char *zPath, 
  int flags, 
  int *pResOut
){
  return pVfs->xAccess(pVfs, zPath, flags, pResOut);
}
/*
 * ----------------------------------------------------------
 * File: os_unix.c
 * ID: 5efd57d03f8fb988d081c5bcf5cc2998
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: os_unix.c v1.3 FreeBSD 2013-04-05 01:10 devel <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* 
 * Omit the whole layer from the build if compiling for platforms other than Unix (Linux, BSD, Solaris, OS X, etc.).
 * Note: Mostly SQLite3 source tree.
 */
#if defined(__UNIXES__)
/** This file contains the VFS implementation for unix-like operating systems
** include Linux, MacOSX, *BSD, QNX, VxWorks, AIX, HPUX, and others.
**
** There are actually several different VFS implementations in this file.
** The differences are in the way that file locking is done.  The default
** implementation uses Posix Advisory Locks.  Alternative implementations
** use flock(), dot-files, various proprietary locking schemas, or simply
** skip locking all together.
**
** This source file is organized into divisions where the logic for various
** subfunctions is contained within the appropriate division.  PLEASE
** KEEP THE STRUCTURE OF THIS FILE INTACT.  New code should be placed
** in the correct division and should be clearly labeled.
**
*/
/*
** standard include files.
*/
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <errno.h>
#if defined(__APPLE__) 
# include <sys/mount.h>
#endif
/*
** Allowed values of unixFile.fsFlags
*/
#define UNQLITE_FSFLAGS_IS_MSDOS     0x1

/*
** Default permissions when creating a new file
*/
#ifndef UNQLITE_DEFAULT_FILE_PERMISSIONS
# define UNQLITE_DEFAULT_FILE_PERMISSIONS 0644
#endif
/*
 ** Default permissions when creating auto proxy dir
 */
#ifndef UNQLITE_DEFAULT_PROXYDIR_PERMISSIONS
# define UNQLITE_DEFAULT_PROXYDIR_PERMISSIONS 0755
#endif
/*
** Maximum supported path-length.
*/
#define MAX_PATHNAME 512
/*
** Only set the lastErrno if the error code is a real error and not 
** a normal expected return code of UNQLITE_BUSY or UNQLITE_OK
*/
#define IS_LOCK_ERROR(x)  ((x != UNQLITE_OK) && (x != UNQLITE_BUSY))
/* Forward references */
typedef struct unixInodeInfo unixInodeInfo;   /* An i-node */
typedef struct UnixUnusedFd UnixUnusedFd;     /* An unused file descriptor */
/*
** Sometimes, after a file handle is closed by SQLite, the file descriptor
** cannot be closed immediately. In these cases, instances of the following
** structure are used to store the file descriptor while waiting for an
** opportunity to either close or reuse it.
*/
struct UnixUnusedFd {
  int fd;                   /* File descriptor to close */
  int flags;                /* Flags this file descriptor was opened with */
  UnixUnusedFd *pNext;      /* Next unused file descriptor on same file */
};
/*
** The unixFile structure is subclass of unqlite3_file specific to the unix
** VFS implementations.
*/
typedef struct unixFile unixFile;
struct unixFile {
  const unqlite_io_methods *pMethod;  /* Always the first entry */
  unixInodeInfo *pInode;              /* Info about locks on this inode */
  int h;                              /* The file descriptor */
  int dirfd;                          /* File descriptor for the directory */
  unsigned char eFileLock;            /* The type of lock held on this fd */
  int lastErrno;                      /* The unix errno from last I/O error */
  void *lockingContext;               /* Locking style specific state */
  UnixUnusedFd *pUnused;              /* Pre-allocated UnixUnusedFd */
  int fileFlags;                      /* Miscellanous flags */
  const char *zPath;                  /* Name of the file */
  unsigned fsFlags;                   /* cached details from statfs() */
};
/*
** The following macros define bits in unixFile.fileFlags
*/
#define UNQLITE_WHOLE_FILE_LOCKING  0x0001   /* Use whole-file locking */
/*
** Define various macros that are missing from some systems.
*/
#ifndef O_LARGEFILE
# define O_LARGEFILE 0
#endif
#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif
#ifndef O_BINARY
# define O_BINARY 0
#endif
/*
** Helper functions to obtain and relinquish the global mutex. The
** global mutex is used to protect the unixInodeInfo and
** vxworksFileId objects used by this file, all of which may be 
** shared by multiple threads.
**
** Function unixMutexHeld() is used to assert() that the global mutex 
** is held when required. This function is only used as part of assert() 
** statements. e.g.
**
**   unixEnterMutex()
**     assert( unixMutexHeld() );
**   unixEnterLeave()
*/
static void unixEnterMutex(void){
#ifdef UNQLITE_ENABLE_THREADS
	const SyMutexMethods *pMutexMethods = SyMutexExportMethods();
	if( pMutexMethods ){
		SyMutex *pMutex = pMutexMethods->xNew(SXMUTEX_TYPE_STATIC_2); /* pre-allocated, never fail */
		SyMutexEnter(pMutexMethods,pMutex);
	}
#endif /* UNQLITE_ENABLE_THREADS */
}
static void unixLeaveMutex(void){
#ifdef UNQLITE_ENABLE_THREADS
  const SyMutexMethods *pMutexMethods = SyMutexExportMethods();
  if( pMutexMethods ){
	 SyMutex *pMutex = pMutexMethods->xNew(SXMUTEX_TYPE_STATIC_2); /* pre-allocated, never fail */
	 SyMutexLeave(pMutexMethods,pMutex);
  }
#endif /* UNQLITE_ENABLE_THREADS */
}
/*
** This routine translates a standard POSIX errno code into something
** useful to the clients of the unqlite3 functions.  Specifically, it is
** intended to translate a variety of "try again" errors into UNQLITE_BUSY
** and a variety of "please close the file descriptor NOW" errors into 
** UNQLITE_IOERR
** 
** Errors during initialization of locks, or file system support for locks,
** should handle ENOLCK, ENOTSUP, EOPNOTSUPP separately.
*/
static int unqliteErrorFromPosixError(int posixError, int unqliteIOErr) {
  switch (posixError) {
  case 0: 
    return UNQLITE_OK;
    
  case EAGAIN:
  case ETIMEDOUT:
  case EBUSY:
  case EINTR:
  case ENOLCK:  
    /* random NFS retry error, unless during file system support 
     * introspection, in which it actually means what it says */
    return UNQLITE_BUSY;
 
  case EACCES: 
    /* EACCES is like EAGAIN during locking operations, but not any other time*/
      return UNQLITE_BUSY;
    
  case EPERM: 
    return UNQLITE_PERM;
    
  case EDEADLK:
    return UNQLITE_IOERR;
    
#if EOPNOTSUPP!=ENOTSUP
  case EOPNOTSUPP: 
    /* something went terribly awry, unless during file system support 
     * introspection, in which it actually means what it says */
#endif
#ifdef ENOTSUP
  case ENOTSUP: 
    /* invalid fd, unless during file system support introspection, in which 
     * it actually means what it says */
#endif
  case EIO:
  case EBADF:
  case EINVAL:
  case ENOTCONN:
  case ENODEV:
  case ENXIO:
  case ENOENT:
  case ESTALE:
  case ENOSYS:
    /* these should force the client to close the file and reconnect */
    
  default: 
    return unqliteIOErr;
  }
}
/******************************************************************************
*************************** Posix Advisory Locking ****************************
**
** POSIX advisory locks are broken by design.  ANSI STD 1003.1 (1996)
** section 6.5.2.2 lines 483 through 490 specify that when a process
** sets or clears a lock, that operation overrides any prior locks set
** by the same process.  It does not explicitly say so, but this implies
** that it overrides locks set by the same process using a different
** file descriptor.  Consider this test case:
**
**       int fd1 = open("./file1", O_RDWR|O_CREAT, 0644);
**       int fd2 = open("./file2", O_RDWR|O_CREAT, 0644);
**
** Suppose ./file1 and ./file2 are really the same file (because
** one is a hard or symbolic link to the other) then if you set
** an exclusive lock on fd1, then try to get an exclusive lock
** on fd2, it works.  I would have expected the second lock to
** fail since there was already a lock on the file due to fd1.
** But not so.  Since both locks came from the same process, the
** second overrides the first, even though they were on different
** file descriptors opened on different file names.
**
** This means that we cannot use POSIX locks to synchronize file access
** among competing threads of the same process.  POSIX locks will work fine
** to synchronize access for threads in separate processes, but not
** threads within the same process.
**
** To work around the problem, SQLite has to manage file locks internally
** on its own.  Whenever a new database is opened, we have to find the
** specific inode of the database file (the inode is determined by the
** st_dev and st_ino fields of the stat structure that fstat() fills in)
** and check for locks already existing on that inode.  When locks are
** created or removed, we have to look at our own internal record of the
** locks to see if another thread has previously set a lock on that same
** inode.
**
** (Aside: The use of inode numbers as unique IDs does not work on VxWorks.
** For VxWorks, we have to use the alternative unique ID system based on
** canonical filename and implemented in the previous division.)
**
** There is one locking structure
** per inode, so if the same inode is opened twice, both unixFile structures
** point to the same locking structure.  The locking structure keeps
** a reference count (so we will know when to delete it) and a "cnt"
** field that tells us its internal lock status.  cnt==0 means the
** file is unlocked.  cnt==-1 means the file has an exclusive lock.
** cnt>0 means there are cnt shared locks on the file.
**
** Any attempt to lock or unlock a file first checks the locking
** structure.  The fcntl() system call is only invoked to set a 
** POSIX lock if the internal lock structure transitions between
** a locked and an unlocked state.
**
** But wait:  there are yet more problems with POSIX advisory locks.
**
** If you close a file descriptor that points to a file that has locks,
** all locks on that file that are owned by the current process are
** released.  To work around this problem, each unixInodeInfo object
** maintains a count of the number of pending locks on that inode.
** When an attempt is made to close an unixFile, if there are
** other unixFile open on the same inode that are holding locks, the call
** to close() the file descriptor is deferred until all of the locks clear.
** The unixInodeInfo structure keeps a list of file descriptors that need to
** be closed and that list is walked (and cleared) when the last lock
** clears.
**
** Yet another problem:  LinuxThreads do not play well with posix locks.
**
** Many older versions of linux use the LinuxThreads library which is
** not posix compliant.  Under LinuxThreads, a lock created by thread
** A cannot be modified or overridden by a different thread B.
** Only thread A can modify the lock.  Locking behavior is correct
** if the appliation uses the newer Native Posix Thread Library (NPTL)
** on linux - with NPTL a lock created by thread A can override locks
** in thread B.  But there is no way to know at compile-time which
** threading library is being used.  So there is no way to know at
** compile-time whether or not thread A can override locks on thread B.
** One has to do a run-time check to discover the behavior of the
** current process.
**
*/

/*
** An instance of the following structure serves as the key used
** to locate a particular unixInodeInfo object.
*/
struct unixFileId {
  dev_t dev;                  /* Device number */
  ino_t ino;                  /* Inode number */
};
/*
** An instance of the following structure is allocated for each open
** inode.  Or, on LinuxThreads, there is one of these structures for
** each inode opened by each thread.
**
** A single inode can have multiple file descriptors, so each unixFile
** structure contains a pointer to an instance of this object and this
** object keeps a count of the number of unixFile pointing to it.
*/
struct unixInodeInfo {
  struct unixFileId fileId;       /* The lookup key */
  int nShared;                    /* Number of SHARED locks held */
  int eFileLock;                  /* One of SHARED_LOCK, RESERVED_LOCK etc. */
  int nRef;                       /* Number of pointers to this structure */
  int nLock;                      /* Number of outstanding file locks */
  UnixUnusedFd *pUnused;          /* Unused file descriptors to close */
  unixInodeInfo *pNext;           /* List of all unixInodeInfo objects */
  unixInodeInfo *pPrev;           /*    .... doubly linked */
};

static unixInodeInfo *inodeList = 0;
/*
 * Local memory allocation stuff.
 */
void * unqlite_malloc(unsigned int nByte)
{
	SyMemBackend *pAlloc;
	void *p;
	pAlloc = (SyMemBackend *)unqliteExportMemBackend();
	p = SyMemBackendAlloc(pAlloc,nByte);
	return p;
}
void unqlite_free(void *p)
{
	SyMemBackend *pAlloc;
	pAlloc = (SyMemBackend *)unqliteExportMemBackend();
	SyMemBackendFree(pAlloc,p);
}
/*
** Close all file descriptors accumuated in the unixInodeInfo->pUnused list.
** If all such file descriptors are closed without error, the list is
** cleared and UNQLITE_OK returned.
**
** Otherwise, if an error occurs, then successfully closed file descriptor
** entries are removed from the list, and UNQLITE_IOERR_CLOSE returned. 
** not deleted and UNQLITE_IOERR_CLOSE returned.
*/ 
static int closePendingFds(unixFile *pFile){
  int rc = UNQLITE_OK;
  unixInodeInfo *pInode = pFile->pInode;
  UnixUnusedFd *pError = 0;
  UnixUnusedFd *p;
  UnixUnusedFd *pNext;
  for(p=pInode->pUnused; p; p=pNext){
    pNext = p->pNext;
    if( close(p->fd) ){
      pFile->lastErrno = errno;
	  rc = UNQLITE_IOERR;
      p->pNext = pError;
      pError = p;
    }else{
      unqlite_free(p);
    }
  }
  pInode->pUnused = pError;
  return rc;
}
/*
** Release a unixInodeInfo structure previously allocated by findInodeInfo().
**
** The mutex entered using the unixEnterMutex() function must be held
** when this function is called.
*/
static void releaseInodeInfo(unixFile *pFile){
  unixInodeInfo *pInode = pFile->pInode;
  if( pInode ){
    pInode->nRef--;
    if( pInode->nRef==0 ){
      closePendingFds(pFile);
      if( pInode->pPrev ){
        pInode->pPrev->pNext = pInode->pNext;
      }else{
        inodeList = pInode->pNext;
      }
      if( pInode->pNext ){
        pInode->pNext->pPrev = pInode->pPrev;
      }
      unqlite_free(pInode);
    }
  }
}
/*
** Given a file descriptor, locate the unixInodeInfo object that
** describes that file descriptor.  Create a new one if necessary.  The
** return value might be uninitialized if an error occurs.
**
** The mutex entered using the unixEnterMutex() function must be held
** when this function is called.
**
** Return an appropriate error code.
*/
static int findInodeInfo(
  unixFile *pFile,               /* Unix file with file desc used in the key */
  unixInodeInfo **ppInode        /* Return the unixInodeInfo object here */
){
  int rc;                        /* System call return code */
  int fd;                        /* The file descriptor for pFile */
  struct unixFileId fileId;      /* Lookup key for the unixInodeInfo */
  struct stat statbuf;           /* Low-level file information */
  unixInodeInfo *pInode = 0;     /* Candidate unixInodeInfo object */

  /* Get low-level information about the file that we can used to
  ** create a unique name for the file.
  */
  fd = pFile->h;
  rc = fstat(fd, &statbuf);
  if( rc!=0 ){
    pFile->lastErrno = errno;
#ifdef EOVERFLOW
	if( pFile->lastErrno==EOVERFLOW ) return UNQLITE_NOTIMPLEMENTED;
#endif
    return UNQLITE_IOERR;
  }

#ifdef __APPLE__
  /* On OS X on an msdos filesystem, the inode number is reported
  ** incorrectly for zero-size files.  See ticket #3260.  To work
  ** around this problem (we consider it a bug in OS X, not SQLite)
  ** we always increase the file size to 1 by writing a single byte
  ** prior to accessing the inode number.  The one byte written is
  ** an ASCII 'S' character which also happens to be the first byte
  ** in the header of every SQLite database.  In this way, if there
  ** is a race condition such that another thread has already populated
  ** the first page of the database, no damage is done.
  */
  if( statbuf.st_size==0 && (pFile->fsFlags & UNQLITE_FSFLAGS_IS_MSDOS)!=0 ){
    rc = write(fd, "S", 1);
    if( rc!=1 ){
      pFile->lastErrno = errno;
      return UNQLITE_IOERR;
    }
    rc = fstat(fd, &statbuf);
    if( rc!=0 ){
      pFile->lastErrno = errno;
      return UNQLITE_IOERR;
    }
  }
#endif
  SyZero(&fileId,sizeof(fileId));
  fileId.dev = statbuf.st_dev;
  fileId.ino = statbuf.st_ino;
  pInode = inodeList;
  while( pInode && SyMemcmp((const void *)&fileId,(const void *)&pInode->fileId, sizeof(fileId)) ){
    pInode = pInode->pNext;
  }
  if( pInode==0 ){
    pInode = (unixInodeInfo *)unqlite_malloc( sizeof(*pInode) );
    if( pInode==0 ){
      return UNQLITE_NOMEM;
    }
    SyZero(pInode,sizeof(*pInode));
	SyMemcpy((const void *)&fileId,(void *)&pInode->fileId,sizeof(fileId));
    pInode->nRef = 1;
    pInode->pNext = inodeList;
    pInode->pPrev = 0;
    if( inodeList ) inodeList->pPrev = pInode;
    inodeList = pInode;
  }else{
    pInode->nRef++;
  }
  *ppInode = pInode;
  return UNQLITE_OK;
}
/*
** This routine checks if there is a RESERVED lock held on the specified
** file by this or any other process. If such a lock is held, set *pResOut
** to a non-zero value otherwise *pResOut is set to zero.  The return value
** is set to UNQLITE_OK unless an I/O error occurs during lock checking.
*/
static int unixCheckReservedLock(unqlite_file *id, int *pResOut){
  int rc = UNQLITE_OK;
  int reserved = 0;
  unixFile *pFile = (unixFile*)id;

 
  unixEnterMutex(); /* Because pFile->pInode is shared across threads */

  /* Check if a thread in this process holds such a lock */
  if( pFile->pInode->eFileLock>SHARED_LOCK ){
    reserved = 1;
  }

  /* Otherwise see if some other process holds it.
  */
  if( !reserved ){
    struct flock lock;
    lock.l_whence = SEEK_SET;
    lock.l_start = RESERVED_BYTE;
    lock.l_len = 1;
    lock.l_type = F_WRLCK;
    if (-1 == fcntl(pFile->h, F_GETLK, &lock)) {
      int tErrno = errno;
	  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
      pFile->lastErrno = tErrno;
    } else if( lock.l_type!=F_UNLCK ){
      reserved = 1;
    }
  }
  
  unixLeaveMutex();
 
  *pResOut = reserved;
  return rc;
}
/*
** Lock the file with the lock specified by parameter eFileLock - one
** of the following:
**
**     (1) SHARED_LOCK
**     (2) RESERVED_LOCK
**     (3) PENDING_LOCK
**     (4) EXCLUSIVE_LOCK
**
** Sometimes when requesting one lock state, additional lock states
** are inserted in between.  The locking might fail on one of the later
** transitions leaving the lock state different from what it started but
** still short of its goal.  The following chart shows the allowed
** transitions and the inserted intermediate states:
**
**    UNLOCKED -> SHARED
**    SHARED -> RESERVED
**    SHARED -> (PENDING) -> EXCLUSIVE
**    RESERVED -> (PENDING) -> EXCLUSIVE
**    PENDING -> EXCLUSIVE
**
** This routine will only increase a lock.  Use the unqliteOsUnlock()
** routine to lower a locking level.
*/
static int unixLock(unqlite_file *id, int eFileLock){
  /* The following describes the implementation of the various locks and
  ** lock transitions in terms of the POSIX advisory shared and exclusive
  ** lock primitives (called read-locks and write-locks below, to avoid
  ** confusion with SQLite lock names). The algorithms are complicated
  ** slightly in order to be compatible with unixdows systems simultaneously
  ** accessing the same database file, in case that is ever required.
  **
  ** Symbols defined in os.h indentify the 'pending byte' and the 'reserved
  ** byte', each single bytes at well known offsets, and the 'shared byte
  ** range', a range of 510 bytes at a well known offset.
  **
  ** To obtain a SHARED lock, a read-lock is obtained on the 'pending
  ** byte'.  If this is successful, a random byte from the 'shared byte
  ** range' is read-locked and the lock on the 'pending byte' released.
  **
  ** A process may only obtain a RESERVED lock after it has a SHARED lock.
  ** A RESERVED lock is implemented by grabbing a write-lock on the
  ** 'reserved byte'. 
  **
  ** A process may only obtain a PENDING lock after it has obtained a
  ** SHARED lock. A PENDING lock is implemented by obtaining a write-lock
  ** on the 'pending byte'. This ensures that no new SHARED locks can be
  ** obtained, but existing SHARED locks are allowed to persist. A process
  ** does not have to obtain a RESERVED lock on the way to a PENDING lock.
  ** This property is used by the algorithm for rolling back a journal file
  ** after a crash.
  **
  ** An EXCLUSIVE lock, obtained after a PENDING lock is held, is
  ** implemented by obtaining a write-lock on the entire 'shared byte
  ** range'. Since all other locks require a read-lock on one of the bytes
  ** within this range, this ensures that no other locks are held on the
  ** database. 
  **
  ** The reason a single byte cannot be used instead of the 'shared byte
  ** range' is that some versions of unixdows do not support read-locks. By
  ** locking a random byte from a range, concurrent SHARED locks may exist
  ** even if the locking primitive used is always a write-lock.
  */
  int rc = UNQLITE_OK;
  unixFile *pFile = (unixFile*)id;
  unixInodeInfo *pInode = pFile->pInode;
  struct flock lock;
  int s = 0;
  int tErrno = 0;

  /* If there is already a lock of this type or more restrictive on the
  ** unixFile, do nothing. Don't use the end_lock: exit path, as
  ** unixEnterMutex() hasn't been called yet.
  */
  if( pFile->eFileLock>=eFileLock ){
    return UNQLITE_OK;
  }
  /* This mutex is needed because pFile->pInode is shared across threads
  */
  unixEnterMutex();
  pInode = pFile->pInode;

  /* If some thread using this PID has a lock via a different unixFile*
  ** handle that precludes the requested lock, return BUSY.
  */
  if( (pFile->eFileLock!=pInode->eFileLock && 
          (pInode->eFileLock>=PENDING_LOCK || eFileLock>SHARED_LOCK))
  ){
    rc = UNQLITE_BUSY;
    goto end_lock;
  }

  /* If a SHARED lock is requested, and some thread using this PID already
  ** has a SHARED or RESERVED lock, then increment reference counts and
  ** return UNQLITE_OK.
  */
  if( eFileLock==SHARED_LOCK && 
      (pInode->eFileLock==SHARED_LOCK || pInode->eFileLock==RESERVED_LOCK) ){
    pFile->eFileLock = SHARED_LOCK;
    pInode->nShared++;
    pInode->nLock++;
    goto end_lock;
  }
  /* A PENDING lock is needed before acquiring a SHARED lock and before
  ** acquiring an EXCLUSIVE lock.  For the SHARED lock, the PENDING will
  ** be released.
  */
  lock.l_len = 1L;
  lock.l_whence = SEEK_SET;
  if( eFileLock==SHARED_LOCK 
      || (eFileLock==EXCLUSIVE_LOCK && pFile->eFileLock<PENDING_LOCK)
  ){
    lock.l_type = (eFileLock==SHARED_LOCK?F_RDLCK:F_WRLCK);
    lock.l_start = PENDING_BYTE;
    s = fcntl(pFile->h, F_SETLK, &lock);
    if( s==(-1) ){
      tErrno = errno;
      rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
      if( IS_LOCK_ERROR(rc) ){
        pFile->lastErrno = tErrno;
      }
      goto end_lock;
    }
  }
  /* If control gets to this point, then actually go ahead and make
  ** operating system calls for the specified lock.
  */
  if( eFileLock==SHARED_LOCK ){
    /* Now get the read-lock */
    lock.l_start = SHARED_FIRST;
    lock.l_len = SHARED_SIZE;
    if( (s = fcntl(pFile->h, F_SETLK, &lock))==(-1) ){
      tErrno = errno;
    }
    /* Drop the temporary PENDING lock */
    lock.l_start = PENDING_BYTE;
    lock.l_len = 1L;
    lock.l_type = F_UNLCK;
    if( fcntl(pFile->h, F_SETLK, &lock)!=0 ){
      if( s != -1 ){
        /* This could happen with a network mount */
        tErrno = errno; 
        rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR); 
        if( IS_LOCK_ERROR(rc) ){
          pFile->lastErrno = tErrno;
        }
        goto end_lock;
      }
    }
    if( s==(-1) ){
		rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
      if( IS_LOCK_ERROR(rc) ){
        pFile->lastErrno = tErrno;
      }
    }else{
      pFile->eFileLock = SHARED_LOCK;
      pInode->nLock++;
      pInode->nShared = 1;
    }
  }else if( eFileLock==EXCLUSIVE_LOCK && pInode->nShared>1 ){
    /* We are trying for an exclusive lock but another thread in this
    ** same process is still holding a shared lock. */
    rc = UNQLITE_BUSY;
  }else{
    /* The request was for a RESERVED or EXCLUSIVE lock.  It is
    ** assumed that there is a SHARED or greater lock on the file
    ** already.
    */
    lock.l_type = F_WRLCK;
    switch( eFileLock ){
      case RESERVED_LOCK:
        lock.l_start = RESERVED_BYTE;
        break;
      case EXCLUSIVE_LOCK:
        lock.l_start = SHARED_FIRST;
        lock.l_len = SHARED_SIZE;
        break;
      default:
		  /* Can't happen */
        break;
    }
    s = fcntl(pFile->h, F_SETLK, &lock);
    if( s==(-1) ){
      tErrno = errno;
      rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
      if( IS_LOCK_ERROR(rc) ){
        pFile->lastErrno = tErrno;
      }
    }
  }
  if( rc==UNQLITE_OK ){
    pFile->eFileLock = eFileLock;
    pInode->eFileLock = eFileLock;
  }else if( eFileLock==EXCLUSIVE_LOCK ){
    pFile->eFileLock = PENDING_LOCK;
    pInode->eFileLock = PENDING_LOCK;
  }
end_lock:
  unixLeaveMutex();
  return rc;
}
/*
** Add the file descriptor used by file handle pFile to the corresponding
** pUnused list.
*/
static void setPendingFd(unixFile *pFile){
  unixInodeInfo *pInode = pFile->pInode;
  UnixUnusedFd *p = pFile->pUnused;
  p->pNext = pInode->pUnused;
  pInode->pUnused = p;
  pFile->h = -1;
  pFile->pUnused = 0;
}
/*
** Lower the locking level on file descriptor pFile to eFileLock.  eFileLock
** must be either NO_LOCK or SHARED_LOCK.
**
** If the locking level of the file descriptor is already at or below
** the requested locking level, this routine is a no-op.
** 
** If handleNFSUnlock is true, then on downgrading an EXCLUSIVE_LOCK to SHARED
** the byte range is divided into 2 parts and the first part is unlocked then
** set to a read lock, then the other part is simply unlocked.  This works 
** around a bug in BSD NFS lockd (also seen on MacOSX 10.3+) that fails to 
** remove the write lock on a region when a read lock is set.
*/
static int _posixUnlock(unqlite_file *id, int eFileLock, int handleNFSUnlock){
  unixFile *pFile = (unixFile*)id;
  unixInodeInfo *pInode;
  struct flock lock;
  int rc = UNQLITE_OK;
  int h;
  int tErrno;                      /* Error code from system call errors */

   if( pFile->eFileLock<=eFileLock ){
    return UNQLITE_OK;
  }
  unixEnterMutex();
  
  h = pFile->h;
  pInode = pFile->pInode;
  
  if( pFile->eFileLock>SHARED_LOCK ){
    /* downgrading to a shared lock on NFS involves clearing the write lock
    ** before establishing the readlock - to avoid a race condition we downgrade
    ** the lock in 2 blocks, so that part of the range will be covered by a 
    ** write lock until the rest is covered by a read lock:
    **  1:   [WWWWW]
    **  2:   [....W]
    **  3:   [RRRRW]
    **  4:   [RRRR.]
    */
    if( eFileLock==SHARED_LOCK ){
      if( handleNFSUnlock ){
        off_t divSize = SHARED_SIZE - 1;
        
        lock.l_type = F_UNLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = SHARED_FIRST;
        lock.l_len = divSize;
        if( fcntl(h, F_SETLK, &lock)==(-1) ){
          tErrno = errno;
		  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
          if( IS_LOCK_ERROR(rc) ){
            pFile->lastErrno = tErrno;
          }
          goto end_unlock;
        }
        lock.l_type = F_RDLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = SHARED_FIRST;
        lock.l_len = divSize;
        if( fcntl(h, F_SETLK, &lock)==(-1) ){
          tErrno = errno;
		  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
          if( IS_LOCK_ERROR(rc) ){
            pFile->lastErrno = tErrno;
          }
          goto end_unlock;
        }
        lock.l_type = F_UNLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = SHARED_FIRST+divSize;
        lock.l_len = SHARED_SIZE-divSize;
        if( fcntl(h, F_SETLK, &lock)==(-1) ){
          tErrno = errno;
		  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
          if( IS_LOCK_ERROR(rc) ){
            pFile->lastErrno = tErrno;
          }
          goto end_unlock;
        }
      }else{
        lock.l_type = F_RDLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = SHARED_FIRST;
        lock.l_len = SHARED_SIZE;
        if( fcntl(h, F_SETLK, &lock)==(-1) ){
          tErrno = errno;
		  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
          if( IS_LOCK_ERROR(rc) ){
            pFile->lastErrno = tErrno;
          }
          goto end_unlock;
        }
      }
    }
    lock.l_type = F_UNLCK;
    lock.l_whence = SEEK_SET;
    lock.l_start = PENDING_BYTE;
    lock.l_len = 2L;
    if( fcntl(h, F_SETLK, &lock)!=(-1) ){
      pInode->eFileLock = SHARED_LOCK;
    }else{
      tErrno = errno;
	  rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
      if( IS_LOCK_ERROR(rc) ){
        pFile->lastErrno = tErrno;
      }
      goto end_unlock;
    }
  }
  if( eFileLock==NO_LOCK ){
    /* Decrement the shared lock counter.  Release the lock using an
    ** OS call only when all threads in this same process have released
    ** the lock.
    */
    pInode->nShared--;
    if( pInode->nShared==0 ){
      lock.l_type = F_UNLCK;
      lock.l_whence = SEEK_SET;
      lock.l_start = lock.l_len = 0L;
      
      if( fcntl(h, F_SETLK, &lock)!=(-1) ){
        pInode->eFileLock = NO_LOCK;
      }else{
        tErrno = errno;
		rc = unqliteErrorFromPosixError(tErrno, UNQLITE_LOCKERR);
        if( IS_LOCK_ERROR(rc) ){
          pFile->lastErrno = tErrno;
        }
        pInode->eFileLock = NO_LOCK;
        pFile->eFileLock = NO_LOCK;
      }
    }

    /* Decrement the count of locks against this same file.  When the
    ** count reaches zero, close any other file descriptors whose close
    ** was deferred because of outstanding locks.
    */
    pInode->nLock--;
 
    if( pInode->nLock==0 ){
      int rc2 = closePendingFds(pFile);
      if( rc==UNQLITE_OK ){
        rc = rc2;
      }
    }
  }
	
end_unlock:

  unixLeaveMutex();
  
  if( rc==UNQLITE_OK ) pFile->eFileLock = eFileLock;
  return rc;
}
/*
** Lower the locking level on file descriptor pFile to eFileLock.  eFileLock
** must be either NO_LOCK or SHARED_LOCK.
**
** If the locking level of the file descriptor is already at or below
** the requested locking level, this routine is a no-op.
*/
static int unixUnlock(unqlite_file *id, int eFileLock){
  return _posixUnlock(id, eFileLock, 0);
}
/*
** This function performs the parts of the "close file" operation 
** common to all locking schemes. It closes the directory and file
** handles, if they are valid, and sets all fields of the unixFile
** structure to 0.
**
*/
static int closeUnixFile(unqlite_file *id){
  unixFile *pFile = (unixFile*)id;
  if( pFile ){
    if( pFile->dirfd>=0 ){
      int err = close(pFile->dirfd);
      if( err ){
        pFile->lastErrno = errno;
        return UNQLITE_IOERR;
      }else{
        pFile->dirfd=-1;
      }
    }
    if( pFile->h>=0 ){
      int err = close(pFile->h);
      if( err ){
        pFile->lastErrno = errno;
        return UNQLITE_IOERR;
      }
    }
    unqlite_free(pFile->pUnused);
    SyZero(pFile,sizeof(unixFile));
  }
  return UNQLITE_OK;
}
/*
** Close a file.
*/
static int unixClose(unqlite_file *id){
  int rc = UNQLITE_OK;
  if( id ){
    unixFile *pFile = (unixFile *)id;
    unixUnlock(id, NO_LOCK);
    unixEnterMutex();
    if( pFile->pInode && pFile->pInode->nLock ){
      /* If there are outstanding locks, do not actually close the file just
      ** yet because that would clear those locks.  Instead, add the file
      ** descriptor to pInode->pUnused list.  It will be automatically closed 
      ** when the last lock is cleared.
      */
      setPendingFd(pFile);
    }
    releaseInodeInfo(pFile);
    rc = closeUnixFile(id);
    unixLeaveMutex();
  }
  return rc;
}
/************** End of the posix advisory lock implementation *****************
******************************************************************************/
/*
**
** The next division contains implementations for all methods of the 
** unqlite_file object other than the locking methods.  The locking
** methods were defined in divisions above (one locking method per
** division).  Those methods that are common to all locking modes
** are gather together into this division.
*/
/*
** Seek to the offset passed as the second argument, then read cnt 
** bytes into pBuf. Return the number of bytes actually read.
**
** NB:  If you define USE_PREAD or USE_PREAD64, then it might also
** be necessary to define _XOPEN_SOURCE to be 500.  This varies from
** one system to another.  Since SQLite does not define USE_PREAD
** any form by default, we will not attempt to define _XOPEN_SOURCE.
** See tickets #2741 and #2681.
**
** To avoid stomping the errno value on a failed read the lastErrno value
** is set before returning.
*/
static int seekAndRead(unixFile *id, unqlite_int64 offset, void *pBuf, int cnt){
  int got;
#if (!defined(USE_PREAD) && !defined(USE_PREAD64))
  unqlite_int64 newOffset;
#endif
 
#if defined(USE_PREAD)
  got = pread(id->h, pBuf, cnt, offset);
#elif defined(USE_PREAD64)
  got = pread64(id->h, pBuf, cnt, offset);
#else
  newOffset = lseek(id->h, offset, SEEK_SET);
  
  if( newOffset!=offset ){
    if( newOffset == -1 ){
      ((unixFile*)id)->lastErrno = errno;
    }else{
      ((unixFile*)id)->lastErrno = 0;			
    }
    return -1;
  }
  got = read(id->h, pBuf, cnt);
#endif
  if( got<0 ){
    ((unixFile*)id)->lastErrno = errno;
  }
  return got;
}
/*
** Read data from a file into a buffer.  Return UNQLITE_OK if all
** bytes were read successfully and UNQLITE_IOERR if anything goes
** wrong.
*/
static int unixRead(
  unqlite_file *id, 
  void *pBuf, 
  unqlite_int64 amt,
  unqlite_int64 offset
){
  unixFile *pFile = (unixFile *)id;
  int got;
  
  got = seekAndRead(pFile, offset, pBuf, (int)amt);
  if( got==(int)amt ){
    return UNQLITE_OK;
  }else if( got<0 ){
    /* lastErrno set by seekAndRead */
    return UNQLITE_IOERR;
  }else{
    pFile->lastErrno = 0; /* not a system error */
    /* Unread parts of the buffer must be zero-filled */
    SyZero(&((char*)pBuf)[got],(sxu32)amt-got);
    return UNQLITE_IOERR;
  }
}
/*
** Seek to the offset in id->offset then read cnt bytes into pBuf.
** Return the number of bytes actually read.  Update the offset.
**
** To avoid stomping the errno value on a failed write the lastErrno value
** is set before returning.
*/
static int seekAndWrite(unixFile *id, unqlite_int64 offset, const void *pBuf, unqlite_int64 cnt){
  int got;
#if (!defined(USE_PREAD) && !defined(USE_PREAD64))
  unqlite_int64 newOffset;
#endif
  
#if defined(USE_PREAD)
  got = pwrite(id->h, pBuf, cnt, offset);
#elif defined(USE_PREAD64)
  got = pwrite64(id->h, pBuf, cnt, offset);
#else
  newOffset = lseek(id->h, offset, SEEK_SET);
  if( newOffset!=offset ){
    if( newOffset == -1 ){
      ((unixFile*)id)->lastErrno = errno;
    }else{
      ((unixFile*)id)->lastErrno = 0;			
    }
    return -1;
  }
  got = write(id->h, pBuf, cnt);
#endif
  if( got<0 ){
    ((unixFile*)id)->lastErrno = errno;
  }
  return got;
}
/*
** Write data from a buffer into a file.  Return UNQLITE_OK on success
** or some other error code on failure.
*/
static int unixWrite(
  unqlite_file *id, 
  const void *pBuf, 
  unqlite_int64 amt,
  unqlite_int64 offset 
){
  unixFile *pFile = (unixFile*)id;
  int wrote = 0;

  while( amt>0 && (wrote = seekAndWrite(pFile, offset, pBuf, amt))>0 ){
    amt -= wrote;
    offset += wrote;
    pBuf = &((char*)pBuf)[wrote];
  }
  
  if( amt>0 ){
    if( wrote<0 ){
      /* lastErrno set by seekAndWrite */
      return UNQLITE_IOERR;
    }else{
      pFile->lastErrno = 0; /* not a system error */
      return UNQLITE_FULL;
    }
  }
  return UNQLITE_OK;
}
/*
** We do not trust systems to provide a working fdatasync().  Some do.
** Others do no.  To be safe, we will stick with the (slower) fsync().
** If you know that your system does support fdatasync() correctly,
** then simply compile with -Dfdatasync=fdatasync
*/
#if !defined(fdatasync) && !defined(__linux__)
# define fdatasync fsync
#endif

/*
** Define HAVE_FULLFSYNC to 0 or 1 depending on whether or not
** the F_FULLFSYNC macro is defined.  F_FULLFSYNC is currently
** only available on Mac OS X.  But that could change.
*/
#ifdef F_FULLFSYNC
# define HAVE_FULLFSYNC 1
#else
# define HAVE_FULLFSYNC 0
#endif
/*
** The fsync() system call does not work as advertised on many
** unix systems.  The following procedure is an attempt to make
** it work better.
**
**
** SQLite sets the dataOnly flag if the size of the file is unchanged.
** The idea behind dataOnly is that it should only write the file content
** to disk, not the inode.  We only set dataOnly if the file size is 
** unchanged since the file size is part of the inode.  However, 
** Ted Ts'o tells us that fdatasync() will also write the inode if the
** file size has changed.  The only real difference between fdatasync()
** and fsync(), Ted tells us, is that fdatasync() will not flush the
** inode if the mtime or owner or other inode attributes have changed.
** We only care about the file size, not the other file attributes, so
** as far as SQLite is concerned, an fdatasync() is always adequate.
** So, we always use fdatasync() if it is available, regardless of
** the value of the dataOnly flag.
*/
static int full_fsync(int fd, int fullSync, int dataOnly){
  int rc;
#if HAVE_FULLFSYNC
  SXUNUSED(dataOnly);
#else
  SXUNUSED(fullSync);
  SXUNUSED(dataOnly);
#endif

  /* If we compiled with the UNQLITE_NO_SYNC flag, then syncing is a
  ** no-op
  */
#if HAVE_FULLFSYNC
  if( fullSync ){
    rc = fcntl(fd, F_FULLFSYNC, 0);
  }else{
    rc = 1;
  }
  /* If the FULLFSYNC failed, fall back to attempting an fsync().
  ** It shouldn't be possible for fullfsync to fail on the local 
  ** file system (on OSX), so failure indicates that FULLFSYNC
  ** isn't supported for this file system. So, attempt an fsync 
  ** and (for now) ignore the overhead of a superfluous fcntl call.  
  ** It'd be better to detect fullfsync support once and avoid 
  ** the fcntl call every time sync is called.
  */
  if( rc ) rc = fsync(fd);

#elif defined(__APPLE__)
  /* fdatasync() on HFS+ doesn't yet flush the file size if it changed correctly
  ** so currently we default to the macro that redefines fdatasync to fsync
  */
  rc = fsync(fd);
#else 
  rc = fdatasync(fd);
#endif /* ifdef UNQLITE_NO_SYNC elif HAVE_FULLFSYNC */
  if( rc!= -1 ){
    rc = 0;
  }
  return rc;
}
/*
** Make sure all writes to a particular file are committed to disk.
**
** If dataOnly==0 then both the file itself and its metadata (file
** size, access time, etc) are synced.  If dataOnly!=0 then only the
** file data is synced.
**
** Under Unix, also make sure that the directory entry for the file
** has been created by fsync-ing the directory that contains the file.
** If we do not do this and we encounter a power failure, the directory
** entry for the journal might not exist after we reboot.  The next
** SQLite to access the file will not know that the journal exists (because
** the directory entry for the journal was never created) and the transaction
** will not roll back - possibly leading to database corruption.
*/
static int unixSync(unqlite_file *id, int flags){
  int rc;
  unixFile *pFile = (unixFile*)id;

  int isDataOnly = (flags&UNQLITE_SYNC_DATAONLY);
  int isFullsync = (flags&0x0F)==UNQLITE_SYNC_FULL;

  rc = full_fsync(pFile->h, isFullsync, isDataOnly);

  if( rc ){
    pFile->lastErrno = errno;
    return UNQLITE_IOERR;
  }
  if( pFile->dirfd>=0 ){
    int err;
#ifndef UNQLITE_DISABLE_DIRSYNC
    /* The directory sync is only attempted if full_fsync is
    ** turned off or unavailable.  If a full_fsync occurred above,
    ** then the directory sync is superfluous.
    */
    if( (!HAVE_FULLFSYNC || !isFullsync) && full_fsync(pFile->dirfd,0,0) ){
       /*
       ** We have received multiple reports of fsync() returning
       ** errors when applied to directories on certain file systems.
       ** A failed directory sync is not a big deal.  So it seems
       ** better to ignore the error.  Ticket #1657
       */
       /* pFile->lastErrno = errno; */
       /* return UNQLITE_IOERR; */
    }
#endif
    err = close(pFile->dirfd); /* Only need to sync once, so close the */
    if( err==0 ){              /* directory when we are done */
      pFile->dirfd = -1;
    }else{
      pFile->lastErrno = errno;
      rc = UNQLITE_IOERR;
    }
  }
  return rc;
}
/*
** Truncate an open file to a specified size
*/
static int unixTruncate(unqlite_file *id, sxi64 nByte){
  unixFile *pFile = (unixFile *)id;
  int rc;

  rc = ftruncate(pFile->h, (off_t)nByte);
  if( rc ){
    pFile->lastErrno = errno;
    return UNQLITE_IOERR;
  }else{
    return UNQLITE_OK;
  }
}
/*
** Determine the current size of a file in bytes
*/
static int unixFileSize(unqlite_file *id,sxi64 *pSize){
  int rc;
  struct stat buf;
  
  rc = fstat(((unixFile*)id)->h, &buf);
  
  if( rc!=0 ){
    ((unixFile*)id)->lastErrno = errno;
    return UNQLITE_IOERR;
  }
  *pSize = buf.st_size;

  /* When opening a zero-size database, the findInodeInfo() procedure
  ** writes a single byte into that file in order to work around a bug
  ** in the OS-X msdos filesystem.  In order to avoid problems with upper
  ** layers, we need to report this file size as zero even though it is
  ** really 1.   Ticket #3260.
  */
  if( *pSize==1 ) *pSize = 0;

  return UNQLITE_OK;
}
/*
** Return the sector size in bytes of the underlying block device for
** the specified file. This is almost always 512 bytes, but may be
** larger for some devices.
**
** SQLite code assumes this function cannot fail. It also assumes that
** if two files are created in the same file-system directory (i.e.
** a database and its journal file) that the sector size will be the
** same for both.
*/
static int unixSectorSize(unqlite_file *NotUsed){
  SXUNUSED(NotUsed);
  return UNQLITE_DEFAULT_SECTOR_SIZE;
}
/*
** This vector defines all the methods that can operate on an
** unqlite_file for Windows systems.
*/
static const unqlite_io_methods unixIoMethod = {
  1,                              /* iVersion */
  unixClose,                       /* xClose */
  unixRead,                        /* xRead */
  unixWrite,                       /* xWrite */
  unixTruncate,                    /* xTruncate */
  unixSync,                        /* xSync */
  unixFileSize,                    /* xFileSize */
  unixLock,                        /* xLock */
  unixUnlock,                      /* xUnlock */
  unixCheckReservedLock,           /* xCheckReservedLock */
  unixSectorSize,                  /* xSectorSize */
};
/****************************************************************************
**************************** unqlite_vfs methods ****************************
**
** This division contains the implementation of methods on the
** unqlite_vfs object.
*/
/*
** Initialize the contents of the unixFile structure pointed to by pId.
*/
static int fillInUnixFile(
  unqlite_vfs *pVfs,      /* Pointer to vfs object */
  int h,                  /* Open file descriptor of file being opened */
  int dirfd,              /* Directory file descriptor */
  unqlite_file *pId,      /* Write to the unixFile structure here */
  const char *zFilename,  /* Name of the file being opened */
  int noLock,             /* Omit locking if true */
  int isDelete            /* Delete on close if true */
){
  const unqlite_io_methods *pLockingStyle = &unixIoMethod;
  unixFile *pNew = (unixFile *)pId;
  int rc = UNQLITE_OK;

  /* Parameter isDelete is only used on vxworks. Express this explicitly 
  ** here to prevent compiler warnings about unused parameters.
  */
  SXUNUSED(isDelete);
  SXUNUSED(noLock);
  SXUNUSED(pVfs);

  pNew->h = h;
  pNew->dirfd = dirfd;
  pNew->fileFlags = 0;
  pNew->zPath = zFilename;
  
  unixEnterMutex();
  rc = findInodeInfo(pNew, &pNew->pInode);
  if( rc!=UNQLITE_OK ){
      /* If an error occured in findInodeInfo(), close the file descriptor
      ** immediately, before releasing the mutex. findInodeInfo() may fail
      ** in two scenarios:
      **
      **   (a) A call to fstat() failed.
      **   (b) A malloc failed.
      **
      ** Scenario (b) may only occur if the process is holding no other
      ** file descriptors open on the same file. If there were other file
      ** descriptors on this file, then no malloc would be required by
      ** findInodeInfo(). If this is the case, it is quite safe to close
      ** handle h - as it is guaranteed that no posix locks will be released
      ** by doing so.
      **
      ** If scenario (a) caused the error then things are not so safe. The
      ** implicit assumption here is that if fstat() fails, things are in
      ** such bad shape that dropping a lock or two doesn't matter much.
      */
      close(h);
      h = -1;
  }
  unixLeaveMutex();
  
  pNew->lastErrno = 0;
  if( rc!=UNQLITE_OK ){
    if( dirfd>=0 ) close(dirfd); /* silent leak if fail, already in error */
    if( h>=0 ) close(h);
  }else{
    pNew->pMethod = pLockingStyle;
  }
  return rc;
}
/*
** Open a file descriptor to the directory containing file zFilename.
** If successful, *pFd is set to the opened file descriptor and
** UNQLITE_OK is returned. If an error occurs, either UNQLITE_NOMEM
** or UNQLITE_CANTOPEN is returned and *pFd is set to an undefined
** value.
**
** If UNQLITE_OK is returned, the caller is responsible for closing
** the file descriptor *pFd using close().
*/
static int openDirectory(const char *zFilename, int *pFd){
  sxu32 ii;
  int fd = -1;
  char zDirname[MAX_PATHNAME+1];
  sxu32 n;
  n = Systrcpy(zDirname,sizeof(zDirname),zFilename,0);
  for(ii=n; ii>1 && zDirname[ii]!='/'; ii--);
  if( ii>0 ){
    zDirname[ii] = '\0';
    fd = open(zDirname, O_RDONLY|O_BINARY, 0);
    if( fd>=0 ){
#ifdef FD_CLOEXEC
      fcntl(fd, F_SETFD, fcntl(fd, F_GETFD, 0) | FD_CLOEXEC);
#endif
    }
  }
  *pFd = fd;
  return (fd>=0?UNQLITE_OK: UNQLITE_IOERR );
}
/*
** Search for an unused file descriptor that was opened on the database 
** file (not a journal or master-journal file) identified by pathname
** zPath with UNQLITE_OPEN_XXX flags matching those passed as the second
** argument to this function.
**
** Such a file descriptor may exist if a database connection was closed
** but the associated file descriptor could not be closed because some
** other file descriptor open on the same file is holding a file-lock.
** Refer to comments in the unixClose() function and the lengthy comment
** describing "Posix Advisory Locking" at the start of this file for 
** further details. Also, ticket #4018.
**
** If a suitable file descriptor is found, then it is returned. If no
** such file descriptor is located, -1 is returned.
*/
static UnixUnusedFd *findReusableFd(const char *zPath, int flags){
  UnixUnusedFd *pUnused = 0;
  struct stat sStat;                   /* Results of stat() call */
  /* A stat() call may fail for various reasons. If this happens, it is
  ** almost certain that an open() call on the same path will also fail.
  ** For this reason, if an error occurs in the stat() call here, it is
  ** ignored and -1 is returned. The caller will try to open a new file
  ** descriptor on the same path, fail, and return an error to SQLite.
  **
  ** Even if a subsequent open() call does succeed, the consequences of
  ** not searching for a resusable file descriptor are not dire.  */
  if( 0==stat(zPath, &sStat) ){
    unixInodeInfo *pInode;

    unixEnterMutex();
    pInode = inodeList;
    while( pInode && (pInode->fileId.dev!=sStat.st_dev
                     || pInode->fileId.ino!=sStat.st_ino) ){
       pInode = pInode->pNext;
    }
    if( pInode ){
      UnixUnusedFd **pp;
      for(pp=&pInode->pUnused; *pp && (*pp)->flags!=flags; pp=&((*pp)->pNext));
      pUnused = *pp;
      if( pUnused ){
        *pp = pUnused->pNext;
      }
    }
    unixLeaveMutex();
  }
  return pUnused;
}
/*
** This function is called by unixOpen() to determine the unix permissions
** to create new files with. If no error occurs, then UNQLITE_OK is returned
** and a value suitable for passing as the third argument to open(2) is
** written to *pMode. If an IO error occurs, an SQLite error code is 
** returned and the value of *pMode is not modified.
**
** If the file being opened is a temporary file, it is always created with
** the octal permissions 0600 (read/writable by owner only). If the file
** is a database or master journal file, it is created with the permissions 
** mask UNQLITE_DEFAULT_FILE_PERMISSIONS.
**
** Finally, if the file being opened is a WAL or regular journal file, then 
** this function queries the file-system for the permissions on the 
** corresponding database file and sets *pMode to this value. Whenever 
** possible, WAL and journal files are created using the same permissions 
** as the associated database file.
*/
static int findCreateFileMode(
  const char *zPath,              /* Path of file (possibly) being created */
  int flags,                      /* Flags passed as 4th argument to xOpen() */
  mode_t *pMode                   /* OUT: Permissions to open file with */
){
  int rc = UNQLITE_OK;             /* Return Code */
  if( flags & UNQLITE_OPEN_TEMP_DB ){
    *pMode = 0600;
     SXUNUSED(zPath);
  }else{
    *pMode = UNQLITE_DEFAULT_FILE_PERMISSIONS;
  }
  return rc;
}
/*
** Open the file zPath.
** 
** Previously, the SQLite OS layer used three functions in place of this
** one:
**
**     unqliteOsOpenReadWrite();
**     unqliteOsOpenReadOnly();
**     unqliteOsOpenExclusive();
**
** These calls correspond to the following combinations of flags:
**
**     ReadWrite() ->     (READWRITE | CREATE)
**     ReadOnly()  ->     (READONLY) 
**     OpenExclusive() -> (READWRITE | CREATE | EXCLUSIVE)
**
** The old OpenExclusive() accepted a boolean argument - "delFlag". If
** true, the file was configured to be automatically deleted when the
** file handle closed. To achieve the same effect using this new 
** interface, add the DELETEONCLOSE flag to those specified above for 
** OpenExclusive().
*/
static int unixOpen(
  unqlite_vfs *pVfs,           /* The VFS for which this is the xOpen method */
  const char *zPath,           /* Pathname of file to be opened */
  unqlite_file *pFile,         /* The file descriptor to be filled in */
  unsigned int flags           /* Input flags to control the opening */
){
  unixFile *p = (unixFile *)pFile;
  int fd = -1;                   /* File descriptor returned by open() */
  int dirfd = -1;                /* Directory file descriptor */
  int openFlags = 0;             /* Flags to pass to open() */
  int noLock;                    /* True to omit locking primitives */
  int rc = UNQLITE_OK;            /* Function Return Code */
  UnixUnusedFd *pUnused;
  int isExclusive  = (flags & UNQLITE_OPEN_EXCLUSIVE);
  int isDelete     = (flags & UNQLITE_OPEN_TEMP_DB);
  int isCreate     = (flags & UNQLITE_OPEN_CREATE);
  int isReadonly   = (flags & UNQLITE_OPEN_READONLY);
  int isReadWrite  = (flags & UNQLITE_OPEN_READWRITE);
  /* If creating a master or main-file journal, this function will open
  ** a file-descriptor on the directory too. The first time unixSync()
  ** is called the directory file descriptor will be fsync()ed and close()d.
  */
  int isOpenDirectory = isCreate;
  const char *zName = zPath;

  SyZero(p,sizeof(unixFile));
  
  pUnused = findReusableFd(zName, flags);
  if( pUnused ){
	  fd = pUnused->fd;
  }else{
	  pUnused = unqlite_malloc(sizeof(*pUnused));
      if( !pUnused ){
        return UNQLITE_NOMEM;
      }
  }
  p->pUnused = pUnused;
  
  /* Determine the value of the flags parameter passed to POSIX function
  ** open(). These must be calculated even if open() is not called, as
  ** they may be stored as part of the file handle and used by the 
  ** 'conch file' locking functions later on.  */
  if( isReadonly )  openFlags |= O_RDONLY;
  if( isReadWrite ) openFlags |= O_RDWR;
  if( isCreate )    openFlags |= O_CREAT;
  if( isExclusive ) openFlags |= (O_EXCL|O_NOFOLLOW);
  openFlags |= (O_LARGEFILE|O_BINARY);

  if( fd<0 ){
    mode_t openMode;              /* Permissions to create file with */
    rc = findCreateFileMode(zName, flags, &openMode);
    if( rc!=UNQLITE_OK ){
      return rc;
    }
    fd = open(zName, openFlags, openMode);
    if( fd<0 ){
	  rc = UNQLITE_IOERR;
      goto open_finished;
    }
  }
  
  if( p->pUnused ){
    p->pUnused->fd = fd;
    p->pUnused->flags = flags;
  }

  if( isDelete ){
    unlink(zName);
  }

  if( isOpenDirectory ){
    rc = openDirectory(zPath, &dirfd);
    if( rc!=UNQLITE_OK ){
      /* It is safe to close fd at this point, because it is guaranteed not
      ** to be open on a database file. If it were open on a database file,
      ** it would not be safe to close as this would release any locks held
      ** on the file by this process.  */
      close(fd);             /* silently leak if fail, already in error */
      goto open_finished;
    }
  }

#ifdef FD_CLOEXEC
  fcntl(fd, F_SETFD, fcntl(fd, F_GETFD, 0) | FD_CLOEXEC);
#endif

  noLock = 0;

#if defined(__APPLE__) 
  struct statfs fsInfo;
  if( fstatfs(fd, &fsInfo) == -1 ){
    ((unixFile*)pFile)->lastErrno = errno;
    if( dirfd>=0 ) close(dirfd); /* silently leak if fail, in error */
    close(fd); /* silently leak if fail, in error */
    return UNQLITE_IOERR;
  }
  if (0 == SyStrncmp("msdos", fsInfo.f_fstypename, 5)) {
    ((unixFile*)pFile)->fsFlags |= UNQLITE_FSFLAGS_IS_MSDOS;
  }
#endif
  
  rc = fillInUnixFile(pVfs, fd, dirfd, pFile, zPath, noLock, isDelete);
open_finished:
  if( rc!=UNQLITE_OK ){
    unqlite_free(p->pUnused);
  }
  return rc;
}
/*
** Delete the file at zPath. If the dirSync argument is true, fsync()
** the directory after deleting the file.
*/
static int unixDelete(
  unqlite_vfs *NotUsed,     /* VFS containing this as the xDelete method */
  const char *zPath,        /* Name of file to be deleted */
  int dirSync               /* If true, fsync() directory after deleting file */
){
  int rc = UNQLITE_OK;
  SXUNUSED(NotUsed);
  
  if( unlink(zPath)==(-1) && errno!=ENOENT ){
	  return UNQLITE_IOERR;
  }
#ifndef UNQLITE_DISABLE_DIRSYNC
  if( dirSync ){
    int fd;
    rc = openDirectory(zPath, &fd);
    if( rc==UNQLITE_OK ){
      if( fsync(fd) )
      {
        rc = UNQLITE_IOERR;
      }
      if( close(fd) && !rc ){
        rc = UNQLITE_IOERR;
      }
    }
  }
#endif
  return rc;
}
/*
** Sleep for a little while.  Return the amount of time slept.
** The argument is the number of microseconds we want to sleep.
** The return value is the number of microseconds of sleep actually
** requested from the underlying operating system, a number which
** might be greater than or equal to the argument, but not less
** than the argument.
*/
static int unixSleep(unqlite_vfs *NotUsed, int microseconds)
{
#if defined(HAVE_USLEEP) && HAVE_USLEEP
  usleep(microseconds);
  SXUNUSED(NotUsed);
  return microseconds;
#else
  int seconds = (microseconds+999999)/1000000;
  SXUNUSED(NotUsed);
  sleep(seconds);
  return seconds*1000000;
#endif
}
/*
 * Export the current system time.
 */
static int unixCurrentTime(unqlite_vfs *pVfs,Sytm *pOut)
{
	struct tm *pTm;
	time_t tt;
	SXUNUSED(pVfs);
	time(&tt);
	pTm = gmtime(&tt);
	if( pTm ){ /* Yes, it can fail */
		STRUCT_TM_TO_SYTM(pTm,pOut);
	}
	return UNQLITE_OK;
}
/*
** Test the existance of or access permissions of file zPath. The
** test performed depends on the value of flags:
**
**     UNQLITE_ACCESS_EXISTS: Return 1 if the file exists
**     UNQLITE_ACCESS_READWRITE: Return 1 if the file is read and writable.
**     UNQLITE_ACCESS_READONLY: Return 1 if the file is readable.
**
** Otherwise return 0.
*/
static int unixAccess(
  unqlite_vfs *NotUsed,   /* The VFS containing this xAccess method */
  const char *zPath,      /* Path of the file to examine */
  int flags,              /* What do we want to learn about the zPath file? */
  int *pResOut            /* Write result boolean here */
){
  int amode = 0;
  SXUNUSED(NotUsed);
  switch( flags ){
    case UNQLITE_ACCESS_EXISTS:
      amode = F_OK;
      break;
    case UNQLITE_ACCESS_READWRITE:
      amode = W_OK|R_OK;
      break;
    case UNQLITE_ACCESS_READ:
      amode = R_OK;
      break;
    default:
		/* Can't happen */
      break;
  }
  *pResOut = (access(zPath, amode)==0);
  if( flags==UNQLITE_ACCESS_EXISTS && *pResOut ){
    struct stat buf;
    if( 0==stat(zPath, &buf) && buf.st_size==0 ){
      *pResOut = 0;
    }
  }
  return UNQLITE_OK;
}
/*
** Turn a relative pathname into a full pathname. The relative path
** is stored as a nul-terminated string in the buffer pointed to by
** zPath. 
**
** zOut points to a buffer of at least unqlite_vfs.mxPathname bytes 
** (in this case, MAX_PATHNAME bytes). The full-path is written to
** this buffer before returning.
*/
static int unixFullPathname(
  unqlite_vfs *pVfs,            /* Pointer to vfs object */
  const char *zPath,            /* Possibly relative input path */
  int nOut,                     /* Size of output buffer in bytes */
  char *zOut                    /* Output buffer */
){
  if( zPath[0]=='/' ){
	  Systrcpy(zOut,(sxu32)nOut,zPath,0);
	  SXUNUSED(pVfs);
  }else{
    sxu32 nCwd;
	zOut[nOut-1] = '\0';
    if( getcwd(zOut, nOut-1)==0 ){
		return UNQLITE_IOERR;
    }
    nCwd = SyStrlen(zOut);
    SyBufferFormat(&zOut[nCwd],(sxu32)nOut-nCwd,"/%s",zPath);
  }
  return UNQLITE_OK;
}
/* int (*xMmap)(const char *, void **, jx9_int64 *) */
static int UnixVfs_Mmap(const char *zPath, void **ppMap, unqlite_int64 *pSize)
{
	struct stat st;
	void *pMap;
	int fd;
	int rc;
	/* Open the file in a read-only mode */
	fd = open(zPath, O_RDONLY);
	if( fd < 0 ){
		return -1;
	}
	/* stat the handle */
	fstat(fd, &st);
	/* Obtain a memory view of the whole file */
	pMap = mmap(0, st.st_size, PROT_READ, MAP_PRIVATE|MAP_FILE, fd, 0);
	rc = UNQLITE_OK;
	if( pMap == MAP_FAILED ){
		rc = -1;
	}else{
		/* Point to the memory view */
		*ppMap = pMap;
		*pSize = (unqlite_int64)st.st_size;
	}
	close(fd);
	return rc;
}
/* void (*xUnmap)(void *, jx9_int64)  */
static void UnixVfs_Unmap(void *pView, unqlite_int64 nSize)
{
	munmap(pView, (size_t)nSize);
}
/*
 * Export the Unix Vfs.
 */
UNQLITE_PRIVATE const unqlite_vfs * unqliteExportBuiltinVfs(void)
{
	static const unqlite_vfs sUnixvfs = {
		"Unix",              /* Vfs name */
		1,                   /* Vfs structure version */
		sizeof(unixFile),    /* szOsFile */
		MAX_PATHNAME,        /* mxPathName */
		unixOpen,            /* xOpen */
		unixDelete,          /* xDelete */
		unixAccess,          /* xAccess */
		unixFullPathname,    /* xFullPathname */
		0,                   /* xTmp */
		UnixVfs_Mmap,        /* xMap */
		UnixVfs_Unmap,       /* xUnamp */
		unixSleep,           /* xSleep */
		unixCurrentTime,     /* xCurrentTime */
		0,                   /* xGetLastError */
	};
	return &sUnixvfs;
}

#endif /* __UNIXES__ */

/*
 * ----------------------------------------------------------
 * File: os_win.c
 * ID: ab70fb386c21b39a08b0eb776a8391ab
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: os_win.c v1.2 Win7 2012-11-10 12:10 devel <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/* Omit the whole layer from the build if compiling for platforms other than Windows */
#ifdef __WINNT__
/* This file contains code that is specific to windows. (Mostly SQLite3 source tree) */
#include <Windows.h>
/*
** Some microsoft compilers lack this definition.
*/
#ifndef INVALID_FILE_ATTRIBUTES
# define INVALID_FILE_ATTRIBUTES ((DWORD)-1) 
#endif
/*
** WinCE lacks native support for file locking so we have to fake it
** with some code of our own.
*/
#ifdef __WIN_CE__
typedef struct winceLock {
  int nReaders;       /* Number of reader locks obtained */
  BOOL bPending;      /* Indicates a pending lock has been obtained */
  BOOL bReserved;     /* Indicates a reserved lock has been obtained */
  BOOL bExclusive;    /* Indicates an exclusive lock has been obtained */
} winceLock;
#define AreFileApisANSI() 1
#define FormatMessageW(a,b,c,d,e,f,g) 0
#endif

/*
** The winFile structure is a subclass of unqlite_file* specific to the win32
** portability layer.
*/
typedef struct winFile winFile;
struct winFile {
  const unqlite_io_methods *pMethod; /*** Must be first ***/
  unqlite_vfs *pVfs;      /* The VFS used to open this file */
  HANDLE h;               /* Handle for accessing the file */
  sxu8 locktype;          /* Type of lock currently held on this file */
  short sharedLockByte;   /* Randomly chosen byte used as a shared lock */
  DWORD lastErrno;        /* The Windows errno from the last I/O error */
  DWORD sectorSize;       /* Sector size of the device file is on */
  int szChunk;            /* Chunk size */
#ifdef __WIN_CE__
  WCHAR *zDeleteOnClose;  /* Name of file to delete when closing */
  HANDLE hMutex;          /* Mutex used to control access to shared lock */  
  HANDLE hShared;         /* Shared memory segment used for locking */
  winceLock local;        /* Locks obtained by this instance of winFile */
  winceLock *shared;      /* Global shared lock memory for the file  */
#endif
};
/*
** Convert a UTF-8 string to microsoft unicode (UTF-16?). 
**
** Space to hold the returned string is obtained from HeapAlloc().
*/
static WCHAR *utf8ToUnicode(const char *zFilename){
  int nChar;
  WCHAR *zWideFilename;

  nChar = MultiByteToWideChar(CP_UTF8, 0, zFilename, -1, 0, 0);
  zWideFilename = (WCHAR *)HeapAlloc(GetProcessHeap(),0,nChar*sizeof(zWideFilename[0]) );
  if( zWideFilename==0 ){
    return 0;
  }
  nChar = MultiByteToWideChar(CP_UTF8, 0, zFilename, -1, zWideFilename, nChar);
  if( nChar==0 ){
    HeapFree(GetProcessHeap(),0,zWideFilename);
    zWideFilename = 0;
  }
  return zWideFilename;
}

/*
** Convert microsoft unicode to UTF-8.  Space to hold the returned string is
** obtained from malloc().
*/
static char *unicodeToUtf8(const WCHAR *zWideFilename){
  int nByte;
  char *zFilename;

  nByte = WideCharToMultiByte(CP_UTF8, 0, zWideFilename, -1, 0, 0, 0, 0);
  zFilename = (char *)HeapAlloc(GetProcessHeap(),0,nByte );
  if( zFilename==0 ){
    return 0;
  }
  nByte = WideCharToMultiByte(CP_UTF8, 0, zWideFilename, -1, zFilename, nByte,
                              0, 0);
  if( nByte == 0 ){
    HeapFree(GetProcessHeap(),0,zFilename);
    zFilename = 0;
  }
  return zFilename;
}

/*
** Convert an ansi string to microsoft unicode, based on the
** current codepage settings for file apis.
** 
** Space to hold the returned string is obtained
** from malloc.
*/
static WCHAR *mbcsToUnicode(const char *zFilename){
  int nByte;
  WCHAR *zMbcsFilename;
  int codepage = AreFileApisANSI() ? CP_ACP : CP_OEMCP;

  nByte = MultiByteToWideChar(codepage, 0, zFilename, -1, 0,0)*sizeof(WCHAR);
  zMbcsFilename = (WCHAR *)HeapAlloc(GetProcessHeap(),0,nByte*sizeof(zMbcsFilename[0]) );
  if( zMbcsFilename==0 ){
    return 0;
  }
  nByte = MultiByteToWideChar(codepage, 0, zFilename, -1, zMbcsFilename, nByte);
  if( nByte==0 ){
    HeapFree(GetProcessHeap(),0,zMbcsFilename);
    zMbcsFilename = 0;
  }
  return zMbcsFilename;
}
/*
** Convert multibyte character string to UTF-8.  Space to hold the
** returned string is obtained from malloc().
*/
char *unqlite_win32_mbcs_to_utf8(const char *zFilename){
  char *zFilenameUtf8;
  WCHAR *zTmpWide;

  zTmpWide = mbcsToUnicode(zFilename);
  if( zTmpWide==0 ){
    return 0;
  }
  zFilenameUtf8 = unicodeToUtf8(zTmpWide);
  HeapFree(GetProcessHeap(),0,zTmpWide);
  return zFilenameUtf8;
}
/*
** Some microsoft compilers lack this definition.
*/
#ifndef INVALID_SET_FILE_POINTER
# define INVALID_SET_FILE_POINTER ((DWORD)-1)
#endif

/*
** Move the current position of the file handle passed as the first 
** argument to offset iOffset within the file. If successful, return 0. 
** Otherwise, set pFile->lastErrno and return non-zero.
*/
static int seekWinFile(winFile *pFile, unqlite_int64 iOffset){
  LONG upperBits;                 /* Most sig. 32 bits of new offset */
  LONG lowerBits;                 /* Least sig. 32 bits of new offset */
  DWORD dwRet;                    /* Value returned by SetFilePointer() */

  upperBits = (LONG)((iOffset>>32) & 0x7fffffff);
  lowerBits = (LONG)(iOffset & 0xffffffff);

  /* API oddity: If successful, SetFilePointer() returns a dword 
  ** containing the lower 32-bits of the new file-offset. Or, if it fails,
  ** it returns INVALID_SET_FILE_POINTER. However according to MSDN, 
  ** INVALID_SET_FILE_POINTER may also be a valid new offset. So to determine 
  ** whether an error has actually occured, it is also necessary to call 
  ** GetLastError().
  */
  dwRet = SetFilePointer(pFile->h, lowerBits, &upperBits, FILE_BEGIN);
  if( (dwRet==INVALID_SET_FILE_POINTER && GetLastError()!=NO_ERROR) ){
    pFile->lastErrno = GetLastError();
    return 1;
  }
  return 0;
}
/*
** Close a file.
**
** It is reported that an attempt to close a handle might sometimes
** fail.  This is a very unreasonable result, but windows is notorious
** for being unreasonable so I do not doubt that it might happen.  If
** the close fails, we pause for 100 milliseconds and try again.  As
** many as MX_CLOSE_ATTEMPT attempts to close the handle are made before
** giving up and returning an error.
*/
#define MX_CLOSE_ATTEMPT 3
static int winClose(unqlite_file *id)
{
  int rc, cnt = 0;
  winFile *pFile = (winFile*)id;
  do{
    rc = CloseHandle(pFile->h);
  }while( rc==0 && ++cnt < MX_CLOSE_ATTEMPT && (Sleep(100), 1) );

  return rc ? UNQLITE_OK : UNQLITE_IOERR;
}
/*
** Read data from a file into a buffer.  Return UNQLITE_OK if all
** bytes were read successfully and UNQLITE_IOERR if anything goes
** wrong.
*/
static int winRead(
  unqlite_file *id,          /* File to read from */
  void *pBuf,                /* Write content into this buffer */
  unqlite_int64 amt,        /* Number of bytes to read */
  unqlite_int64 offset       /* Begin reading at this offset */
){
  winFile *pFile = (winFile*)id;  /* file handle */
  DWORD nRead;                    /* Number of bytes actually read from file */

  if( seekWinFile(pFile, offset) ){
    return UNQLITE_FULL;
  }
  if( !ReadFile(pFile->h, pBuf, (DWORD)amt, &nRead, 0) ){
    pFile->lastErrno = GetLastError();
    return UNQLITE_IOERR;
  }
  if( nRead<(DWORD)amt ){
    /* Unread parts of the buffer must be zero-filled */
    SyZero(&((char*)pBuf)[nRead],(sxu32)(amt-nRead));
    return UNQLITE_IOERR;
  }

  return UNQLITE_OK;
}

/*
** Write data from a buffer into a file.  Return UNQLITE_OK on success
** or some other error code on failure.
*/
static int winWrite(
  unqlite_file *id,               /* File to write into */
  const void *pBuf,               /* The bytes to be written */
  unqlite_int64 amt,                        /* Number of bytes to write */
  unqlite_int64 offset            /* Offset into the file to begin writing at */
){
  int rc;                         /* True if error has occured, else false */
  winFile *pFile = (winFile*)id;  /* File handle */

  rc = seekWinFile(pFile, offset);
  if( rc==0 ){
    sxu8 *aRem = (sxu8 *)pBuf;        /* Data yet to be written */
    unqlite_int64 nRem = amt;         /* Number of bytes yet to be written */
    DWORD nWrite;                 /* Bytes written by each WriteFile() call */

    while( nRem>0 && WriteFile(pFile->h, aRem, (DWORD)nRem, &nWrite, 0) && nWrite>0 ){
      aRem += nWrite;
      nRem -= nWrite;
    }
    if( nRem>0 ){
      pFile->lastErrno = GetLastError();
      rc = 1;
    }
  }
  if( rc ){
    if( pFile->lastErrno==ERROR_HANDLE_DISK_FULL ){
      return UNQLITE_FULL;
    }
    return UNQLITE_IOERR;
  }
  return UNQLITE_OK;
}

/*
** Truncate an open file to a specified size
*/
static int winTruncate(unqlite_file *id, unqlite_int64 nByte){
  winFile *pFile = (winFile*)id;  /* File handle object */
  int rc = UNQLITE_OK;             /* Return code for this function */


  /* If the user has configured a chunk-size for this file, truncate the
  ** file so that it consists of an integer number of chunks (i.e. the
  ** actual file size after the operation may be larger than the requested
  ** size).
  */
  if( pFile->szChunk ){
    nByte = ((nByte + pFile->szChunk - 1)/pFile->szChunk) * pFile->szChunk;
  }

  /* SetEndOfFile() returns non-zero when successful, or zero when it fails. */
  if( seekWinFile(pFile, nByte) ){
    rc = UNQLITE_IOERR;
  }else if( 0==SetEndOfFile(pFile->h) ){
    pFile->lastErrno = GetLastError();
    rc = UNQLITE_IOERR;
  }
  return rc;
}
/*
** Make sure all writes to a particular file are committed to disk.
*/
static int winSync(unqlite_file *id, int flags){
  winFile *pFile = (winFile*)id;
  SXUNUSED(flags); /* MSVC warning */
  if( FlushFileBuffers(pFile->h) ){
    return UNQLITE_OK;
  }else{
    pFile->lastErrno = GetLastError();
    return UNQLITE_IOERR;
  }
}
/*
** Determine the current size of a file in bytes
*/
static int winFileSize(unqlite_file *id, unqlite_int64 *pSize){
  DWORD upperBits;
  DWORD lowerBits;
  winFile *pFile = (winFile*)id;
  DWORD error;
  lowerBits = GetFileSize(pFile->h, &upperBits);
  if(   (lowerBits == INVALID_FILE_SIZE)
     && ((error = GetLastError()) != NO_ERROR) )
  {
    pFile->lastErrno = error;
    return UNQLITE_IOERR;
  }
  *pSize = (((unqlite_int64)upperBits)<<32) + lowerBits;
  return UNQLITE_OK;
}
/*
** LOCKFILE_FAIL_IMMEDIATELY is undefined on some Windows systems.
*/
#ifndef LOCKFILE_FAIL_IMMEDIATELY
# define LOCKFILE_FAIL_IMMEDIATELY 1
#endif

/*
** Acquire a reader lock.
*/
static int getReadLock(winFile *pFile){
  int res;
  OVERLAPPED ovlp;
  ovlp.Offset = SHARED_FIRST;
  ovlp.OffsetHigh = 0;
  ovlp.hEvent = 0;
  res = LockFileEx(pFile->h, LOCKFILE_FAIL_IMMEDIATELY,0, SHARED_SIZE, 0, &ovlp);
  if( res == 0 ){
    pFile->lastErrno = GetLastError();
  }
  return res;
}
/*
** Undo a readlock
*/
static int unlockReadLock(winFile *pFile){
  int res;
  res = UnlockFile(pFile->h, SHARED_FIRST, 0, SHARED_SIZE, 0);
  if( res == 0 ){
    pFile->lastErrno = GetLastError();
  }
  return res;
}
/*
** Lock the file with the lock specified by parameter locktype - one
** of the following:
**
**     (1) SHARED_LOCK
**     (2) RESERVED_LOCK
**     (3) PENDING_LOCK
**     (4) EXCLUSIVE_LOCK
**
** Sometimes when requesting one lock state, additional lock states
** are inserted in between.  The locking might fail on one of the later
** transitions leaving the lock state different from what it started but
** still short of its goal.  The following chart shows the allowed
** transitions and the inserted intermediate states:
**
**    UNLOCKED -> SHARED
**    SHARED -> RESERVED
**    SHARED -> (PENDING) -> EXCLUSIVE
**    RESERVED -> (PENDING) -> EXCLUSIVE
**    PENDING -> EXCLUSIVE
**
** This routine will only increase a lock.  The winUnlock() routine
** erases all locks at once and returns us immediately to locking level 0.
** It is not possible to lower the locking level one step at a time.  You
** must go straight to locking level 0.
*/
static int winLock(unqlite_file *id, int locktype){
  int rc = UNQLITE_OK;    /* Return code from subroutines */
  int res = 1;           /* Result of a windows lock call */
  int newLocktype;       /* Set pFile->locktype to this value before exiting */
  int gotPendingLock = 0;/* True if we acquired a PENDING lock this time */
  winFile *pFile = (winFile*)id;
  DWORD error = NO_ERROR;

  /* If there is already a lock of this type or more restrictive on the
  ** OsFile, do nothing.
  */
  if( pFile->locktype>=locktype ){
    return UNQLITE_OK;
  }

  /* Make sure the locking sequence is correct
  assert( pFile->locktype!=NO_LOCK || locktype==SHARED_LOCK );
  assert( locktype!=PENDING_LOCK );
  assert( locktype!=RESERVED_LOCK || pFile->locktype==SHARED_LOCK );
  */
  /* Lock the PENDING_LOCK byte if we need to acquire a PENDING lock or
  ** a SHARED lock.  If we are acquiring a SHARED lock, the acquisition of
  ** the PENDING_LOCK byte is temporary.
  */
  newLocktype = pFile->locktype;
  if(   (pFile->locktype==NO_LOCK)
     || (   (locktype==EXCLUSIVE_LOCK)
         && (pFile->locktype==RESERVED_LOCK))
  ){
    int cnt = 3;
    while( cnt-->0 && (res = LockFile(pFile->h, PENDING_BYTE, 0, 1, 0))==0 ){
      /* Try 3 times to get the pending lock.  The pending lock might be
      ** held by another reader process who will release it momentarily.
	  */
      Sleep(1);
    }
    gotPendingLock = res;
    if( !res ){
      error = GetLastError();
    }
  }

  /* Acquire a shared lock
  */
  if( locktype==SHARED_LOCK && res ){
   /* assert( pFile->locktype==NO_LOCK ); */
    res = getReadLock(pFile);
    if( res ){
      newLocktype = SHARED_LOCK;
    }else{
      error = GetLastError();
    }
  }

  /* Acquire a RESERVED lock
  */
  if( locktype==RESERVED_LOCK && res ){
    /* assert( pFile->locktype==SHARED_LOCK ); */
    res = LockFile(pFile->h, RESERVED_BYTE, 0, 1, 0);
    if( res ){
      newLocktype = RESERVED_LOCK;
    }else{
      error = GetLastError();
    }
  }

  /* Acquire a PENDING lock
  */
  if( locktype==EXCLUSIVE_LOCK && res ){
    newLocktype = PENDING_LOCK;
    gotPendingLock = 0;
  }

  /* Acquire an EXCLUSIVE lock
  */
  if( locktype==EXCLUSIVE_LOCK && res ){
    /* assert( pFile->locktype>=SHARED_LOCK ); */
    res = unlockReadLock(pFile);
    res = LockFile(pFile->h, SHARED_FIRST, 0, SHARED_SIZE, 0);
    if( res ){
      newLocktype = EXCLUSIVE_LOCK;
    }else{
      error = GetLastError();
      getReadLock(pFile);
    }
  }

  /* If we are holding a PENDING lock that ought to be released, then
  ** release it now.
  */
  if( gotPendingLock && locktype==SHARED_LOCK ){
    UnlockFile(pFile->h, PENDING_BYTE, 0, 1, 0);
  }

  /* Update the state of the lock has held in the file descriptor then
  ** return the appropriate result code.
  */
  if( res ){
    rc = UNQLITE_OK;
  }else{
    pFile->lastErrno = error;
    rc = UNQLITE_BUSY;
  }
  pFile->locktype = (sxu8)newLocktype;
  return rc;
}
/*
** This routine checks if there is a RESERVED lock held on the specified
** file by this or any other process. If such a lock is held, return
** non-zero, otherwise zero.
*/
static int winCheckReservedLock(unqlite_file *id, int *pResOut){
  int rc;
  winFile *pFile = (winFile*)id;
  if( pFile->locktype>=RESERVED_LOCK ){
    rc = 1;
  }else{
    rc = LockFile(pFile->h, RESERVED_BYTE, 0, 1, 0);
    if( rc ){
      UnlockFile(pFile->h, RESERVED_BYTE, 0, 1, 0);
    }
    rc = !rc;
  }
  *pResOut = rc;
  return UNQLITE_OK;
}
/*
** Lower the locking level on file descriptor id to locktype.  locktype
** must be either NO_LOCK or SHARED_LOCK.
**
** If the locking level of the file descriptor is already at or below
** the requested locking level, this routine is a no-op.
**
** It is not possible for this routine to fail if the second argument
** is NO_LOCK.  If the second argument is SHARED_LOCK then this routine
** might return UNQLITE_IOERR;
*/
static int winUnlock(unqlite_file *id, int locktype){
  int type;
  winFile *pFile = (winFile*)id;
  int rc = UNQLITE_OK;

  type = pFile->locktype;
  if( type>=EXCLUSIVE_LOCK ){
    UnlockFile(pFile->h, SHARED_FIRST, 0, SHARED_SIZE, 0);
    if( locktype==SHARED_LOCK && !getReadLock(pFile) ){
      /* This should never happen.  We should always be able to
      ** reacquire the read lock */
      rc = UNQLITE_IOERR;
    }
  }
  if( type>=RESERVED_LOCK ){
    UnlockFile(pFile->h, RESERVED_BYTE, 0, 1, 0);
  }
  if( locktype==NO_LOCK && type>=SHARED_LOCK ){
    unlockReadLock(pFile);
  }
  if( type>=PENDING_LOCK ){
    UnlockFile(pFile->h, PENDING_BYTE, 0, 1, 0);
  }
  pFile->locktype = (sxu8)locktype;
  return rc;
}
/*
** Return the sector size in bytes of the underlying block device for
** the specified file. This is almost always 512 bytes, but may be
** larger for some devices.
**
*/
static int winSectorSize(unqlite_file *id){
  return (int)(((winFile*)id)->sectorSize);
}
/*
** This vector defines all the methods that can operate on an
** unqlite_file for Windows systems.
*/
static const unqlite_io_methods winIoMethod = {
  1,                              /* iVersion */
  winClose,                       /* xClose */
  winRead,                        /* xRead */
  winWrite,                       /* xWrite */
  winTruncate,                    /* xTruncate */
  winSync,                        /* xSync */
  winFileSize,                    /* xFileSize */
  winLock,                        /* xLock */
  winUnlock,                      /* xUnlock */
  winCheckReservedLock,           /* xCheckReservedLock */
  winSectorSize,                  /* xSectorSize */
};
/*
 * Windows VFS Methods.
 */
/*
** Convert a UTF-8 filename into whatever form the underlying
** operating system wants filenames in.  Space to hold the result
** is obtained from malloc and must be freed by the calling
** function.
*/
static void *convertUtf8Filename(const char *zFilename)
{
  void *zConverted;
  zConverted = utf8ToUnicode(zFilename);
  /* caller will handle out of memory */
  return zConverted;
}
/*
** Delete the named file.
**
** Note that windows does not allow a file to be deleted if some other
** process has it open.  Sometimes a virus scanner or indexing program
** will open a journal file shortly after it is created in order to do
** whatever it does.  While this other process is holding the
** file open, we will be unable to delete it.  To work around this
** problem, we delay 100 milliseconds and try to delete again.  Up
** to MX_DELETION_ATTEMPTs deletion attempts are run before giving
** up and returning an error.
*/
#define MX_DELETION_ATTEMPTS 5
static int winDelete(
  unqlite_vfs *pVfs,          /* Not used on win32 */
  const char *zFilename,      /* Name of file to delete */
  int syncDir                 /* Not used on win32 */
){
  int cnt = 0;
  DWORD rc;
  DWORD error = 0;
  void *zConverted;
  zConverted = convertUtf8Filename(zFilename);
  if( zConverted==0 ){
	   SXUNUSED(pVfs);
	   SXUNUSED(syncDir);
    return UNQLITE_NOMEM;
  }
  do{
	  DeleteFileW((LPCWSTR)zConverted);
  }while(   (   ((rc = GetFileAttributesW((LPCWSTR)zConverted)) != INVALID_FILE_ATTRIBUTES)
	  || ((error = GetLastError()) == ERROR_ACCESS_DENIED))
	  && (++cnt < MX_DELETION_ATTEMPTS)
	  && (Sleep(100), 1)
	  );
	HeapFree(GetProcessHeap(),0,zConverted);
 
  return (   (rc == INVALID_FILE_ATTRIBUTES) 
          && (error == ERROR_FILE_NOT_FOUND)) ? UNQLITE_OK : UNQLITE_IOERR;
}
/*
** Check the existance and status of a file.
*/
static int winAccess(
  unqlite_vfs *pVfs,         /* Not used  */
  const char *zFilename,     /* Name of file to check */
  int flags,                 /* Type of test to make on this file */
  int *pResOut               /* OUT: Result */
){
  WIN32_FILE_ATTRIBUTE_DATA sAttrData;
  DWORD attr;
  int rc = 0;
  void *zConverted;
  SXUNUSED(pVfs);

  zConverted = convertUtf8Filename(zFilename);
  if( zConverted==0 ){
    return UNQLITE_NOMEM;
  }
  SyZero(&sAttrData,sizeof(sAttrData));
  if( GetFileAttributesExW((WCHAR*)zConverted,
	  GetFileExInfoStandard, 
	  &sAttrData) ){
      /* For an UNQLITE_ACCESS_EXISTS query, treat a zero-length file
      ** as if it does not exist.
      */
      if(    flags==UNQLITE_ACCESS_EXISTS
          && sAttrData.nFileSizeHigh==0 
          && sAttrData.nFileSizeLow==0 ){
        attr = INVALID_FILE_ATTRIBUTES;
      }else{
        attr = sAttrData.dwFileAttributes;
      }
    }else{
      if( GetLastError()!=ERROR_FILE_NOT_FOUND ){
        HeapFree(GetProcessHeap(),0,zConverted);
        return UNQLITE_IOERR;
      }else{
        attr = INVALID_FILE_ATTRIBUTES;
      }
    }
  HeapFree(GetProcessHeap(),0,zConverted);
  switch( flags ){
     case UNQLITE_ACCESS_READWRITE:
      rc = (attr & FILE_ATTRIBUTE_READONLY)==0;
      break;
    case UNQLITE_ACCESS_READ:
    case UNQLITE_ACCESS_EXISTS:
	default:
      rc = attr!=INVALID_FILE_ATTRIBUTES;
      break;
  }
  *pResOut = rc;
  return UNQLITE_OK;
}
/*
** Turn a relative pathname into a full pathname.  Write the full
** pathname into zOut[].  zOut[] will be at least pVfs->mxPathname
** bytes in size.
*/
static int winFullPathname(
  unqlite_vfs *pVfs,            /* Pointer to vfs object */
  const char *zRelative,        /* Possibly relative input path */
  int nFull,                    /* Size of output buffer in bytes */
  char *zFull                   /* Output buffer */
){
  int nByte;
  void *zConverted;
  WCHAR *zTemp;
  char *zOut;
  SXUNUSED(nFull);
  zConverted = convertUtf8Filename(zRelative);
  if( zConverted == 0 ){
	  return UNQLITE_NOMEM;
  }
  nByte = GetFullPathNameW((WCHAR*)zConverted, 0, 0, 0) + 3;
  zTemp = (WCHAR *)HeapAlloc(GetProcessHeap(),0,nByte*sizeof(zTemp[0]) );
  if( zTemp==0 ){
	  HeapFree(GetProcessHeap(),0,zConverted);
	  return UNQLITE_NOMEM;
  }
  GetFullPathNameW((WCHAR*)zConverted, nByte, zTemp, 0);
  HeapFree(GetProcessHeap(),0,zConverted);
  zOut = unicodeToUtf8(zTemp);
  HeapFree(GetProcessHeap(),0,zTemp);
  if( zOut == 0 ){
    return UNQLITE_NOMEM;
  }
  Systrcpy(zFull,(sxu32)pVfs->mxPathname,zOut,0);
  HeapFree(GetProcessHeap(),0,zOut);
  return UNQLITE_OK;
}
/*
** Get the sector size of the device used to store
** file.
*/
static int getSectorSize(
    unqlite_vfs *pVfs,
    const char *zRelative     /* UTF-8 file name */
){
  DWORD bytesPerSector = UNQLITE_DEFAULT_SECTOR_SIZE;
  char zFullpath[MAX_PATH+1];
  int rc;
  DWORD dwRet = 0;
  DWORD dwDummy;
  /*
  ** We need to get the full path name of the file
  ** to get the drive letter to look up the sector
  ** size.
  */
  rc = winFullPathname(pVfs, zRelative, MAX_PATH, zFullpath);
  if( rc == UNQLITE_OK )
  {
    void *zConverted = convertUtf8Filename(zFullpath);
    if( zConverted ){
        /* trim path to just drive reference */
        WCHAR *p = (WCHAR *)zConverted;
        for(;*p;p++){
          if( *p == '\\' ){
            *p = '\0';
            break;
          }
        }
        dwRet = GetDiskFreeSpaceW((WCHAR*)zConverted,
                                  &dwDummy,
                                  &bytesPerSector,
                                  &dwDummy,
                                  &dwDummy);
		 HeapFree(GetProcessHeap(),0,zConverted);
	}
    if( !dwRet ){
      bytesPerSector = UNQLITE_DEFAULT_SECTOR_SIZE;
    }
  }
  return (int) bytesPerSector; 
}
/*
** Sleep for a little while.  Return the amount of time slept.
*/
static int winSleep(unqlite_vfs *pVfs, int microsec){
  Sleep((microsec+999)/1000);
  SXUNUSED(pVfs);
  return ((microsec+999)/1000)*1000;
}
/*
 * Export the current system time.
 */
static int winCurrentTime(unqlite_vfs *pVfs,Sytm *pOut)
{
	SYSTEMTIME sSys;
	SXUNUSED(pVfs);
	GetSystemTime(&sSys);
	SYSTEMTIME_TO_SYTM(&sSys,pOut);
	return UNQLITE_OK;
}
/*
** The idea is that this function works like a combination of
** GetLastError() and FormatMessage() on windows (or errno and
** strerror_r() on unix). After an error is returned by an OS
** function, UnQLite calls this function with zBuf pointing to
** a buffer of nBuf bytes. The OS layer should populate the
** buffer with a nul-terminated UTF-8 encoded error message
** describing the last IO error to have occurred within the calling
** thread.
**
** If the error message is too large for the supplied buffer,
** it should be truncated. The return value of xGetLastError
** is zero if the error message fits in the buffer, or non-zero
** otherwise (if the message was truncated). If non-zero is returned,
** then it is not necessary to include the nul-terminator character
** in the output buffer.
*/
static int winGetLastError(unqlite_vfs *pVfs, int nBuf, char *zBuf)
{
  /* FormatMessage returns 0 on failure.  Otherwise it
  ** returns the number of TCHARs written to the output
  ** buffer, excluding the terminating null char.
  */
  DWORD error = GetLastError();
  WCHAR *zTempWide = 0;
  DWORD dwLen;
  char *zOut = 0;

  SXUNUSED(pVfs);
  dwLen = FormatMessageW(
	  FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	  0,
	  error,
	  0,
	  (LPWSTR) &zTempWide,
	  0,
	  0
	  );
    if( dwLen > 0 ){
      /* allocate a buffer and convert to UTF8 */
      zOut = unicodeToUtf8(zTempWide);
      /* free the system buffer allocated by FormatMessage */
      LocalFree(zTempWide);
    }
	if( 0 == dwLen ){
		Systrcpy(zBuf,(sxu32)nBuf,"OS Error",sizeof("OS Error")-1);
	}else{
		/* copy a maximum of nBuf chars to output buffer */
		Systrcpy(zBuf,(sxu32)nBuf,zOut,0 /* Compute input length automatically */);
		/* free the UTF8 buffer */
		HeapFree(GetProcessHeap(),0,zOut);
	}
  return 0;
}
/*
** Open a file.
*/
static int winOpen(
  unqlite_vfs *pVfs,        /* Not used */
  const char *zName,        /* Name of the file (UTF-8) */
  unqlite_file *id,         /* Write the UnQLite file handle here */
  unsigned int flags                /* Open mode flags */
){
  HANDLE h;
  DWORD dwDesiredAccess;
  DWORD dwShareMode;
  DWORD dwCreationDisposition;
  DWORD dwFlagsAndAttributes = 0;
  winFile *pFile = (winFile*)id;
  void *zConverted;              /* Filename in OS encoding */
  const char *zUtf8Name = zName; /* Filename in UTF-8 encoding */
  int isExclusive  = (flags & UNQLITE_OPEN_EXCLUSIVE);
  int isDelete     = (flags & UNQLITE_OPEN_TEMP_DB);
  int isCreate     = (flags & UNQLITE_OPEN_CREATE);
  int isReadWrite  = (flags & UNQLITE_OPEN_READWRITE);

  pFile->h = INVALID_HANDLE_VALUE;
  /* Convert the filename to the system encoding. */
  zConverted = convertUtf8Filename(zUtf8Name);
  if( zConverted==0 ){
    return UNQLITE_NOMEM;
  }
  if( isReadWrite ){
    dwDesiredAccess = GENERIC_READ | GENERIC_WRITE;
  }else{
    dwDesiredAccess = GENERIC_READ;
  }
  /* UNQLITE_OPEN_EXCLUSIVE is used to make sure that a new file is 
  ** created.
  */
  if( isExclusive ){
    /* Creates a new file, only if it does not already exist. */
    /* If the file exists, it fails. */
    dwCreationDisposition = CREATE_NEW;
  }else if( isCreate ){
    /* Open existing file, or create if it doesn't exist */
    dwCreationDisposition = OPEN_ALWAYS;
  }else{
    /* Opens a file, only if it exists. */
    dwCreationDisposition = OPEN_EXISTING;
  }

  dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;

  if( isDelete ){
    dwFlagsAndAttributes = FILE_ATTRIBUTE_TEMPORARY
                               | FILE_ATTRIBUTE_HIDDEN
                               | FILE_FLAG_DELETE_ON_CLOSE;
  }else{
    dwFlagsAndAttributes = FILE_ATTRIBUTE_NORMAL;
  }
  h = CreateFileW((WCHAR*)zConverted,
       dwDesiredAccess,
       dwShareMode,
       NULL,
       dwCreationDisposition,
       dwFlagsAndAttributes,
       NULL
    );
  if( h==INVALID_HANDLE_VALUE ){
    pFile->lastErrno = GetLastError();
    HeapFree(GetProcessHeap(),0,zConverted);
	return UNQLITE_IOERR;
  }
  SyZero(pFile,sizeof(*pFile));
  pFile->pMethod = &winIoMethod;
  pFile->h = h;
  pFile->lastErrno = NO_ERROR;
  pFile->pVfs = pVfs;
  pFile->sectorSize = getSectorSize(pVfs, zUtf8Name);
  HeapFree(GetProcessHeap(),0,zConverted);
  return UNQLITE_OK;
}
/* Open a file in a read-only mode */
static HANDLE OpenReadOnly(LPCWSTR pPath)
{
	DWORD dwType = FILE_ATTRIBUTE_NORMAL | FILE_FLAG_RANDOM_ACCESS;
	DWORD dwShare = FILE_SHARE_READ | FILE_SHARE_WRITE;
	DWORD dwAccess = GENERIC_READ;
	DWORD dwCreate = OPEN_EXISTING;	
	HANDLE pHandle;
	pHandle = CreateFileW(pPath, dwAccess, dwShare, 0, dwCreate, dwType, 0);
	if( pHandle == INVALID_HANDLE_VALUE){
		return 0;
	}
	return pHandle;
}
/* int (*xMmap)(const char *, void **, jx9_int64 *) */
static int WinVfs_Mmap(const char *zPath, void **ppMap, unqlite_int64 *pSize)
{
	DWORD dwSizeLow, dwSizeHigh;
	HANDLE pHandle, pMapHandle;
	void *pConverted, *pView;

	pConverted = convertUtf8Filename(zPath);
	if( pConverted == 0 ){
		return -1;
	}
	pHandle = OpenReadOnly((LPCWSTR)pConverted);
	HeapFree(GetProcessHeap(), 0, pConverted);
	if( pHandle == 0 ){
		return -1;
	}
	/* Get the file size */
	dwSizeLow = GetFileSize(pHandle, &dwSizeHigh);
	/* Create the mapping */
	pMapHandle = CreateFileMappingW(pHandle, 0, PAGE_READONLY, dwSizeHigh, dwSizeLow, 0);
	if( pMapHandle == 0 ){
		CloseHandle(pHandle);
		return -1;
	}
	*pSize = ((unqlite_int64)dwSizeHigh << 32) | dwSizeLow;
	/* Obtain the view */
	pView = MapViewOfFile(pMapHandle, FILE_MAP_READ, 0, 0, (SIZE_T)(*pSize));
	if( pView ){
		/* Let the upper layer point to the view */
		*ppMap = pView;
	}
	/* Close the handle
	 * According to MSDN it's OK the close the HANDLES.
	 */
	CloseHandle(pMapHandle);
	CloseHandle(pHandle);
	return pView ? UNQLITE_OK : -1;
}
/* void (*xUnmap)(void *, jx9_int64)  */
static void WinVfs_Unmap(void *pView, unqlite_int64 nSize)
{
	nSize = 0; /* Compiler warning */
	UnmapViewOfFile(pView);
}
/*
 * Export the Windows Vfs.
 */
UNQLITE_PRIVATE const unqlite_vfs * unqliteExportBuiltinVfs(void)
{
	static const unqlite_vfs sWinvfs = {
		"Windows",           /* Vfs name */
		1,                   /* Vfs structure version */
		sizeof(winFile),     /* szOsFile */
		MAX_PATH,            /* mxPathName */
		winOpen,             /* xOpen */
		winDelete,           /* xDelete */
		winAccess,           /* xAccess */
		winFullPathname,     /* xFullPathname */
		0,                   /* xTmp */
		WinVfs_Mmap,		 /* xMmap() */
		WinVfs_Unmap,		 /* xUnmap() */
		winSleep,            /* xSleep */
		winCurrentTime,      /* xCurrentTime */
		winGetLastError,     /* xGetLastError */
	};
	return &sWinvfs;
}
#endif /* __WINNT__ */
/*
 * ----------------------------------------------------------
 * File: pager.c
 * ID: 57ff77347402fbf6892af589ff8a5df7
 * ----------------------------------------------------------
 */
/*
 * Symisc unQLite: An Embeddable NoSQL (Post Modern) Database Engine.
 * Copyright (C) 2012-2013, Symisc Systems http://unqlite.symisc.net/
 * Version 1.1.6
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
 /* $SymiscID: pager.c v1.1 Win7 2012-11-29 03:46 stable <chm@symisc.net> $ */
#ifndef UNQLITE_AMALGAMATION
#include "unqliteInt.h"
#endif
/*
** This file implements the pager and the transaction manager for UnQLite (Mostly inspired from the SQLite3 Source tree).
**
** The Pager.eState variable stores the current 'state' of a pager. A
** pager may be in any one of the seven states shown in the following
** state diagram.
**
**                            OPEN <------+------+
**                              |         |      |
**                              V         |      |
**               +---------> READER-------+      |
**               |              |                |
**               |              V                |
**               |<-------WRITER_LOCKED--------->| 
**               |              |                |  
**               |              V                |
**               |<------WRITER_CACHEMOD-------->|
**               |              |                |
**               |              V                |
**               |<-------WRITER_DBMOD---------->|
**               |              |                |
**               |              V                |
**               +<------WRITER_FINISHED-------->+
** 
**  OPEN:
**
**    The pager starts up in this state. Nothing is guaranteed in this
**    state - the file may or may not be locked and the database size is
**    unknown. The database may not be read or written.
**
**    * No read or write transaction is active.
**    * Any lock, or no lock at all, may be held on the database file.
**    * The dbSize and dbOrigSize variables may not be trusted.
**
**  READER:
**
**    In this state all the requirements for reading the database in 
**    rollback mode are met. Unless the pager is (or recently
**    was) in exclusive-locking mode, a user-level read transaction is 
**    open. The database size is known in this state.
** 
**    * A read transaction may be active (but a write-transaction cannot).
**    * A SHARED or greater lock is held on the database file.
**    * The dbSize variable may be trusted (even if a user-level read 
**      transaction is not active). The dbOrigSize variables
**      may not be trusted at this point.
**    * Even if a read-transaction is not open, it is guaranteed that 
**      there is no hot-journal in the file-system.
**
**  WRITER_LOCKED:
**
**    The pager moves to this state from READER when a write-transaction
**    is first opened on the database. In WRITER_LOCKED state, all locks 
**    required to start a write-transaction are held, but no actual 
**    modifications to the cache or database have taken place.
**
**    In rollback mode, a RESERVED or (if the transaction was opened with 
**    EXCLUSIVE flag) EXCLUSIVE lock is obtained on the database file when
**    moving to this state, but the journal file is not written to or opened 
**    to in this state. If the transaction is committed or rolled back while 
**    in WRITER_LOCKED state, all that is required is to unlock the database 
**    file.
**
**    * A write transaction is active.
**    * If the connection is open in rollback-mode, a RESERVED or greater 
**      lock is held on the database file.
**    * The dbSize and dbOrigSize variables are all valid.
**    * The contents of the pager cache have not been modified.
**    * The journal file may or may not be open.
**    * Nothing (not even the first header) has been written to the journal.
**
**  WRITER_CACHEMOD:
**
**    A pager moves from WRITER_LOCKED state to this state when a page is
**    first modified by the upper layer. In rollback mode the journal file
**    is opened (if it is not already open) and a header written to the
**    start of it. The database file on disk has not been modified.
**
**    * A write transaction is active.
**    * A RESERVED or greater lock is held on the database file.
**    * The journal file is open and the first header has been written 
**      to it, but the header has not been synced to disk.
**    * The contents of the page cache have been modified.
**
**  WRITER_DBMOD:
**
**    The pager transitions from WRITER_CACHEMOD into WRITER_DBMOD state
**    when it modifies the contents of the database file.
**
**    * A write transaction is active.
**    * An EXCLUSIVE or greater lock is held on the database file.
**    * The journal file is open and the first header has been written 
**      and synced to disk.
**    * The contents of the page cache have been modified (and possibly
**      written to disk).
**
**  WRITER_FINISHED:
**
**    A rollback-mode pager changes to WRITER_FINISHED state from WRITER_DBMOD
**    state after the entire transaction has been successfully written into the
**    database file. In this state the transaction may be committed simply
**    by finalizing the journal file. Once in WRITER_FINISHED state, it is 
**    not possible to modify the database further. At this point, the upper 
**    layer must either commit or rollback the transaction.
**
**    * A write transaction is active.
**    * An EXCLUSIVE or greater lock is held on the database file.
**    * All writing and syncing of journal and database data has finished.
**      If no error occured, all that remains is to finalize the journal to
**      commit the transaction. If an error did occur, the caller will need
**      to rollback the transaction. 
**  
**
*/
#define PAGER_OPEN                  0
#define PAGER_READER                1
#define PAGER_WRITER_LOCKED         2
#define PAGER_WRITER_CACHEMOD       3
#define PAGER_WRITER_DBMOD          4
#define PAGER_WRITER_FINISHED       5
/*
** Journal files begin with the following magic string.  The data
** was obtained from /dev/random.  It is used only as a sanity check.
**
** NOTE: These values must be different from the one used by SQLite3
** to avoid journal file collision.
**
*/
static const unsigned char aJournalMagic[] = {
  0xa6, 0xe8, 0xcd, 0x2b, 0x1c, 0x92, 0xdb, 0x9f,
};
/*
** The journal header size for this pager. This is usually the same 
** size as a single disk sector. See also setSectorSize().
*/
#define JOURNAL_HDR_SZ(pPager) (pPager->iSectorSize)
/*
 * Database page handle.
 * Each raw disk page is represented in memory by an instance
 * of the following structure.
 */
typedef struct Page Page;
struct Page {
  /* Must correspond to unqlite_page */
  unsigned char *zData;           /* Content of this page */
  void *pUserData;                /* Extra content */
  pgno pgno;                      /* Page number for this page */
  /**********************************************************************
  ** Elements above are public.  All that follows is private to pcache.c
  ** and should not be accessed by other modules.
  */
  Pager *pPager;                 /* The pager this page is part of */
  int flags;                     /* Page flags defined below */
  int nRef;                      /* Number of users of this page */
  Page *pNext, *pPrev;    /* A list of all pages */
  Page *pDirtyNext;             /* Next element in list of dirty pages */
  Page *pDirtyPrev;             /* Previous element in list of dirty pages */
  Page *pNextCollide,*pPrevCollide; /* Collission chain */
  Page *pNextHot,*pPrevHot;    /* Hot dirty pages chain */
};
/* Bit values for Page.flags */
#define PAGE_DIRTY             0x002  /* Page has changed */
#define PAGE_NEED_SYNC         0x004  /* fsync the rollback journal before
                                       ** writing this page to the database */
#define PAGE_DONT_WRITE        0x008  /* Dont write page content to disk */
#define PAGE_NEED_READ         0x010  /* Content is unread */
#define PAGE_IN_JOURNAL        0x020  /* Page written to the journal */
#define PAGE_HOT_DIRTY         0x040  /* Hot dirty page */
#define PAGE_DONT_MAKE_HOT     0x080  /* Dont make this page Hot. In other words,
									   * do not link it to the hot dirty list.
									   */
/*
 * Each active database pager is represented by an instance of
 * the following structure.
 */
struct Pager
{
  SyMemBackend *pAllocator;      /* Memory backend */
  unqlite *pDb;                  /* DB handle that own this instance */
  unqlite_kv_engine *pEngine;    /* Underlying KV storage engine */
  char *zFilename;               /* Name of the database file */
  char *zJournal;                /* Name of the journal file */
  unqlite_vfs *pVfs;             /* Underlying virtual file system */
  unqlite_file *pfd,*pjfd;       /* File descriptors for database and journal */
  pgno dbSize;                   /* Number of pages in the file */
  pgno dbOrigSize;               /* dbSize before the current change */
  sxi64 dbByteSize;              /* Database size in bytes */
  void *pMmap;                   /* Read-only Memory view (mmap) of the whole file if requested (UNQLITE_OPEN_MMAP). */
  sxu32 nRec;                    /* Number of pages written to the journal */
  SyPRNGCtx sPrng;               /* PRNG Context */
  sxu32 cksumInit;               /* Quasi-random value added to every checksum */
  sxu32 iOpenFlags;              /* Flag passed to unqlite_open() after processing */
  sxi64 iJournalOfft;            /* Journal offset we are reading from */
  int (*xBusyHandler)(void *);   /* Busy handler */
  void *pBusyHandlerArg;         /* First arg to xBusyHandler() */
  void (*xPageUnpin)(void *);    /* Page Unpin callback */
  void (*xPageReload)(void *);   /* Page Reload callback */
  Bitvec *pVec;                  /* Bitmap */
  Page *pHeader;                 /* Page one of the database (Unqlite header) */
  Sytm tmCreate;                 /* Database creation time */
  SyString sKv;                  /* Underlying Key/Value storage engine name */
  int iState;                    /* Pager state */
  int iLock;                     /* Lock state */
  sxi32 iFlags;                  /* Control flags (see below) */
  int is_mem;                    /* True for an in-memory database */
  int is_rdonly;                 /* True for a read-only database */
  int no_jrnl;                   /* TRUE to omit journaling */
  int iPageSize;                 /* Page size in bytes (default 4K) */
  int iSectorSize;               /* Size of a single sector on disk */
  unsigned char *zTmpPage;       /* Temporary page */
  Page *pFirstDirty;             /* First dirty pages */
  Page *pDirty;                  /* Transient list of dirty pages */
  Page *pAll;                    /* List of all pages */
  Page *pHotDirty;               /* List of hot dirty pages */
  Page *pFirstHot;               /* First hot dirty page */
  sxu32 nHot;                    /* Total number of hot dirty pages */
  Page **apHash;                 /* Page table */
  sxu32 nSize;                   /* apHash[] size: Must be a power of two  */
  sxu32 nPage;                   /* Total number of page loaded in memory */
  sxu32 nCacheMax;               /* Maximum page to cache*/
};
/* Control flags */
#define PAGER_CTRL_COMMIT_ERR   0x001 /* Commit error */
#define PAGER_CTRL_DIRTY_COMMIT 0x002 /* Dirty commit has been applied */ 
/*
** Read a 32-bit integer from the given file descriptor. 
** All values are stored on disk as big-endian.
*/
static int ReadInt32(unqlite_file *pFd,sxu32 *pOut,sxi64 iOfft)
{
	unsigned char zBuf[4];
	int rc;
	rc = unqliteOsRead(pFd,zBuf,sizeof(zBuf),iOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	SyBigEndianUnpack32(zBuf,pOut);
	return UNQLITE_OK;
}
/*
** Read a 64-bit integer from the given file descriptor. 
** All values are stored on disk as big-endian.
*/
static int ReadInt64(unqlite_file *pFd,sxu64 *pOut,sxi64 iOfft)
{
	unsigned char zBuf[8];
	int rc;
	rc = unqliteOsRead(pFd,zBuf,sizeof(zBuf),iOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	SyBigEndianUnpack64(zBuf,pOut);
	return UNQLITE_OK;
}
/*
** Write a 32-bit integer into the given file descriptor.
*/
static int WriteInt32(unqlite_file *pFd,sxu32 iNum,sxi64 iOfft)
{
	unsigned char zBuf[4];
	int rc;
	SyBigEndianPack32(zBuf,iNum);
	rc = unqliteOsWrite(pFd,zBuf,sizeof(zBuf),iOfft);
	return rc;
}
/*
** Write a 64-bit integer into the given file descriptor.
*/
static int WriteInt64(unqlite_file *pFd,sxu64 iNum,sxi64 iOfft)
{
	unsigned char zBuf[8];
	int rc;
	SyBigEndianPack64(zBuf,iNum);
	rc = unqliteOsWrite(pFd,zBuf,sizeof(zBuf),iOfft);
	return rc;
}
/*
** The maximum allowed sector size. 64KiB. If the xSectorsize() method 
** returns a value larger than this, then MAX_SECTOR_SIZE is used instead.
** This could conceivably cause corruption following a power failure on
** such a system. This is currently an undocumented limit.
*/
#define MAX_SECTOR_SIZE 0x10000
/*
** Get the size of a single sector on disk.
** The sector size will be used used  to determine the size
** and alignment of journal header and within created journal files.
**
** The default sector size is set to 512.
*/
static int GetSectorSize(unqlite_file *pFd)
{
	int iSectorSize = UNQLITE_DEFAULT_SECTOR_SIZE;
	if( pFd ){
		iSectorSize = unqliteOsSectorSize(pFd);
		if( iSectorSize < 32 ){
			iSectorSize = 512;
		}
		if( iSectorSize > MAX_SECTOR_SIZE ){
			iSectorSize = MAX_SECTOR_SIZE;
		}
	}
	return iSectorSize;
}
/* Hash function for page number  */
#define PAGE_HASH(PNUM) (PNUM)
/*
 * Fetch a page from the cache.
 */
static Page * pager_fetch_page(Pager *pPager,pgno page_num)
{
	Page *pEntry;
	if( pPager->nPage < 1 ){
		/* Don't bother hashing */
		return 0;
	}
	/* Perform the lookup */
	pEntry = pPager->apHash[PAGE_HASH(page_num) & (pPager->nSize - 1)];
	for(;;){
		if( pEntry == 0 ){
			break;
		}
		if( pEntry->pgno == page_num ){
			return pEntry;
		}
		/* Point to the next entry in the collision chain */
		pEntry = pEntry->pNextCollide;
	}
	/* No such page */
	return 0;
}
/*
 * Allocate and initialize a new page.
 */
static Page * pager_alloc_page(Pager *pPager,pgno num_page)
{
	Page *pNew;
	
	pNew = (Page *)SyMemBackendPoolAlloc(pPager->pAllocator,sizeof(Page)+pPager->iPageSize);
	if( pNew == 0 ){
		return 0;
	}
	/* Zero the structure */
	SyZero(pNew,sizeof(Page)+pPager->iPageSize);
	/* Page data */
	pNew->zData = (unsigned char *)&pNew[1];
	/* Fill in the structure */
	pNew->pPager = pPager;
	pNew->nRef = 1;
	pNew->pgno = num_page;
	return pNew;
}
/*
 * Increment the reference count of a given page.
 */
static void page_ref(Page *pPage)
{
	if( pPage->pPager->pAllocator->pMutexMethods ){
		SyMutexEnter(pPage->pPager->pAllocator->pMutexMethods, pPage->pPager->pAllocator->pMutex);
	}
	pPage->nRef++;
	if( pPage->pPager->pAllocator->pMutexMethods ){
		SyMutexLeave(pPage->pPager->pAllocator->pMutexMethods, pPage->pPager->pAllocator->pMutex);
	}
}
/*
 * Release an in-memory page after its reference count reach zero.
 */
static int pager_release_page(Pager *pPager,Page *pPage)
{
	int rc = UNQLITE_OK;
	if( !(pPage->flags & PAGE_DIRTY)){
		/* Invoke the unpin callback if available */
		if( pPager->xPageUnpin && pPage->pUserData ){
			pPager->xPageUnpin(pPage->pUserData);
		}
		pPage->pUserData = 0;
		SyMemBackendPoolFree(pPager->pAllocator,pPage);
	}else{
		/* Dirty page, it will be released later when a dirty commit
		 * or the final commit have been applied.
		 */
		rc = UNQLITE_LOCKED;
	}
	return rc;
}
/* Forward declaration */
static int pager_unlink_page(Pager *pPager,Page *pPage);
/*
 * Decrement the reference count of a given page.
 */
static void page_unref(Page *pPage)
{
	int nRef;
	if( pPage->pPager->pAllocator->pMutexMethods ){
		SyMutexEnter(pPage->pPager->pAllocator->pMutexMethods, pPage->pPager->pAllocator->pMutex);
	}
	nRef = pPage->nRef--;
	if( pPage->pPager->pAllocator->pMutexMethods ){
		SyMutexLeave(pPage->pPager->pAllocator->pMutexMethods, pPage->pPager->pAllocator->pMutex);
	}
	if( nRef == 0){
		Pager *pPager = pPage->pPager;
		if( !(pPage->flags & PAGE_DIRTY)  ){
			pager_unlink_page(pPager,pPage);
			/* Release the page */
			pager_release_page(pPager,pPage);
		}else{
			if( pPage->flags & PAGE_DONT_MAKE_HOT ){
				/* Do not add this page to the hot dirty list */
				return;
			}
			if( !(pPage->flags & PAGE_HOT_DIRTY) ){
				/* Add to the hot dirty list */
				pPage->pPrevHot = 0;
				if( pPager->pFirstHot == 0 ){
					pPager->pFirstHot = pPager->pHotDirty = pPage;
				}else{
					pPage->pNextHot = pPager->pHotDirty;
					if( pPager->pHotDirty ){
						pPager->pHotDirty->pPrevHot = pPage;
					}
					pPager->pHotDirty = pPage;
				}
				pPager->nHot++;
				pPage->flags |= PAGE_HOT_DIRTY;
			}
		}
	}
}
/*
 * Link a freshly created page to the list of active page.
 */
static int pager_link_page(Pager *pPager,Page *pPage)
{
	sxu32 nBucket;
	/* Install in the corresponding bucket */
	nBucket = PAGE_HASH(pPage->pgno) & (pPager->nSize - 1);
	pPage->pNextCollide = pPager->apHash[nBucket];
	if( pPager->apHash[nBucket] ){
		pPager->apHash[nBucket]->pPrevCollide = pPage;
	}
	pPager->apHash[nBucket] = pPage;
	/* Link to the list of active pages */
	MACRO_LD_PUSH(pPager->pAll,pPage);
	pPager->nPage++;
	if( (pPager->nPage >= pPager->nSize * 4)  && pPager->nPage < 100000 ){
		/* Grow the hashtable */
		sxu32 nNewSize = pPager->nSize << 1;
		Page *pEntry,**apNew;
		sxu32 n;
		apNew = (Page **)SyMemBackendAlloc(pPager->pAllocator, nNewSize * sizeof(Page *));
		if( apNew ){
			sxu32 iBucket;
			/* Zero the new table */
			SyZero((void *)apNew, nNewSize * sizeof(Page *));
			/* Rehash all entries */
			n = 0;
			pEntry = pPager->pAll;
			for(;;){
				/* Loop one */
				if( n >= pPager->nPage ){
					break;
				}
				pEntry->pNextCollide = pEntry->pPrevCollide = 0;
				/* Install in the new bucket */
				iBucket = PAGE_HASH(pEntry->pgno) & (nNewSize - 1);
				pEntry->pNextCollide = apNew[iBucket];
				if( apNew[iBucket] ){
					apNew[iBucket]->pPrevCollide = pEntry;
				}
				apNew[iBucket] = pEntry;
				/* Point to the next entry */
				pEntry = pEntry->pNext;
				n++;
			}
			/* Release the old table and reflect the change */
			SyMemBackendFree(pPager->pAllocator,(void *)pPager->apHash);
			pPager->apHash = apNew;
			pPager->nSize  = nNewSize;
		}
	}
	return UNQLITE_OK;
}
/*
 * Unlink a page from the list of active pages.
 */
static int pager_unlink_page(Pager *pPager,Page *pPage)
{
	if( pPage->pNextCollide ){
		pPage->pNextCollide->pPrevCollide = pPage->pPrevCollide;
	}
	if( pPage->pPrevCollide ){
		pPage->pPrevCollide->pNextCollide = pPage->pNextCollide;
	}else{
		sxu32 nBucket = PAGE_HASH(pPage->pgno) & (pPager->nSize - 1);
		pPager->apHash[nBucket] = pPage->pNextCollide;
	}
	MACRO_LD_REMOVE(pPager->pAll,pPage);
	pPager->nPage--;
	return UNQLITE_OK;
}
/*
 * Update the content of a cached page.
 */
static int pager_fill_page(Pager *pPager,pgno iNum,void *pContents)
{
	Page *pPage;
	/* Fetch the page from the catch */
	pPage = pager_fetch_page(pPager,iNum);
	if( pPage == 0 ){
		return SXERR_NOTFOUND;
	}
	/* Reflect the change */
	SyMemcpy(pContents,pPage->zData,pPager->iPageSize);

	return UNQLITE_OK;
}
/*
 * Read the content of a page from disk.
 */
static int pager_get_page_contents(Pager *pPager,Page *pPage,int noContent)
{
	int rc = UNQLITE_OK;
	if( pPager->is_mem || noContent || pPage->pgno >= pPager->dbSize ){
		/* Do not bother reading, zero the page contents only */
		SyZero(pPage->zData,pPager->iPageSize);
		return UNQLITE_OK;
	}
	if( (pPager->iOpenFlags & UNQLITE_OPEN_MMAP) && (pPager->pMmap /* Paranoid edition */) ){
		unsigned char *zMap = (unsigned char *)pPager->pMmap;
		pPage->zData = &zMap[pPage->pgno * pPager->iPageSize];
	}else{
		/* Read content */
		rc = unqliteOsRead(pPager->pfd,pPage->zData,pPager->iPageSize,pPage->pgno * pPager->iPageSize);
	}
	return rc;
}
/*
 * Add a page to the dirty list.
 */
static void pager_page_to_dirty_list(Pager *pPager,Page *pPage)
{
	if( pPage->flags & PAGE_DIRTY ){
		/* Already set */
		return;
	}
	/* Mark the page as dirty */
	pPage->flags |= PAGE_DIRTY|PAGE_NEED_SYNC|PAGE_IN_JOURNAL;
	/* Link to the list */
	pPage->pDirtyPrev = 0;
	pPage->pDirtyNext = pPager->pDirty;
	if( pPager->pDirty ){
		pPager->pDirty->pDirtyPrev = pPage;
	}
	pPager->pDirty = pPage;
	if( pPager->pFirstDirty == 0 ){
		pPager->pFirstDirty = pPage;
	}
}
/*
 * Merge sort.
 * The merge sort implementation is based on the one used by
 * the PH7 Embeddable PHP Engine (http://ph7.symisc.net/).
 */
/*
** Inputs:
**   a:       A sorted, null-terminated linked list.  (May be null).
**   b:       A sorted, null-terminated linked list.  (May be null).
**   cmp:     A pointer to the comparison function.
**
** Return Value:
**   A pointer to the head of a sorted list containing the elements
**   of both a and b.
**
** Side effects:
**   The "next", "prev" pointers for elements in the lists a and b are
**   changed.
*/
static Page * page_merge_dirty(Page *pA, Page *pB)
{
	Page result, *pTail;
    /* Prevent compiler warning */
	result.pDirtyNext = result.pDirtyPrev = 0;
	pTail = &result;
	while( pA && pB ){
		if( pA->pgno < pB->pgno ){
			pTail->pDirtyPrev = pA;
			pA->pDirtyNext = pTail;
			pTail = pA;
			pA = pA->pDirtyPrev;
		}else{
			pTail->pDirtyPrev = pB;
			pB->pDirtyNext = pTail;
			pTail = pB;
			pB = pB->pDirtyPrev;
		}
	}
	if( pA ){
		pTail->pDirtyPrev = pA;
		pA->pDirtyNext = pTail;
	}else if( pB ){
		pTail->pDirtyPrev = pB;
		pB->pDirtyNext = pTail;
	}else{
		pTail->pDirtyPrev = pTail->pDirtyNext = 0;
	}
	return result.pDirtyPrev;
}
/*
** Inputs:
**   Map:       Input hashmap
**   cmp:       A comparison function.
**
** Return Value:
**   Sorted hashmap.
**
** Side effects:
**   The "next" pointers for elements in list are changed.
*/
#define N_SORT_BUCKET  32
static Page * pager_get_dirty_pages(Pager *pPager)
{
	Page *a[N_SORT_BUCKET], *p, *pIn;
	sxu32 i;
	if( pPager->pFirstDirty == 0 ){
		/* Don't bother sorting, the list is already empty */
		return 0;
	}
	SyZero(a, sizeof(a));
	/* Point to the first inserted entry */
	pIn = pPager->pFirstDirty;
	while( pIn ){
		p = pIn;
		pIn = p->pDirtyPrev;
		p->pDirtyPrev = 0;
		for(i=0; i<N_SORT_BUCKET-1; i++){
			if( a[i]==0 ){
				a[i] = p;
				break;
			}else{
				p = page_merge_dirty(a[i], p);
				a[i] = 0;
			}
		}
		if( i==N_SORT_BUCKET-1 ){
			/* To get here, there need to be 2^(N_SORT_BUCKET) elements in he input list.
			 * But that is impossible.
			 */
			a[i] = page_merge_dirty(a[i], p);
		}
	}
	p = a[0];
	for(i=1; i<N_SORT_BUCKET; i++){
		p = page_merge_dirty(p,a[i]);
	}
	p->pDirtyNext = 0;
	return p;
}
/*
 * See block comment above.
 */
static Page * page_merge_hot(Page *pA, Page *pB)
{
	Page result, *pTail;
    /* Prevent compiler warning */
	result.pNextHot = result.pPrevHot = 0;
	pTail = &result;
	while( pA && pB ){
		if( pA->pgno < pB->pgno ){
			pTail->pPrevHot = pA;
			pA->pNextHot = pTail;
			pTail = pA;
			pA = pA->pPrevHot;
		}else{
			pTail->pPrevHot = pB;
			pB->pNextHot = pTail;
			pTail = pB;
			pB = pB->pPrevHot;
		}
	}
	if( pA ){
		pTail->pPrevHot = pA;
		pA->pNextHot = pTail;
	}else if( pB ){
		pTail->pPrevHot = pB;
		pB->pNextHot = pTail;
	}else{
		pTail->pPrevHot = pTail->pNextHot = 0;
	}
	return result.pPrevHot;
}
/*
** Inputs:
**   Map:       Input hashmap
**   cmp:       A comparison function.
**
** Return Value:
**   Sorted hashmap.
**
** Side effects:
**   The "next" pointers for elements in list are changed.
*/
#define N_SORT_BUCKET  32
static Page * pager_get_hot_pages(Pager *pPager)
{
	Page *a[N_SORT_BUCKET], *p, *pIn;
	sxu32 i;
	if( pPager->pFirstHot == 0 ){
		/* Don't bother sorting, the list is already empty */
		return 0;
	}
	SyZero(a, sizeof(a));
	/* Point to the first inserted entry */
	pIn = pPager->pFirstHot;
	while( pIn ){
		p = pIn;
		pIn = p->pPrevHot;
		p->pPrevHot = 0;
		for(i=0; i<N_SORT_BUCKET-1; i++){
			if( a[i]==0 ){
				a[i] = p;
				break;
			}else{
				p = page_merge_hot(a[i], p);
				a[i] = 0;
			}
		}
		if( i==N_SORT_BUCKET-1 ){
			/* To get here, there need to be 2^(N_SORT_BUCKET) elements in he input list.
			 * But that is impossible.
			 */
			a[i] = page_merge_hot(a[i], p);
		}
	}
	p = a[0];
	for(i=1; i<N_SORT_BUCKET; i++){
		p = page_merge_hot(p,a[i]);
	}
	p->pNextHot = 0;
	return p;
}
/*
** The format for the journal header is as follows:
** - 8 bytes: Magic identifying journal format.
** - 4 bytes: Number of records in journal.
** - 4 bytes: Random number used for page hash.
** - 8 bytes: Initial database page count.
** - 4 bytes: Sector size used by the process that wrote this journal.
** - 4 bytes: Database page size.
** 
** Followed by (JOURNAL_HDR_SZ - 28) bytes of unused space.
*/
/*
** Open the journal file and extract its header information.
**
** If the header is read successfully, *pNRec is set to the number of
** page records following this header and *pDbSize is set to the size of the
** database before the transaction began, in pages. Also, pPager->cksumInit
** is set to the value read from the journal header. UNQLITE_OK is returned
** in this case.
**
** If the journal header file appears to be corrupted, UNQLITE_DONE is
** returned and *pNRec and *PDbSize are undefined.  If JOURNAL_HDR_SZ bytes
** cannot be read from the journal file an error code is returned.
*/
static int pager_read_journal_header(
  Pager *pPager,               /* Pager object */
  sxu32 *pNRec,                /* OUT: Value read from the nRec field */
  pgno  *pDbSize               /* OUT: Value of original database size field */
)
{
	sxu32 iPageSize,iSectorSize;
	unsigned char zMagic[8];
	sxi64 iHdrOfft;
	sxi64 iSize;
	int rc;
	/* Offset to start reading from */
	iHdrOfft = 0;
	/* Get the size of the journal */
	rc = unqliteOsFileSize(pPager->pjfd,&iSize);
	if( rc != UNQLITE_OK ){
		return UNQLITE_DONE;
	}
	/* If the journal file is too small, return UNQLITE_DONE. */
	if( 32 /* Minimum sector size */> iSize ){
		return UNQLITE_DONE;
	}
	/* Make sure we are dealing with a valid journal */
	rc = unqliteOsRead(pPager->pjfd,zMagic,sizeof(zMagic),iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( SyMemcmp(zMagic,aJournalMagic,sizeof(zMagic)) != 0 ){
		return UNQLITE_DONE;
	}
	iHdrOfft += sizeof(zMagic);
	 /* Read the first three 32-bit fields of the journal header: The nRec
      ** field, the checksum-initializer and the database size at the start
      ** of the transaction. Return an error code if anything goes wrong.
      */
	rc = ReadInt32(pPager->pjfd,pNRec,iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	iHdrOfft += 4;
	rc = ReadInt32(pPager->pjfd,&pPager->cksumInit,iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	iHdrOfft += 4;
	rc = ReadInt64(pPager->pjfd,pDbSize,iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	iHdrOfft += 8;
	/* Read the page-size and sector-size journal header fields. */
	rc = ReadInt32(pPager->pjfd,&iSectorSize,iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	iHdrOfft += 4;
	rc = ReadInt32(pPager->pjfd,&iPageSize,iHdrOfft);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Check that the values read from the page-size and sector-size fields
    ** are within range. To be 'in range', both values need to be a power
    ** of two greater than or equal to 512 or 32, and not greater than their 
    ** respective compile time maximum limits.
    */
    if( iPageSize < UNQLITE_MIN_PAGE_SIZE || iSectorSize<32
     || iPageSize > UNQLITE_MAX_PAGE_SIZE || iSectorSize>MAX_SECTOR_SIZE
     || ((iPageSize-1)&iPageSize)!=0    || ((iSectorSize-1)&iSectorSize)!=0 
    ){
      /* If the either the page-size or sector-size in the journal-header is 
      ** invalid, then the process that wrote the journal-header must have 
      ** crashed before the header was synced. In this case stop reading 
      ** the journal file here.
      */
      return UNQLITE_DONE;
    }
    /* Update the assumed sector-size to match the value used by 
    ** the process that created this journal. If this journal was
    ** created by a process other than this one, then this routine
    ** is being called from within pager_playback(). The local value
    ** of Pager.sectorSize is restored at the end of that routine.
    */
    pPager->iSectorSize = iSectorSize;
	pPager->iPageSize = iPageSize;
	/* Ready to rollback */
	pPager->iJournalOfft = JOURNAL_HDR_SZ(pPager);
	/* All done */
	return UNQLITE_OK;
}
/*
 * Write the journal header in the given memory buffer.
 * The given buffer is big enough to hold the whole header.
 */
static int pager_write_journal_header(Pager *pPager,unsigned char *zBuf)
{
	unsigned char *zPtr = zBuf;
	/* 8 bytes magic number */
	SyMemcpy(aJournalMagic,zPtr,sizeof(aJournalMagic));
	zPtr += sizeof(aJournalMagic);
	/* 4 bytes: Number of records in journal. */
	SyBigEndianPack32(zPtr,0);
	zPtr += 4;
	/* 4 bytes: Random number used to compute page checksum. */
	SyBigEndianPack32(zPtr,pPager->cksumInit);
	zPtr += 4;
	/* 8 bytes: Initial database page count. */
	SyBigEndianPack64(zPtr,pPager->dbOrigSize);
	zPtr += 8;
	/* 4 bytes: Sector size used by the process that wrote this journal. */
	SyBigEndianPack32(zPtr,(sxu32)pPager->iSectorSize);
	zPtr += 4;
	/* 4 bytes: Database page size. */
	SyBigEndianPack32(zPtr,(sxu32)pPager->iPageSize);
	return UNQLITE_OK;
}
/*
** Parameter aData must point to a buffer of pPager->pageSize bytes
** of data. Compute and return a checksum based ont the contents of the 
** page of data and the current value of pPager->cksumInit.
**
** This is not a real checksum. It is really just the sum of the 
** random initial value (pPager->cksumInit) and every 200th byte
** of the page data, starting with byte offset (pPager->pageSize%200).
** Each byte is interpreted as an 8-bit unsigned integer.
**
** Changing the formula used to compute this checksum results in an
** incompatible journal file format.
**
** If journal corruption occurs due to a power failure, the most likely 
** scenario is that one end or the other of the record will be changed. 
** It is much less likely that the two ends of the journal record will be
** correct and the middle be corrupt.  Thus, this "checksum" scheme,
** though fast and simple, catches the mostly likely kind of corruption.
*/
static sxu32 pager_cksum(Pager *pPager,const unsigned char *zData)
{
  sxu32 cksum = pPager->cksumInit;         /* Checksum value to return */
  int i = pPager->iPageSize-200;          /* Loop counter */
  while( i>0 ){
    cksum += zData[i];
    i -= 200;
  }
  return cksum;
}
/*
** Read a single page from the journal file opened on file descriptor
** jfd. Playback this one page. Update the offset to read from.
*/
static int pager_play_back_one_page(Pager *pPager,sxi64 *pOfft,unsigned char *zTmp)
{
	unsigned char *zData = zTmp;
	sxi64 iOfft; /* Offset to read from */
	pgno iNum;   /* Pager number */
	sxu32 ckSum; /* Sanity check */
	int rc;
	/* Offset to start reading from */
	iOfft = *pOfft;
	/* Database page number */
	rc = ReadInt64(pPager->pjfd,&iNum,iOfft);
	if( rc != UNQLITE_OK ){ return rc; }
	iOfft += 8;
	/* Page data */
	rc = unqliteOsRead(pPager->pjfd,zData,pPager->iPageSize,iOfft);
	if( rc != UNQLITE_OK ){ return rc; }
	iOfft += pPager->iPageSize;
	/* Page cksum */
	rc = ReadInt32(pPager->pjfd,&ckSum,iOfft);
	if( rc != UNQLITE_OK ){ return rc; }
	iOfft += 4;
	/* Synchronize pointers */
	*pOfft = iOfft;
	/* Make sure we are dealing with a valid page */
	if( ckSum != pager_cksum(pPager,zData) ){
		/* Ignore that page */
		return SXERR_IGNORE;
	}
	if( iNum >= pPager->dbSize ){
		/* Ignore that page */
		return UNQLITE_OK;
	}
	/* playback */
	rc = unqliteOsWrite(pPager->pfd,zData,pPager->iPageSize,iNum * pPager->iPageSize);
	if( rc == UNQLITE_OK ){
		/* Flush the cache */
		pager_fill_page(pPager,iNum,zData);
	}
	return rc;
}
/*
** Playback the journal and thus restore the database file to
** the state it was in before we started making changes.  
**
** The journal file format is as follows: 
**
**  (1)  8 byte prefix.  A copy of aJournalMagic[].
**  (2)  4 byte big-endian integer which is the number of valid page records
**       in the journal. 
**  (3)  4 byte big-endian integer which is the initial value for the 
**       sanity checksum.
**  (4)  8 byte integer which is the number of pages to truncate the
**       database to during a rollback.
**  (5)  4 byte big-endian integer which is the sector size.  The header
**       is this many bytes in size.
**  (6)  4 byte big-endian integer which is the page size.
**  (7)  zero padding out to the next sector size.
**  (8)  Zero or more pages instances, each as follows:
**        +  4 byte page number.
**        +  pPager->pageSize bytes of data.
**        +  4 byte checksum
**
** When we speak of the journal header, we mean the first 7 items above.
** Each entry in the journal is an instance of the 8th item.
**
** Call the value from the second bullet "nRec".  nRec is the number of
** valid page entries in the journal.  In most cases, you can compute the
** value of nRec from the size of the journal file.  But if a power
** failure occurred while the journal was being written, it could be the
** case that the size of the journal file had already been increased but
** the extra entries had not yet made it safely to disk.  In such a case,
** the value of nRec computed from the file size would be too large.  For
** that reason, we always use the nRec value in the header.
**
** If the file opened as the journal file is not a well-formed
** journal file then all pages up to the first corrupted page are rolled
** back (or no pages if the journal header is corrupted). The journal file
** is then deleted and SQLITE_OK returned, just as if no corruption had
** been encountered.
**
** If an I/O or malloc() error occurs, the journal-file is not deleted
** and an error code is returned.
**
*/
static int pager_playback(Pager *pPager)
{
	unsigned char *zTmp = 0; /* cc warning */
	sxu32 n,nRec;
	sxi64 iOfft;
	int rc;
	/* Read the journal header*/
	rc = pager_read_journal_header(pPager,&nRec,&pPager->dbSize);
	if( rc != UNQLITE_OK ){
		if( rc == UNQLITE_DONE ){
			goto end_playback;
		}
		unqliteGenErrorFormat(pPager->pDb,"IO error while reading journal file '%s' header",pPager->zJournal);
		return rc;
	}
	/* Truncate the database back to its original size */
	rc = unqliteOsTruncate(pPager->pfd,pPager->iPageSize * pPager->dbSize);
	if( rc != UNQLITE_OK ){
		unqliteGenError(pPager->pDb,"IO error while truncating database file");
		return rc;
	}
	/* Allocate a temporary page */
	zTmp = (unsigned char *)SyMemBackendAlloc(pPager->pAllocator,(sxu32)pPager->iPageSize);
	if( zTmp == 0 ){
		unqliteGenOutofMem(pPager->pDb);
		return UNQLITE_NOMEM;
	}
	SyZero((void *)zTmp,(sxu32)pPager->iPageSize);
	/* Copy original pages out of the journal and back into the 
    ** database file and/or page cache.
    */
	iOfft = pPager->iJournalOfft;
	for( n = 0 ; n < nRec ; ++n ){
		rc = pager_play_back_one_page(pPager,&iOfft,zTmp);
		if( rc != UNQLITE_OK ){
			if( rc != SXERR_IGNORE ){
				unqliteGenError(pPager->pDb,"Page playback error");
				goto end_playback;
			}
		}
	}
end_playback:
	/* Release the temp page */
	SyMemBackendFree(pPager->pAllocator,(void *)zTmp);
	if( rc == UNQLITE_OK ){
		/* Sync the database file */
		unqliteOsSync(pPager->pfd,UNQLITE_SYNC_FULL);
	}
	if( rc == UNQLITE_DONE ){
		rc = UNQLITE_OK;
	}
	/* Return to the caller */
	return rc;
}
/*
** Unlock the database file to level eLock, which must be either NO_LOCK
** or SHARED_LOCK. Regardless of whether or not the call to xUnlock()
** succeeds, set the Pager.iLock variable to match the (attempted) new lock.
**
** Except, if Pager.iLock is set to NO_LOCK when this function is
** called, do not modify it. See the comment above the #define of 
** NO_LOCK for an explanation of this.
*/
static int pager_unlock_db(Pager *pPager, int eLock)
{
  int rc = UNQLITE_OK;
  if( pPager->iLock != NO_LOCK ){
    rc = unqliteOsUnlock(pPager->pfd,eLock);
    pPager->iLock = eLock;
  }
  return rc;
}
/*
** Lock the database file to level eLock, which must be either SHARED_LOCK,
** RESERVED_LOCK or EXCLUSIVE_LOCK. If the caller is successful, set the
** Pager.eLock variable to the new locking state. 
**
** Except, if Pager.eLock is set to NO_LOCK when this function is 
** called, do not modify it unless the new locking state is EXCLUSIVE_LOCK. 
** See the comment above the #define of NO_LOCK for an explanation 
** of this.
*/
static int pager_lock_db(Pager *pPager, int eLock){
  int rc = UNQLITE_OK;
  if( pPager->iLock < eLock || pPager->iLock == NO_LOCK ){
    rc = unqliteOsLock(pPager->pfd, eLock);
    if( rc==UNQLITE_OK ){
      pPager->iLock = eLock;
    }else{
		unqliteGenError(pPager->pDb,
			rc == UNQLITE_BUSY ? "Another process or thread hold the requested lock" : "Error while requesting database lock"
			);
	}
  }
  return rc;
}
/*
** Try to obtain a lock of type locktype on the database file. If
** a similar or greater lock is already held, this function is a no-op
** (returning UNQLITE_OK immediately).
**
** Otherwise, attempt to obtain the lock using unqliteOsLock(). Invoke 
** the busy callback if the lock is currently not available. Repeat 
** until the busy callback returns false or until the attempt to 
** obtain the lock succeeds.
**
** Return UNQLITE_OK on success and an error code if we cannot obtain
** the lock. If the lock is obtained successfully, set the Pager.state 
** variable to locktype before returning.
*/
static int pager_wait_on_lock(Pager *pPager, int locktype){
  int rc;                              /* Return code */
  do {
    rc = pager_lock_db(pPager,locktype);
  }while( rc==UNQLITE_BUSY && pPager->xBusyHandler && pPager->xBusyHandler(pPager->pBusyHandlerArg) );
  return rc;
}
/*
** This function is called after transitioning from PAGER_OPEN to
** PAGER_SHARED state. It tests if there is a hot journal present in
** the file-system for the given pager. A hot journal is one that 
** needs to be played back. According to this function, a hot-journal
** file exists if the following criteria are met:
**
**   * The journal file exists in the file system, and
**   * No process holds a RESERVED or greater lock on the database file, and
**   * The database file itself is greater than 0 bytes in size, and
**   * The first byte of the journal file exists and is not 0x00.
**
** If the current size of the database file is 0 but a journal file
** exists, that is probably an old journal left over from a prior
** database with the same name. In this case the journal file is
** just deleted using OsDelete, *pExists is set to 0 and UNQLITE_OK
** is returned.
**
** If a hot-journal file is found to exist, *pExists is set to 1 and 
** UNQLITE_OK returned. If no hot-journal file is present, *pExists is
** set to 0 and UNQLITE_OK returned. If an IO error occurs while trying
** to determine whether or not a hot-journal file exists, the IO error
** code is returned and the value of *pExists is undefined.
*/
static int pager_has_hot_journal(Pager *pPager, int *pExists)
{
  unqlite_vfs *pVfs = pPager->pVfs;
  int rc = UNQLITE_OK;           /* Return code */
  int exists = 1;               /* True if a journal file is present */

  *pExists = 0;
  rc = unqliteOsAccess(pVfs, pPager->zJournal, UNQLITE_ACCESS_EXISTS, &exists);
  if( rc==UNQLITE_OK && exists ){
    int locked = 0;             /* True if some process holds a RESERVED lock */

    /* Race condition here:  Another process might have been holding the
    ** the RESERVED lock and have a journal open at the unqliteOsAccess() 
    ** call above, but then delete the journal and drop the lock before
    ** we get to the following unqliteOsCheckReservedLock() call.  If that
    ** is the case, this routine might think there is a hot journal when
    ** in fact there is none.  This results in a false-positive which will
    ** be dealt with by the playback routine.
    */
    rc = unqliteOsCheckReservedLock(pPager->pfd, &locked);
    if( rc==UNQLITE_OK && !locked ){
      sxi64 n = 0;                    /* Size of db file in bytes */
 
      /* Check the size of the database file. If it consists of 0 pages,
      ** then delete the journal file. See the header comment above for 
      ** the reasoning here.  Delete the obsolete journal file under
      ** a RESERVED lock to avoid race conditions.
      */
      rc = unqliteOsFileSize(pPager->pfd,&n);
      if( rc==UNQLITE_OK ){
        if( n < 1 ){
          if( pager_lock_db(pPager, RESERVED_LOCK)==UNQLITE_OK ){
            unqliteOsDelete(pVfs, pPager->zJournal, 0);
			pager_unlock_db(pPager, SHARED_LOCK);
          }
        }else{
          /* The journal file exists and no other connection has a reserved
          ** or greater lock on the database file. */
			*pExists = 1;
        }
      }
    }
  }
  return rc;
}
/*
 * Rollback a journal file. (See block-comment above).
 */
static int pager_journal_rollback(Pager *pPager,int check_hot)
{
	int rc;
	if( check_hot ){
		int iExists = 0; /* cc warning */
		/* Check if the journal file exists */
		rc = pager_has_hot_journal(pPager,&iExists);
		if( rc != UNQLITE_OK  ){
			/* IO error */
			return rc;
		}
		if( !iExists ){
			/* Journal file does not exists */
			return UNQLITE_OK;
		}
	}
	if( pPager->is_rdonly ){
		unqliteGenErrorFormat(pPager->pDb,
			"Cannot rollback journal file '%s' due to a read-only database handle",pPager->zJournal);
		return UNQLITE_READ_ONLY;
	}
	/* Get an EXCLUSIVE lock on the database file. At this point it is
      ** important that a RESERVED lock is not obtained on the way to the
      ** EXCLUSIVE lock. If it were, another process might open the
      ** database file, detect the RESERVED lock, and conclude that the
      ** database is safe to read while this process is still rolling the 
      ** hot-journal back.
      ** 
      ** Because the intermediate RESERVED lock is not requested, any
      ** other process attempting to access the database file will get to 
      ** this point in the code and fail to obtain its own EXCLUSIVE lock 
      ** on the database file.
      **
      ** Unless the pager is in locking_mode=exclusive mode, the lock is
      ** downgraded to SHARED_LOCK before this function returns.
      */
	/* Open the journal file */
	rc = unqliteOsOpen(pPager->pVfs,pPager->pAllocator,pPager->zJournal,&pPager->pjfd,UNQLITE_OPEN_READWRITE);
	if( rc != UNQLITE_OK ){
		unqliteGenErrorFormat(pPager->pDb,"IO error while opening journal file: '%s'",pPager->zJournal);
		goto fail;
	}
	rc = pager_lock_db(pPager,EXCLUSIVE_LOCK);
	if( rc != UNQLITE_OK ){
		unqliteGenError(pPager->pDb,"Cannot acquire an exclusive lock on the database while journal rollback");
		goto fail;
	}
	/* Sync the journal file */
	unqliteOsSync(pPager->pjfd,UNQLITE_SYNC_NORMAL);
	/* Finally rollback the database */
	rc = pager_playback(pPager);
	/* Switch back to shared lock */
	pager_unlock_db(pPager,SHARED_LOCK);
fail:
	/* Close the journal handle */
	unqliteOsCloseFree(pPager->pAllocator,pPager->pjfd);
	pPager->pjfd = 0;
	if( rc == UNQLITE_OK ){
		/* Delete the journal file */
		unqliteOsDelete(pPager->pVfs,pPager->zJournal,TRUE);
	}
	return rc;
}
/*
 * Write the unqlite header (First page). (Big-Endian)
 */
static int pager_write_db_header(Pager *pPager)
{
	unsigned char *zRaw = pPager->pHeader->zData;
	unqlite_kv_engine *pEngine = pPager->pEngine;
	sxu32 nDos;
	sxu16 nLen;
	/* Database signature */
	SyMemcpy(UNQLITE_DB_SIG,zRaw,sizeof(UNQLITE_DB_SIG)-1);
	zRaw += sizeof(UNQLITE_DB_SIG)-1;
	/* Database magic number */
	SyBigEndianPack32(zRaw,UNQLITE_DB_MAGIC);
	zRaw += 4; /* 4 byte magic number */
	/* Database creation time */
	SyZero(&pPager->tmCreate,sizeof(Sytm));
	if( pPager->pVfs->xCurrentTime ){
		pPager->pVfs->xCurrentTime(pPager->pVfs,&pPager->tmCreate);
	}
	/* DOS time format (4 bytes) */
	SyTimeFormatToDos(&pPager->tmCreate,&nDos);
	SyBigEndianPack32(zRaw,nDos);
	zRaw += 4; /* 4 byte DOS time */
	/* Sector size */
	SyBigEndianPack32(zRaw,(sxu32)pPager->iSectorSize);
	zRaw += 4; /* 4 byte sector size */
	/* Page size */
	SyBigEndianPack32(zRaw,(sxu32)pPager->iPageSize);
	zRaw += 4; /* 4 byte page size */
	/* Key value storage engine */
	nLen = (sxu16)SyStrlen(pEngine->pIo->pMethods->zName);
	SyBigEndianPack16(zRaw,nLen); /* 2 byte storage engine name */
	zRaw += 2;
	SyMemcpy((const void *)pEngine->pIo->pMethods->zName,(void *)zRaw,nLen);
	zRaw += nLen;
	/* All rest are meta-data available to the host application */
	return UNQLITE_OK;
}
/*
 * Read the unqlite header (first page). (Big-Endian)
 */
static int pager_extract_header(Pager *pPager,const unsigned char *zRaw,sxu32 nByte)
{
	const unsigned char *zEnd = &zRaw[nByte];
	sxu32 nDos,iMagic;
	sxu16 nLen;
	char *zKv;
	/* Database signature */
	if( SyMemcmp(UNQLITE_DB_SIG,zRaw,sizeof(UNQLITE_DB_SIG)-1) != 0 ){
		/* Corrupt database */
		return UNQLITE_CORRUPT;
	}
	zRaw += sizeof(UNQLITE_DB_SIG)-1;
	/* Database magic number */
	SyBigEndianUnpack32(zRaw,&iMagic);
	zRaw += 4; /* 4 byte magic number */
	if( iMagic != UNQLITE_DB_MAGIC ){
		/* Corrupt database */
		return UNQLITE_CORRUPT;
	}
	/* Database creation time */
	SyBigEndianUnpack32(zRaw,&nDos);
	zRaw += 4; /* 4 byte DOS time format */
	SyDosTimeFormat(nDos,&pPager->tmCreate);
	/* Sector size */
	SyBigEndianUnpack32(zRaw,(sxu32 *)&pPager->iSectorSize);
	zRaw += 4; /* 4 byte sector size */
	/* Page size */
	SyBigEndianUnpack32(zRaw,(sxu32 *)&pPager->iPageSize);
	zRaw += 4; /* 4 byte page size */
	/* Check that the values read from the page-size and sector-size fields
    ** are within range. To be 'in range', both values need to be a power
    ** of two greater than or equal to 512 or 32, and not greater than their 
    ** respective compile time maximum limits.
    */
    if( pPager->iPageSize<UNQLITE_MIN_PAGE_SIZE || pPager->iSectorSize<32
     || pPager->iPageSize>UNQLITE_MAX_PAGE_SIZE || pPager->iSectorSize>MAX_SECTOR_SIZE
     || ((pPager->iPageSize<-1)&pPager->iPageSize)!=0    || ((pPager->iSectorSize-1)&pPager->iSectorSize)!=0 
    ){
      return UNQLITE_CORRUPT;
	}
	/* Key value storage engine */
	SyBigEndianUnpack16(zRaw,&nLen); /* 2 byte storage engine length */
	zRaw += 2;
	if( nLen > (sxu16)(zEnd - zRaw) ){
		nLen = (sxu16)(zEnd - zRaw);
	}
	zKv = (char *)SyMemBackendDup(pPager->pAllocator,(const char *)zRaw,nLen);
	if( zKv == 0 ){
		return UNQLITE_NOMEM;
	}
	SyStringInitFromBuf(&pPager->sKv,zKv,nLen);
	return UNQLITE_OK;
}
/*
 * Read the database header.
 */
static int pager_read_db_header(Pager *pPager)
{
	unsigned char zRaw[UNQLITE_MIN_PAGE_SIZE]; /* Minimum page size */
	sxi64 n = 0;              /* Size of db file in bytes */
	int rc;
	/* Get the file size first */
	rc = unqliteOsFileSize(pPager->pfd,&n);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	pPager->dbByteSize = n;
	if( n > 0 ){
		unqlite_kv_methods *pMethods;
		SyString *pKv;
		pgno nPage;
		if( n < UNQLITE_MIN_PAGE_SIZE ){
			/* A valid unqlite database must be at least 512 bytes long */
			unqliteGenError(pPager->pDb,"Malformed database image");
			return UNQLITE_CORRUPT;
		}
		/* Read the database header */
		rc = unqliteOsRead(pPager->pfd,zRaw,sizeof(zRaw),0);
		if( rc != UNQLITE_OK ){
			unqliteGenError(pPager->pDb,"IO error while reading database header");
			return rc;
		}
		/* Extract the header */
		rc = pager_extract_header(pPager,zRaw,sizeof(zRaw));
		if( rc != UNQLITE_OK ){
			unqliteGenError(pPager->pDb,rc == UNQLITE_NOMEM ? "Unqlite is running out of memory" : "Malformed database image");
			return rc;
		}
		/* Update pager state  */
		nPage = (pgno)(n / pPager->iPageSize);
		if( nPage==0 && n>0 ){
			nPage = 1;
		}
		pPager->dbSize = nPage;
		/* Laod the target Key/Value storage engine */
		pKv = &pPager->sKv;
		pMethods = unqliteFindKVStore(pKv->zString,pKv->nByte);
		if( pMethods == 0 ){
			unqliteGenErrorFormat(pPager->pDb,"No such Key/Value storage engine '%z'",pKv);
			return UNQLITE_NOTIMPLEMENTED;
		}
		/* Install the new KV storage engine */
		rc = unqlitePagerRegisterKvEngine(pPager,pMethods);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}else{
		/* Set a default page and sector size */
		pPager->iSectorSize = GetSectorSize(pPager->pfd);
		pPager->iPageSize = unqliteGetPageSize();
		SyStringInitFromBuf(&pPager->sKv,pPager->pEngine->pIo->pMethods->zName,SyStrlen(pPager->pEngine->pIo->pMethods->zName));
		pPager->dbSize = 0;
	}
	/* Allocate a temporary page size */
	pPager->zTmpPage = (unsigned char *)SyMemBackendAlloc(pPager->pAllocator,(sxu32)pPager->iPageSize);
	if( pPager->zTmpPage == 0 ){
		unqliteGenOutofMem(pPager->pDb);
		return UNQLITE_NOMEM;
	}
	SyZero(pPager->zTmpPage,(sxu32)pPager->iPageSize);
	return UNQLITE_OK;
}
/*
 * Write the database header.
 */
static int pager_create_header(Pager *pPager)
{
	Page *pHeader;
	int rc;
	/* Allocate a new page */
	pHeader = pager_alloc_page(pPager,0);
	if( pHeader == 0 ){
		return UNQLITE_NOMEM;
	}
	pPager->pHeader = pHeader;
	/* Link the page */
	pager_link_page(pPager,pHeader);
	/* Add to the dirty list */
	pager_page_to_dirty_list(pPager,pHeader);
	/* Write the database header */
	rc = pager_write_db_header(pPager);
	return rc;
}
/*
** This function is called to obtain a shared lock on the database file.
** It is illegal to call unqlitePagerAcquire() until after this function
** has been successfully called. If a shared-lock is already held when
** this function is called, it is a no-op.
**
** The following operations are also performed by this function.
**
**   1) If the pager is currently in PAGER_OPEN state (no lock held
**      on the database file), then an attempt is made to obtain a
**      SHARED lock on the database file. Immediately after obtaining
**      the SHARED lock, the file-system is checked for a hot-journal,
**      which is played back if present. 
**
** If everything is successful, UNQLITE_OK is returned. If an IO error 
** occurs while locking the database, checking for a hot-journal file or 
** rolling back a journal file, the IO error code is returned.
*/
static int pager_shared_lock(Pager *pPager)
{
	int rc = UNQLITE_OK;
	if( pPager->iState == PAGER_OPEN ){
		unqlite_kv_methods *pMethods;
		/* Open the target database */
		rc = unqliteOsOpen(pPager->pVfs,pPager->pAllocator,pPager->zFilename,&pPager->pfd,pPager->iOpenFlags);
		if( rc != UNQLITE_OK ){
			unqliteGenErrorFormat(pPager->pDb,
				"IO error while opening the target database file: %s",pPager->zFilename
				);
			return rc;
		}
		/* Try to obtain a shared lock */
		rc = pager_wait_on_lock(pPager,SHARED_LOCK);
		if( rc == UNQLITE_OK ){
			if( pPager->iLock <= SHARED_LOCK ){
				/* Rollback any hot journal */
				rc = pager_journal_rollback(pPager,1);
				if( rc != UNQLITE_OK ){
					return rc;
				}
			}
			/* Read the database header */
			rc = pager_read_db_header(pPager);
			if( rc != UNQLITE_OK ){
				return rc;
			}
			if(pPager->dbSize > 0 ){
				if( pPager->iOpenFlags & UNQLITE_OPEN_MMAP ){
					const unqlite_vfs * pVfs = unqliteExportBuiltinVfs();
					/* Obtain a read-only memory view of the whole file */
					if( pVfs && pVfs->xMmap ){
						int vr;
						vr = pVfs->xMmap(pPager->zFilename,&pPager->pMmap,&pPager->dbByteSize);
						if( vr != UNQLITE_OK ){
							/* Generate a warning */
							unqliteGenError(pPager->pDb,"Cannot obtain a read-only memory view of the target database");
							pPager->iOpenFlags &= ~UNQLITE_OPEN_MMAP;
						}
					}else{
						/* Generate a warning */
						unqliteGenError(pPager->pDb,"Cannot obtain a read-only memory view of the target database");
						pPager->iOpenFlags &= ~UNQLITE_OPEN_MMAP;
					}
				}
			}
			/* Update the pager state */
			pPager->iState = PAGER_READER;
			/* Invoke the xOpen methods if available */
			pMethods = pPager->pEngine->pIo->pMethods;
			if( pMethods->xOpen ){
				rc = pMethods->xOpen(pPager->pEngine,pPager->dbSize);
				if( rc != UNQLITE_OK ){
					unqliteGenErrorFormat(pPager->pDb,
						"xOpen() method of the underlying KV engine '%z' failed",
						&pPager->sKv
						);
					pager_unlock_db(pPager,NO_LOCK);
					pPager->iState = PAGER_OPEN;
					return rc;
				}
			}
		}else if( rc == UNQLITE_BUSY ){
			unqliteGenError(pPager->pDb,"Another process or thread have a reserved or exclusive lock on this database");
		}		
	}
	return rc;
}
/*
** Begin a write-transaction on the specified pager object. If a 
** write-transaction has already been opened, this function is a no-op.
*/
UNQLITE_PRIVATE int unqlitePagerBegin(Pager *pPager)
{
	int rc;
	/* Obtain a shared lock on the database first */
	rc = pager_shared_lock(pPager);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pPager->iState >= PAGER_WRITER_LOCKED ){
		return UNQLITE_OK;
	}
	if( pPager->is_rdonly ){
		unqliteGenError(pPager->pDb,"Read-only database");
		/* Read only database */
		return UNQLITE_READ_ONLY;
	}
	/* Obtain a reserved lock on the database */
	rc = pager_wait_on_lock(pPager,RESERVED_LOCK);
	if( rc == UNQLITE_OK ){
		/* Create the bitvec */
		pPager->pVec = unqliteBitvecCreate(pPager->pAllocator,pPager->dbSize);
		if( pPager->pVec == 0 ){
			unqliteGenOutofMem(pPager->pDb);
			rc = UNQLITE_NOMEM;
			goto fail;
		}
		/* Change to the WRITER_LOCK state */
		pPager->iState = PAGER_WRITER_LOCKED;
		pPager->dbOrigSize = pPager->dbSize;
		pPager->iJournalOfft = 0;
		pPager->nRec = 0;
		if( pPager->dbSize < 1 ){
			/* Write the  database header */
			rc = pager_create_header(pPager);
			if( rc != UNQLITE_OK ){
				goto fail;
			}
			pPager->dbSize = 1;
		}
	}else if( rc == UNQLITE_BUSY ){
		unqliteGenError(pPager->pDb,"Another process or thread have a reserved lock on this database");
	}
	return rc;
fail:
	/* Downgrade to shared lock */
	pager_unlock_db(pPager,SHARED_LOCK);
	return rc;
}
/*
** This function is called at the start of every write transaction.
** There must already be a RESERVED or EXCLUSIVE lock on the database 
** file when this routine is called.
**
*/
static int unqliteOpenJournal(Pager *pPager)
{
	unsigned char *zHeader;
	int rc = UNQLITE_OK;
	if( pPager->is_mem || pPager->no_jrnl ){
		/* Journaling is omitted for this database */
		goto finish;
	}
	if( pPager->iState >= PAGER_WRITER_CACHEMOD ){
		/* Already opened */
		return UNQLITE_OK;
	}
	/* Delete any previously journal with the same name */
	unqliteOsDelete(pPager->pVfs,pPager->zJournal,1);
	/* Open the journal file */
	rc = unqliteOsOpen(pPager->pVfs,pPager->pAllocator,pPager->zJournal,
		&pPager->pjfd,UNQLITE_OPEN_CREATE|UNQLITE_OPEN_READWRITE);
	if( rc != UNQLITE_OK ){
		unqliteGenErrorFormat(pPager->pDb,"IO error while opening journal file: %s",pPager->zJournal);
		return rc;
	}
	/* Write the journal header */
	zHeader = (unsigned char *)SyMemBackendAlloc(pPager->pAllocator,(sxu32)pPager->iSectorSize);
	if( zHeader == 0 ){
		rc = UNQLITE_NOMEM;
		goto fail;
	}
	pager_write_journal_header(pPager,zHeader);
	/* Perform the disk write */
	rc = unqliteOsWrite(pPager->pjfd,zHeader,pPager->iSectorSize,0);
	/* Offset to start writing from */
	pPager->iJournalOfft = pPager->iSectorSize;
	/* All done, journal will be synced later */
	SyMemBackendFree(pPager->pAllocator,zHeader);
finish:
	if( rc == UNQLITE_OK ){
		pPager->iState = PAGER_WRITER_CACHEMOD;
		return UNQLITE_OK;
	}
fail:
	/* Unlink the journal file if something goes wrong */
	unqliteOsCloseFree(pPager->pAllocator,pPager->pjfd);
	unqliteOsDelete(pPager->pVfs,pPager->zJournal,0);
	pPager->pjfd = 0;
	return rc;
}
/*
** Sync the journal. In other words, make sure all the pages that have
** been written to the journal have actually reached the surface of the
** disk and can be restored in the event of a hot-journal rollback.
*
* This routine try also to obtain an exclusive lock on the database.
*/
static int unqliteFinalizeJournal(Pager *pPager,int *pRetry,int close_jrnl)
{
	int rc;
	*pRetry = 0;
	/* Grab the exclusive lock first */
	rc = pager_lock_db(pPager,EXCLUSIVE_LOCK);
	if( rc != UNQLITE_OK ){
		/* Retry the excusive lock process */
		*pRetry = 1;
		rc = UNQLITE_OK;
	}
	if( pPager->no_jrnl ){
		/* Journaling is omitted, return immediately */
		return UNQLITE_OK;
	}
	if (pPager->pjfd == 0) {
		/* BUGFIX: https://github.com/symisc/unqlite/issues/137 */
		return UNQLITE_ABORT; /* Ongoing operation must be aborted */
	}
	/* Write the total number of database records */
	rc = WriteInt32(pPager->pjfd,pPager->nRec,8 /* sizeof(aJournalRec) */);
	if( rc != UNQLITE_OK ){
		if( pPager->nRec > 0 ){
			return rc;
		}else{
			/* Not so fatal */
			rc = UNQLITE_OK;
		}
	}
	/* Sync the journal and close it */
	rc = unqliteOsSync(pPager->pjfd,UNQLITE_SYNC_NORMAL);
	if( close_jrnl ){
		/* close the journal file */
		if( UNQLITE_OK != unqliteOsCloseFree(pPager->pAllocator,pPager->pjfd) ){
			if( rc != UNQLITE_OK /* unqliteOsSync */ ){
				return rc;
			}
		}
		pPager->pjfd = 0;
	}
	if( (*pRetry) == 1 ){
		if( pager_lock_db(pPager,EXCLUSIVE_LOCK) == UNQLITE_OK ){
			/* Got exclusive lock */
			*pRetry = 0;
		}
	}
	return UNQLITE_OK;
}
/*
 * Mark a single data page as writeable. The page is written into the 
 * main journal as required.
 */
static int page_write(Pager *pPager,Page *pPage)
{
	int rc;
	if( !pPager->is_mem && !pPager->no_jrnl ){
		/* Write the page to the transaction journal */
		if( pPage->pgno < pPager->dbOrigSize && !unqliteBitvecTest(pPager->pVec,pPage->pgno) ){
			sxu32 cksum;
			if( pPager->nRec == SXU32_HIGH ){
				/* Journal Limit reached */
				unqliteGenError(pPager->pDb,"Journal record limit reached, commit your changes");
				return UNQLITE_LIMIT;
			}
			/* Write the page number */
			rc = WriteInt64(pPager->pjfd,pPage->pgno,pPager->iJournalOfft);
			if( rc != UNQLITE_OK ){ return rc; }
			/* Write the raw page */
			/** CODEC */
			rc = unqliteOsWrite(pPager->pjfd,pPage->zData,pPager->iPageSize,pPager->iJournalOfft + 8);
			if( rc != UNQLITE_OK ){ return rc; }
			/* Compute the checksum */
			cksum = pager_cksum(pPager,pPage->zData);
			rc = WriteInt32(pPager->pjfd,cksum,pPager->iJournalOfft + 8 + pPager->iPageSize);
			if( rc != UNQLITE_OK ){ return rc; }
			/* Update the journal offset */
			pPager->iJournalOfft += 8 /* page num */ + pPager->iPageSize + 4 /* cksum */;
			pPager->nRec++;
			/* Mark as journaled  */
			unqliteBitvecSet(pPager->pVec,pPage->pgno);
		}
	}
	/* Add the page to the dirty list */
	pager_page_to_dirty_list(pPager,pPage);
	/* Update the database size and return. */
	if( (1 + pPage->pgno) > pPager->dbSize ){
		pPager->dbSize = 1 + pPage->pgno;
		if( pPager->dbSize == SXU64_HIGH ){
			unqliteGenError(pPager->pDb,"Database maximum page limit (64-bit) reached");
			return UNQLITE_LIMIT;
		}
	}	
	return UNQLITE_OK;
}
/*
** The argument is the first in a linked list of dirty pages connected
** by the PgHdr.pDirty pointer. This function writes each one of the
** in-memory pages in the list to the database file. The argument may
** be NULL, representing an empty list. In this case this function is
** a no-op.
**
** The pager must hold at least a RESERVED lock when this function
** is called. Before writing anything to the database file, this lock
** is upgraded to an EXCLUSIVE lock. If the lock cannot be obtained,
** UNQLITE_BUSY is returned and no data is written to the database file.
*/
static int pager_write_dirty_pages(Pager *pPager,Page *pDirty)
{
	int rc = UNQLITE_OK;
	Page *pNext;
	for(;;){
		if( pDirty == 0 ){
			break;
		}
		/* Point to the next dirty page */
		pNext = pDirty->pDirtyPrev; /* Not a bug: Reverse link */
		if( (pDirty->flags & PAGE_DONT_WRITE) == 0 ){
			rc = unqliteOsWrite(pPager->pfd,pDirty->zData,pPager->iPageSize,pDirty->pgno * pPager->iPageSize);
			if( rc != UNQLITE_OK ){
				/* A rollback should be done */
				break;
			}
		}
		/* Remove stale flags */
		pDirty->flags &= ~(PAGE_DIRTY|PAGE_DONT_WRITE|PAGE_NEED_SYNC|PAGE_IN_JOURNAL|PAGE_HOT_DIRTY);
		if( pDirty->nRef < 1 ){
			/* Unlink the page now it is unused */
			pager_unlink_page(pPager,pDirty);
			/* Release the page */
			pager_release_page(pPager,pDirty);
		}
		/* Point to the next page */
		pDirty = pNext;
	}
	pPager->pDirty = pPager->pFirstDirty = 0;
	pPager->pHotDirty = pPager->pFirstHot = 0;
	pPager->nHot = 0;
	return rc;
}
/*
** The argument is the first in a linked list of hot dirty pages connected
** by the PgHdr.pHotDirty pointer. This function writes each one of the
** in-memory pages in the list to the database file. The argument may
** be NULL, representing an empty list. In this case this function is
** a no-op.
**
** The pager must hold at least a RESERVED lock when this function
** is called. Before writing anything to the database file, this lock
** is upgraded to an EXCLUSIVE lock. If the lock cannot be obtained,
** UNQLITE_BUSY is returned and no data is written to the database file.
*/
static int pager_write_hot_dirty_pages(Pager *pPager,Page *pDirty)
{
	int rc = UNQLITE_OK;
	Page *pNext;
	for(;;){
		if( pDirty == 0 ){
			break;
		}
		/* Point to the next page */
		pNext = pDirty->pPrevHot; /* Not a bug: Reverse link */
		if( (pDirty->flags & PAGE_DONT_WRITE) == 0 ){
			rc = unqliteOsWrite(pPager->pfd,pDirty->zData,pPager->iPageSize,pDirty->pgno * pPager->iPageSize);
			if( rc != UNQLITE_OK ){
				break;
			}
		}
		/* Remove stale flags */
		pDirty->flags &= ~(PAGE_DIRTY|PAGE_DONT_WRITE|PAGE_NEED_SYNC|PAGE_IN_JOURNAL|PAGE_HOT_DIRTY);
		/* Unlink from the list of dirty pages */
		if( pDirty->pDirtyPrev ){
			pDirty->pDirtyPrev->pDirtyNext = pDirty->pDirtyNext;
		}else{
			pPager->pDirty = pDirty->pDirtyNext;
		}
		if( pDirty->pDirtyNext ){
			pDirty->pDirtyNext->pDirtyPrev = pDirty->pDirtyPrev;
		}else{
			pPager->pFirstDirty = pDirty->pDirtyPrev;
		}
		/* Discard */
		pager_unlink_page(pPager,pDirty);
		/* Release the page */
		pager_release_page(pPager,pDirty);
		/* Next hot page */
		pDirty = pNext;
	}
	return rc;
}
/*
 * Commit a transaction: Phase one.
 */
static int pager_commit_phase1(Pager *pPager)
{
	int get_excl = 0;
	Page *pDirty;
	int rc;
	/* If no database changes have been made, return early. */
	if( pPager->iState < PAGER_WRITER_CACHEMOD ){
		return UNQLITE_OK;
	}
	if( pPager->is_mem ){
		/* An in-memory database */
		return UNQLITE_OK;
	}
	if( pPager->is_rdonly ){
		/* Read-Only DB */
		unqliteGenError(pPager->pDb,"Read-Only database");
		return UNQLITE_READ_ONLY;
	}
	/* Finalize the journal file */
	rc = unqliteFinalizeJournal(pPager,&get_excl,1);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Get the dirty pages */
	pDirty = pager_get_dirty_pages(pPager);
	if( get_excl ){
		/* Wait one last time for the exclusive lock */
		rc = pager_wait_on_lock(pPager,EXCLUSIVE_LOCK);
		if( rc != UNQLITE_OK ){
			unqliteGenError(pPager->pDb,"Cannot obtain an Exclusive lock on the target database");
			return rc;
		}
	}
	if( pPager->iFlags & PAGER_CTRL_DIRTY_COMMIT ){
		/* Sync the database first if a dirty commit have been applied */
		unqliteOsSync(pPager->pfd,UNQLITE_SYNC_NORMAL);
	}
	/* Write the dirty pages */
	rc = pager_write_dirty_pages(pPager,pDirty);
	if( rc != UNQLITE_OK ){
		/* Rollback your DB */
		pPager->iFlags |= PAGER_CTRL_COMMIT_ERR;
		pPager->pFirstDirty = pDirty;
		unqliteGenError(pPager->pDb,"IO error while writing dirty pages, rollback your database");
		return rc;
	}
	/* release all pages */
	{
		Page *p;

		while (1) {
			p = pPager->pAll;
			if (p == 0) {
				break;
			}
			pager_unlink_page(pPager, p);
			pager_release_page(pPager, p);
		}
	}
	/* If the file on disk is not the same size as the database image,
     * then use unqliteOsTruncate to grow or shrink the file here.
     */
	if( pPager->dbSize != pPager->dbOrigSize ){
		unqliteOsTruncate(pPager->pfd,pPager->iPageSize * pPager->dbSize);
	}
	/* Sync the database file */
	unqliteOsSync(pPager->pfd,UNQLITE_SYNC_FULL);
	/* Remove stale flags */
	pPager->iJournalOfft = 0;
	pPager->nRec = 0;
	return UNQLITE_OK;
}
/*
 * Commit a transaction: Phase two.
 */
static int pager_commit_phase2(Pager *pPager)
{
	if( !pPager->is_mem ){
		if( pPager->iState == PAGER_OPEN ){
			return UNQLITE_OK;
		}
		if( pPager->iState != PAGER_READER ){
			if( !pPager->no_jrnl ){
				/* Finally, unlink the journal file */
				unqliteOsDelete(pPager->pVfs,pPager->zJournal,1);
			}
			/* Downgrade to shraed lock */
			pager_unlock_db(pPager,SHARED_LOCK);
			pPager->iState = PAGER_READER;
			if( pPager->pVec ){
				unqliteBitvecDestroy(pPager->pVec);
				pPager->pVec = 0;
			}
		}
	}
	return UNQLITE_OK;
}
/*
 * Perform a dirty commit.
 */
static int pager_dirty_commit(Pager *pPager)
{
	int get_excl = 0;
	Page *pHot;
	int rc;
	/* Finalize the journal file without closing it */
	rc = unqliteFinalizeJournal(pPager,&get_excl,0);
	if( rc != UNQLITE_OK ){
		/* It's not a fatal error if something goes wrong here since
		 * its not the final commit.
		 */
		return UNQLITE_OK;
	}
	/* Point to the list of hot pages */
	pHot = pager_get_hot_pages(pPager);
	if( pHot == 0 ){
		return UNQLITE_OK;
	}
	if( get_excl ){
		/* Wait one last time for the exclusive lock */
		rc = pager_wait_on_lock(pPager,EXCLUSIVE_LOCK);
		if( rc != UNQLITE_OK ){
			/* Not so fatal, will try another time */
			return UNQLITE_OK;
		}
	}
	/* Tell that a dirty commit happen */
	pPager->iFlags |= PAGER_CTRL_DIRTY_COMMIT;
	/* Write the hot pages now */
	rc = pager_write_hot_dirty_pages(pPager,pHot);
	if( rc != UNQLITE_OK ){
		pPager->iFlags |= PAGER_CTRL_COMMIT_ERR;
		unqliteGenError(pPager->pDb,"IO error while writing hot dirty pages, rollback your database");
		return rc;
	}
	pPager->pFirstHot = pPager->pHotDirty = 0;
	pPager->nHot = 0;
	/* No need to sync the database file here, since the journal is already
	 * open here and this is not the final commit.
	 */
	return UNQLITE_OK;
}
/*
** Commit a transaction and sync the database file for the pager pPager.
**
** This routine ensures that:
**
**   * the journal is synced,
**   * all dirty pages are written to the database file, 
**   * the database file is truncated (if required), and
**   * the database file synced.
**   * the journal file is deleted.
*/
UNQLITE_PRIVATE int unqlitePagerCommit(Pager *pPager)
{
	int rc;
	/* Commit: Phase One */
	rc = pager_commit_phase1(pPager);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Commit: Phase Two */
	rc = pager_commit_phase2(pPager);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Remove stale flags */
	pPager->iFlags &= ~PAGER_CTRL_COMMIT_ERR;
	/* All done */
	return UNQLITE_OK;
fail:
	/* Disable the auto-commit flag */
	pPager->pDb->iFlags |= UNQLITE_FL_DISABLE_AUTO_COMMIT;
	return rc;
}
/*
 * Reset the pager to its initial state. This is caused by
 * a rollback operation.
 */
static int pager_reset_state(Pager *pPager,int bResetKvEngine)
{
	unqlite_kv_engine *pEngine = pPager->pEngine;
	Page *pNext,*pPtr = pPager->pAll;
	const unqlite_kv_io *pIo;
	int rc;
	/* Remove stale flags */
	pPager->iFlags &= ~(PAGER_CTRL_COMMIT_ERR|PAGER_CTRL_DIRTY_COMMIT);
	pPager->iJournalOfft = 0;
	pPager->nRec = 0;
	/* Database original size */
	pPager->dbSize = pPager->dbOrigSize;
	/* Discard all in-memory pages */
	for(;;){
		if( pPtr == 0 ){
			break;
		}
		pNext = pPtr->pNext; /* Reverse link */
		/* Remove stale flags */
		pPtr->flags &= ~(PAGE_DIRTY|PAGE_DONT_WRITE|PAGE_NEED_SYNC|PAGE_IN_JOURNAL|PAGE_HOT_DIRTY);
		/* Release the page */
		pager_release_page(pPager,pPtr);
		/* Point to the next page */
		pPtr = pNext;
	}
	pPager->pAll = 0;
	pPager->nPage = 0;
	pPager->pDirty = pPager->pFirstDirty = 0;
	pPager->pHotDirty = pPager->pFirstHot = 0;
	pPager->nHot = 0;
	if( pPager->apHash ){
		/* Zero the table */
		SyZero((void *)pPager->apHash,sizeof(Page *) * pPager->nSize);
	}
	if( pPager->pVec ){
		unqliteBitvecDestroy(pPager->pVec);
		pPager->pVec = 0;
	}
	/* Switch back to shared lock */
	pager_unlock_db(pPager,SHARED_LOCK);
	pPager->iState = PAGER_READER;
	if( bResetKvEngine ){
		/* Reset the underlying KV engine */
		pIo = pEngine->pIo;
		if( pIo->pMethods->xRelease ){
			/* Call the release callback */
			pIo->pMethods->xRelease(pEngine);
		}
		/* Zero the structure */
		SyZero(pEngine,(sxu32)pIo->pMethods->szKv);
		/* Fill in */
		pEngine->pIo = pIo;
		if( pIo->pMethods->xInit ){
			/* Call the init method */
			rc = pIo->pMethods->xInit(pEngine,pPager->iPageSize);
			if( rc != UNQLITE_OK ){
				return rc;
			}
		}
		if( pIo->pMethods->xOpen ){
			/* Call the xOpen method */
			rc = pIo->pMethods->xOpen(pEngine,pPager->dbSize);
			if( rc != UNQLITE_OK ){
				return rc;
			}
		}
	}
	/* All done */
	return UNQLITE_OK;
}
/*
** If a write transaction is open, then all changes made within the 
** transaction are reverted and the current write-transaction is closed.
** The pager falls back to PAGER_READER state if successful.
**
** Otherwise, in rollback mode, this function performs two functions:
**
**   1) It rolls back the journal file, restoring all database file and 
**      in-memory cache pages to the state they were in when the transaction
**      was opened, and
**
**   2) It finalizes the journal file, so that it is not used for hot
**      rollback at any point in the future (i.e. deletion).
**
** Finalization of the journal file (task 2) is only performed if the 
** rollback is successful.
**
*/
UNQLITE_PRIVATE int unqlitePagerRollback(Pager *pPager,int bResetKvEngine)
{
	int rc = UNQLITE_OK;
	if( pPager->iState < PAGER_WRITER_LOCKED ){
		/* A write transaction must be opened */
		return UNQLITE_OK;
	}
	if( pPager->is_mem ){
		/* As of this release 1.1.6: Transactions are not supported for in-memory databases */
		return UNQLITE_OK;
	}
	if( pPager->is_rdonly ){
		/* Read-Only DB */
		unqliteGenError(pPager->pDb,"Read-Only database");
		return UNQLITE_READ_ONLY;
	}
	if( pPager->iState >= PAGER_WRITER_CACHEMOD ){
		if( !pPager->no_jrnl ){
			/* Close any outstanding joural file */
			if( pPager->pjfd ){
				/* Sync the journal file */
				unqliteOsSync(pPager->pjfd,UNQLITE_SYNC_NORMAL);
			}
			unqliteOsCloseFree(pPager->pAllocator,pPager->pjfd);
			pPager->pjfd = 0;
			if( pPager->iFlags & (PAGER_CTRL_COMMIT_ERR|PAGER_CTRL_DIRTY_COMMIT) ){
				/* Perform the rollback */
				rc = pager_journal_rollback(pPager,0);
				if( rc != UNQLITE_OK ){
					/* Set the auto-commit flag */
					pPager->pDb->iFlags |= UNQLITE_FL_DISABLE_AUTO_COMMIT;
					return rc;
				}
			}
		}
		/* Unlink the journal file */
		unqliteOsDelete(pPager->pVfs,pPager->zJournal,1);
		/* Reset the pager state */
		rc = pager_reset_state(pPager,bResetKvEngine);
		if( rc != UNQLITE_OK ){
			/* Mostly an unlikely scenario */
			pPager->pDb->iFlags |= UNQLITE_FL_DISABLE_AUTO_COMMIT; /* Set the auto-commit flag */
			unqliteGenError(pPager->pDb,"Error while reseting pager to its initial state");
			return rc;
		}
	}else{
		/* Downgrade to shared lock */
		pager_unlock_db(pPager,SHARED_LOCK);
		pPager->iState = PAGER_READER;
	}
	return UNQLITE_OK;
}
/*
 *  Mark a data page as non writeable.
 */
static int unqlitePagerDontWrite(unqlite_page *pMyPage)
{
	Page *pPage = (Page *)pMyPage;
	if( pPage->pgno > 0 /* Page 0 is always writeable */ ){
		pPage->flags |= PAGE_DONT_WRITE;
	}
	return UNQLITE_OK;
}
/*
** Mark a data page as writable. This routine must be called before 
** making changes to a page. The caller must check the return value 
** of this function and be careful not to change any page data unless 
** this routine returns UNQLITE_OK.
*/
static int unqlitePageWrite(unqlite_page *pMyPage)
{
	Page *pPage = (Page *)pMyPage;
	Pager *pPager = pPage->pPager;
	int rc;
	/* Begin the write transaction */
	rc = unqlitePagerBegin(pPager);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	if( pPager->iState == PAGER_WRITER_LOCKED ){
		/* The journal file needs to be opened. Higher level routines have already
		 ** obtained the necessary locks to begin the write-transaction, but the
		 ** rollback journal might not yet be open. Open it now if this is the case.
		 */
		rc = unqliteOpenJournal(pPager);
		if( rc != UNQLITE_OK ){
			return rc;
		}
	}
	if( pPager->nHot > 127 ){
		/* Write hot dirty pages */
		rc = pager_dirty_commit(pPager);
		if( rc != UNQLITE_OK ){
			/* A rollback must be done */
			unqliteGenError(pPager->pDb,"Please perform a rollback");
			return rc;
		}
	}
	/* Write the page to the journal file */
	rc = page_write(pPager,pPage);
	return rc;
}
/*
** Acquire a reference to page number pgno in pager pPager (a page
** reference has type unqlite_page*). If the requested reference is 
** successfully obtained, it is copied to *ppPage and UNQLITE_OK returned.
**
** If the requested page is already in the cache, it is returned. 
** Otherwise, a new page object is allocated and populated with data
** read from the database file.
*/
static int unqlitePagerAcquire(
  Pager *pPager,      /* The pager open on the database file */
  pgno pgno,          /* Page number to fetch */
  unqlite_page **ppPage,    /* OUT: Acquired page */
  int fetchOnly,      /* Cache lookup only */
  int noContent       /* Do not bother reading content from disk if true */
)
{
	Page *pPage;
	int rc;
	/* Acquire a shared lock (if not yet done) on the database and rollback any hot-journal if present */
	rc = pager_shared_lock(pPager);
	if( rc != UNQLITE_OK ){
		return rc;
	}
	/* Fetch the page from the cache */
	pPage = pager_fetch_page(pPager,pgno);
	if( fetchOnly ){
		if( ppPage ){
			*ppPage = (unqlite_page *)pPage;
		}
		return pPage ? UNQLITE_OK : UNQLITE_NOTFOUND;
	}
	if( pPage == 0 ){
		/* Allocate a new page */
		pPage = pager_alloc_page(pPager,pgno);
		if( pPage == 0 ){
			unqliteGenOutofMem(pPager->pDb);
			return UNQLITE_NOMEM;
		}
		/* Read page contents */
		rc = pager_get_page_contents(pPager,pPage,noContent);
		if( rc != UNQLITE_OK ){
			SyMemBackendPoolFree(pPager->pAllocator,pPage);
			return rc;
		}
		/* Link the page */
		pager_link_page(pPager,pPage);
	}else{
		if( ppPage ){
			page_ref(pPage);
		}
	}
	/* All done, page is loaded in memeory */
	if( ppPage ){
		*ppPage = (unqlite_page *)pPage;
	}
	return UNQLITE_OK;
}
/*
 * Return true if we are dealing with an in-memory database.
 */
static int unqliteInMemory(const char *zFilename)
{
	sxu32 n;
	if( SX_EMPTY_STR(zFilename) ){
		/* NULL or the empty string means an in-memory database */
		return TRUE;
	}
	n = SyStrlen(zFilename);
	if( n == sizeof(":mem:") - 1 && 
		SyStrnicmp(zFilename,":mem:",sizeof(":mem:") - 1) == 0 ){
			return TRUE;
	}
	if( n == sizeof(":memory:") - 1 && 
		SyStrnicmp(zFilename,":memory:",sizeof(":memory:") - 1) == 0 ){
			return TRUE;
	}
	return FALSE;
}
/*
 * Allocate a new KV cursor.
 */
UNQLITE_PRIVATE int unqliteInitCursor(unqlite *pDb,unqlite_kv_cursor **ppOut)
{
	unqlite_kv_methods *pMethods;
	unqlite_kv_cursor *pCur;
	sxu32 nByte;
	/* Storage engine methods */
	pMethods = pDb->sDB.pPager->pEngine->pIo->pMethods;
	if( pMethods->szCursor < 1 ){
		/* Implementation does not support cursors */
		unqliteGenErrorFormat(pDb,"Storage engine '%s' does not support cursors",pMethods->zName);
		return UNQLITE_NOTIMPLEMENTED;
	}
	nByte = pMethods->szCursor;
	if( nByte < sizeof(unqlite_kv_cursor) ){
		nByte += sizeof(unqlite_kv_cursor);
	}
	pCur = (unqlite_kv_cursor *)SyMemBackendPoolAlloc(&pDb->sMem,nByte);
	if( pCur == 0 ){
		unqliteGenOutofMem(pDb);
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pCur,nByte);
	/* Save the cursor */
	pCur->pStore = pDb->sDB.pPager->pEngine;
	/* Invoke the initialization callback if any */
	if( pMethods->xCursorInit ){
		pMethods->xCursorInit(pCur);
	}
	/* All done */
	*ppOut = pCur;
	return UNQLITE_OK;
}
/*
 * Release a cursor.
 */
UNQLITE_PRIVATE int unqliteReleaseCursor(unqlite *pDb,unqlite_kv_cursor *pCur)
{
	unqlite_kv_methods *pMethods;
	/* Storage engine methods */
	pMethods = pDb->sDB.pPager->pEngine->pIo->pMethods;
	/* Invoke the release callback if available */
	if( pMethods->xCursorRelease ){
		pMethods->xCursorRelease(pCur);
	}
	/* Finally, free the whole instance */
	SyMemBackendPoolFree(&pDb->sMem,pCur);
	return UNQLITE_OK;
}
/*
 * Release the underlying KV storage engine and invoke
 * its associated callbacks if available.
 */
static void pager_release_kv_engine(Pager *pPager)
{
	unqlite_kv_engine *pEngine = pPager->pEngine;
	unqlite_db *pStorage = &pPager->pDb->sDB;
	if( pStorage->pCursor ){
		/* Release the associated cursor */
		unqliteReleaseCursor(pPager->pDb,pStorage->pCursor);
		pStorage->pCursor = 0;
	}
	if( pEngine->pIo->pMethods->xRelease ){
		pEngine->pIo->pMethods->xRelease(pEngine);
	}
	/* Release the whole instance */
	SyMemBackendFree(&pPager->pDb->sMem,(void *)pEngine->pIo);
	SyMemBackendFree(&pPager->pDb->sMem,(void *)pEngine);
	pPager->pEngine = 0;
}
/* Forward declaration */
static int pager_kv_io_init(Pager *pPager,unqlite_kv_methods *pMethods,unqlite_kv_io *pIo);
/*
 * Allocate, initialize and register a new KV storage engine
 * within this database instance.
 */
UNQLITE_PRIVATE int unqlitePagerRegisterKvEngine(Pager *pPager,unqlite_kv_methods *pMethods)
{
	unqlite_db *pStorage = &pPager->pDb->sDB;
	unqlite *pDb = pPager->pDb;
	unqlite_kv_engine *pEngine;
	unqlite_kv_io *pIo;
	sxu32 nByte;
	int rc;
	if( pPager->pEngine ){
		if( pMethods == pPager->pEngine->pIo->pMethods ){
			/* Ticket 1432: Same implementation */
			return UNQLITE_OK;
		}
		/* Release the old KV engine */
		pager_release_kv_engine(pPager);
	}
	/* Allocate a new KV engine instance */
	nByte = (sxu32)pMethods->szKv;
	pEngine = (unqlite_kv_engine *)SyMemBackendAlloc(&pDb->sMem,nByte);
	if( pEngine == 0 ){
		unqliteGenOutofMem(pDb);
		return UNQLITE_NOMEM;
	}
	pIo = (unqlite_kv_io *)SyMemBackendAlloc(&pDb->sMem,sizeof(unqlite_kv_io));
	if( pIo == 0 ){
		SyMemBackendFree(&pDb->sMem,pEngine);
		unqliteGenOutofMem(pDb);
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pIo,sizeof(unqlite_io_methods));
	SyZero(pEngine,nByte);
	/* Populate the IO structure */
	pager_kv_io_init(pPager,pMethods,pIo);
	pEngine->pIo = pIo;
	/* Invoke the init callback if avaialble */
	if( pMethods->xInit ){
		rc = pMethods->xInit(pEngine,unqliteGetPageSize());
		if( rc != UNQLITE_OK ){
			unqliteGenErrorFormat(pDb,
				"xInit() method of the underlying KV engine '%z' failed",&pPager->sKv);
			goto fail;
		}
		pEngine->pIo = pIo;
	}
	pPager->pEngine = pEngine;
	/* Allocate a new cursor */
	rc = unqliteInitCursor(pDb,&pStorage->pCursor);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	return UNQLITE_OK;
fail:
	SyMemBackendFree(&pDb->sMem,pEngine);
	SyMemBackendFree(&pDb->sMem,pIo);
	return rc;
}
/*
 * Return the underlying KV storage engine instance.
 */
UNQLITE_PRIVATE unqlite_kv_engine * unqlitePagerGetKvEngine(unqlite *pDb)
{
	return pDb->sDB.pPager->pEngine;
}
/*
* Allocate and initialize a new Pager object. The pager should
* eventually be freed by passing it to unqlitePagerClose().
*
* The zFilename argument is the path to the database file to open.
* If zFilename is NULL or ":memory:" then all information is held
* in cache. It is never written to disk.  This can be used to implement
* an in-memory database.
*/
UNQLITE_PRIVATE int unqlitePagerOpen(
  unqlite_vfs *pVfs,       /* The virtual file system to use */
  unqlite *pDb,            /* Database handle */
  const char *zFilename,   /* Name of the database file to open */
  unsigned int iFlags      /* flags controlling this file */
  )
{
	unqlite_kv_methods *pMethods = 0;
	int is_mem,rd_only,no_jrnl;
	Pager *pPager;
	sxu32 nByte;
	sxu32 nLen;
	int rc;

	/* Select the appropriate KV storage subsytem  */
	if( (iFlags & UNQLITE_OPEN_IN_MEMORY) || unqliteInMemory(zFilename) ){
		/* An in-memory database, record that  */
		pMethods = unqliteFindKVStore("mem",sizeof("mem") - 1); /* Always available */
		iFlags |= UNQLITE_OPEN_IN_MEMORY;
	}else{
		/* Install the default key value storage subsystem [i.e. Linear Hash] */
		pMethods = unqliteFindKVStore("hash",sizeof("hash")-1);
		if( pMethods == 0 ){
			/* Use the b+tree storage backend if the linear hash storage is not available */
			pMethods = unqliteFindKVStore("btree",sizeof("btree")-1);
		}
	}
	if( pMethods == 0 ){
		/* Can't happen */
		unqliteGenError(pDb,"Cannot install a default Key/Value storage engine");
		return UNQLITE_NOTIMPLEMENTED;
	}
	is_mem = (iFlags & UNQLITE_OPEN_IN_MEMORY) != 0;
	rd_only = (iFlags & UNQLITE_OPEN_READONLY) != 0;
	no_jrnl = (iFlags & UNQLITE_OPEN_OMIT_JOURNALING) != 0;
	rc = UNQLITE_OK;
	if( is_mem ){
		/* Omit journaling for in-memory database */
		no_jrnl = 1;
	}
	/* Total number of bytes to allocate */
	nByte = sizeof(Pager);
	nLen = 0;
	if( !is_mem ){
		nLen = SyStrlen(zFilename);
		nByte += pVfs->mxPathname + nLen + sizeof(char) /* null terminator */;
	}
	/* Allocate */
	pPager = (Pager *)SyMemBackendAlloc(&pDb->sMem,nByte);
	if( pPager == 0 ){
		return UNQLITE_NOMEM;
	}
	/* Zero the structure */
	SyZero(pPager,nByte);
	/* Fill-in the structure */
	pPager->pAllocator = &pDb->sMem;
	pPager->pDb = pDb;
	pDb->sDB.pPager = pPager;
	/* Allocate page table */
	pPager->nSize = 128; /* Must be a power of two */
	nByte = pPager->nSize * sizeof(Page *);
	pPager->apHash = (Page **)SyMemBackendAlloc(pPager->pAllocator,nByte);
	if( pPager->apHash == 0 ){
		rc = UNQLITE_NOMEM;
		goto fail;
	}
	SyZero(pPager->apHash,nByte);
	pPager->is_mem = is_mem;
	pPager->no_jrnl = no_jrnl;
	pPager->is_rdonly = rd_only;
	pPager->iOpenFlags = iFlags;
	pPager->pVfs = pVfs;
	SyRandomnessInit(&pPager->sPrng,0,0);
	SyRandomness(&pPager->sPrng,(void *)&pPager->cksumInit,sizeof(sxu32));
	/* Unlimited cache size */
	pPager->nCacheMax = SXU32_HIGH;
	/* Copy filename and journal name */
	if( !is_mem ){
		pPager->zFilename = (char *)&pPager[1];
		rc = UNQLITE_OK;
		if( pVfs->xFullPathname ){
			rc = pVfs->xFullPathname(pVfs,zFilename,pVfs->mxPathname + nLen,pPager->zFilename);
		}
		if( rc != UNQLITE_OK ){
			/* Simple filename copy */
			SyMemcpy(zFilename,pPager->zFilename,nLen);
			pPager->zFilename[nLen] = 0;
			rc = UNQLITE_OK;
		}else{
			nLen = SyStrlen(pPager->zFilename);
		}
		pPager->zJournal = (char *) SyMemBackendAlloc(pPager->pAllocator,nLen + sizeof(UNQLITE_JOURNAL_FILE_SUFFIX) + sizeof(char));
		if( pPager->zJournal == 0 ){
			rc = UNQLITE_NOMEM;
			goto fail;
		}
		/* Copy filename */
		SyMemcpy(pPager->zFilename,pPager->zJournal,nLen);
		/* Copy journal suffix */
		SyMemcpy(UNQLITE_JOURNAL_FILE_SUFFIX,&pPager->zJournal[nLen],sizeof(UNQLITE_JOURNAL_FILE_SUFFIX)-1);
		/* Append the nul terminator to the journal path */
		pPager->zJournal[nLen + ( sizeof(UNQLITE_JOURNAL_FILE_SUFFIX) - 1)] = 0;
	}
	/* Finally, register the selected KV engine */
	rc = unqlitePagerRegisterKvEngine(pPager,pMethods);
	if( rc != UNQLITE_OK ){
		goto fail;
	}
	/* Set the pager state */
	if( pPager->is_mem ){
		pPager->iState = PAGER_WRITER_FINISHED;
		pPager->iLock = EXCLUSIVE_LOCK;
	}else{
		pPager->iState = PAGER_OPEN;
		pPager->iLock = NO_LOCK;
	}
	/* All done, ready for processing */
	return UNQLITE_OK;
fail:
	SyMemBackendFree(&pDb->sMem,pPager);
	return rc;
}
/*
 * Set a cache limit. Note that, this is a simple hint, the pager is not
 * forced to honor this limit.
 */
UNQLITE_PRIVATE int unqlitePagerSetCachesize(Pager *pPager,int mxPage)
{
	if( mxPage < 256 ){
		return UNQLITE_INVALID;
	}
	pPager->nCacheMax = mxPage;
	return UNQLITE_OK;
}
/*
 * Shutdown the page cache. Free all memory and close the database file.
 */
UNQLITE_PRIVATE int unqlitePagerClose(Pager *pPager)
{
	/* Release the KV engine */
	pager_release_kv_engine(pPager);
	if( pPager->iOpenFlags & UNQLITE_OPEN_MMAP ){
		const unqlite_vfs * pVfs = unqliteExportBuiltinVfs();
		if( pVfs && pVfs->xUnmap && pPager->pMmap ){
			pVfs->xUnmap(pPager->pMmap,pPager->dbByteSize);
		}
	}
	if( !pPager->is_mem && pPager->iState >= PAGER_OPEN) {
		/* Release all lock on this database handle. The issue is
		 * discussed at https://github.com/symisc/unqlite/issues/74.
		 */
		pager_unlock_db(pPager,NO_LOCK);
		/* Close the file  */
		unqliteOsCloseFree(pPager->pAllocator,pPager->pfd);
	}
	if( pPager->pVec ){
		unqliteBitvecDestroy(pPager->pVec);
		pPager->pVec = 0;
	}
	return UNQLITE_OK;
}
/*
 * Generate a random string.
 */
UNQLITE_PRIVATE void unqlitePagerRandomString(Pager *pPager,char *zBuf,sxu32 nLen)
{
	static const char zBase[] = {"abcdefghijklmnopqrstuvwxyz"}; /* English Alphabet */
	sxu32 i;
	/* Generate a binary string first */
	SyRandomness(&pPager->sPrng,zBuf,nLen);
	/* Turn the binary string into english based alphabet */
	for( i = 0 ; i < nLen ; ++i ){
		 zBuf[i] = zBase[zBuf[i] % (sizeof(zBase)-1)];
	 }
}
/*
 * Generate a random number.
 */
UNQLITE_PRIVATE sxu32 unqlitePagerRandomNum(Pager *pPager)
{
	sxu32 iNum = 0; /* cc warning */
	SyRandomness(&pPager->sPrng,(void *)&iNum,sizeof(iNum));
	return iNum;
}
/* Exported KV IO Methods */
/* 
 * Refer to [unqlitePagerAcquire()]
 */
static int unqliteKvIoPageGet(unqlite_kv_handle pHandle,pgno iNum,unqlite_page **ppPage)
{
	int rc;
	rc = unqlitePagerAcquire((Pager *)pHandle,iNum,ppPage,0,0);
	return rc;
}
/* 
 * Refer to [unqlitePagerAcquire()]
 */
static int unqliteKvIoPageLookup(unqlite_kv_handle pHandle,pgno iNum,unqlite_page **ppPage)
{
	int rc;
	rc = unqlitePagerAcquire((Pager *)pHandle,iNum,ppPage,1,0);
	return rc;
}
/* 
 * Refer to [unqlitePagerAcquire()]
 */
static int unqliteKvIoNewPage(unqlite_kv_handle pHandle,unqlite_page **ppPage)
{
	Pager *pPager = (Pager *)pHandle;
	int rc;
	/* 
	 * Acquire a reader-lock first so that pPager->dbSize get initialized.
	 */
	rc = pager_shared_lock(pPager);
	if( rc == UNQLITE_OK ){
		rc = unqlitePagerAcquire(pPager,pPager->dbSize == 0 ? /* Page 0 is reserved */ 1 : pPager->dbSize ,ppPage,0,0);
	}
	return rc;
}
/* 
 * Refer to [unqlitePageWrite()]
 */
static int unqliteKvIopageWrite(unqlite_page *pPage)
{
	int rc;
	if( pPage == 0 ){
		/* TICKET 1433-0348 */
		return UNQLITE_OK;
	}
	rc = unqlitePageWrite(pPage);
	return rc;
}
/* 
 * Refer to [unqlitePagerDontWrite()]
 */
static int unqliteKvIoPageDontWrite(unqlite_page *pPage)
{
	int rc;
	if( pPage == 0 ){
		/* TICKET 1433-0348 */
		return UNQLITE_OK;
	}
	rc = unqlitePagerDontWrite(pPage);
	return rc;
}
/* 
 * Refer to [unqliteBitvecSet()]
 */
static int unqliteKvIoPageDontJournal(unqlite_page *pRaw)
{
	Page *pPage = (Page *)pRaw;
	Pager *pPager;
	if( pPage == 0 ){
		/* TICKET 1433-0348 */
		return UNQLITE_OK;
	}
	pPager = pPage->pPager;
	if( pPager->iState >= PAGER_WRITER_LOCKED ){
		if( !pPager->no_jrnl && pPager->pVec && !unqliteBitvecTest(pPager->pVec,pPage->pgno) ){
			unqliteBitvecSet(pPager->pVec,pPage->pgno);
		}
	}
	return UNQLITE_OK;
}
/* 
 * Do not add a page to the hot dirty list.
 */
static int unqliteKvIoPageDontMakeHot(unqlite_page *pRaw)
{
	Page *pPage = (Page *)pRaw;
	
	if( pPage == 0 ){
		/* TICKET 1433-0348 */
		return UNQLITE_OK;
	}
	pPage->flags |= PAGE_DONT_MAKE_HOT;

	/* Remove from hot dirty list if it is already there */
	if( pPage->flags & PAGE_HOT_DIRTY ){
		Pager *pPager = pPage->pPager;
		if( pPage->pNextHot ){
			pPage->pNextHot->pPrevHot = pPage->pPrevHot;
		}
		if( pPage->pPrevHot ){
			pPage->pPrevHot->pNextHot = pPage->pNextHot;
		}
		if( pPager->pFirstHot == pPage ){
			pPager->pFirstHot = pPage->pPrevHot;
		}
		if( pPager->pHotDirty == pPage ){
			pPager->pHotDirty = pPage->pNextHot;
		}
		pPager->nHot--;
		pPage->flags &= ~PAGE_HOT_DIRTY;
	}

	return UNQLITE_OK;
}
/* 
 * Refer to [page_ref()]
 */
static int unqliteKvIopage_ref(unqlite_page *pPage)
{
	if( pPage ){
		page_ref((Page *)pPage);
	}
	return UNQLITE_OK;
}
/* 
 * Refer to [page_unref()]
 */
static int unqliteKvIoPageUnRef(unqlite_page *pPage)
{
	if( pPage ){
		page_unref((Page *)pPage);
	}
	return UNQLITE_OK;
}
/* 
 * Refer to the declaration of the [Pager] structure
 */
static int unqliteKvIoReadOnly(unqlite_kv_handle pHandle)
{
	return ((Pager *)pHandle)->is_rdonly;
}
/* 
 * Refer to the declaration of the [Pager] structure
 */
static int unqliteKvIoPageSize(unqlite_kv_handle pHandle)
{
	return ((Pager *)pHandle)->iPageSize;
}
/* 
 * Refer to the declaration of the [Pager] structure
 */
static unsigned char * unqliteKvIoTempPage(unqlite_kv_handle pHandle)
{
	return ((Pager *)pHandle)->zTmpPage;
}
/* 
 * Set a page unpin callback.
 * Refer to the declaration of the [Pager] structure
 */
static void unqliteKvIoPageUnpin(unqlite_kv_handle pHandle,void (*xPageUnpin)(void *))
{
	Pager *pPager = (Pager *)pHandle;
	pPager->xPageUnpin = xPageUnpin;
}
/* 
 * Set a page reload callback.
 * Refer to the declaration of the [Pager] structure
 */
static void unqliteKvIoPageReload(unqlite_kv_handle pHandle,void (*xPageReload)(void *))
{
	Pager *pPager = (Pager *)pHandle;
	pPager->xPageReload = xPageReload;
}
/* 
 * Log an error.
 * Refer to the declaration of the [Pager] structure
 */
static void unqliteKvIoErr(unqlite_kv_handle pHandle,const char *zErr)
{
	Pager *pPager = (Pager *)pHandle;
	unqliteGenError(pPager->pDb,zErr);
}
/*
 * Init an instance of the [unqlite_kv_io] structure.
 */
static int pager_kv_io_init(Pager *pPager,unqlite_kv_methods *pMethods,unqlite_kv_io *pIo)
{
	pIo->pHandle =  pPager;
	pIo->pMethods = pMethods;
	
	pIo->xGet    = unqliteKvIoPageGet;
	pIo->xLookup = unqliteKvIoPageLookup;
	pIo->xNew    = unqliteKvIoNewPage;
	
	pIo->xWrite     = unqliteKvIopageWrite; 
	pIo->xDontWrite = unqliteKvIoPageDontWrite;
	pIo->xDontJournal = unqliteKvIoPageDontJournal;
	pIo->xDontMkHot = unqliteKvIoPageDontMakeHot;

	pIo->xPageRef   = unqliteKvIopage_ref;
	pIo->xPageUnref = unqliteKvIoPageUnRef;

	pIo->xPageSize = unqliteKvIoPageSize;
	pIo->xReadOnly = unqliteKvIoReadOnly;

	pIo->xTmpPage =  unqliteKvIoTempPage;

	pIo->xSetUnpin = unqliteKvIoPageUnpin;
	pIo->xSetReload = unqliteKvIoPageReload;

	pIo->xErr = unqliteKvIoErr;

	return UNQLITE_OK;
}

/* END-OF-IMPLEMENTATION: unqlite@embedded@symisc 34-09-46 */
/*
 * Symisc UnQLite-KV: A Transactional Key/Value Store Database Engine.
 * Copyright (C) 2016 - 2019, Symisc Systems http://unqlite.symisc.net/
 * Copyright (C) 2014, Yuras Shumovich <shumovichy@gmail.com>
 * Version 1.2
 * For information on licensing, redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES
 * please contact Symisc Systems via:
 *       legal@symisc.net
 *       licensing@symisc.net
 *       contact@symisc.net
 * or visit:
 *      http://unqlite.symisc.net/licensing.html
 */
/*
 * Copyright (C) 2012, 2013, 2014, 2015, 2016, 2017, 2019 Symisc Systems, S.U.A.R.L [M.I.A.G Mrad Chems Eddine <chm@symisc.net>].
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY SYMISC SYSTEMS ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
 * NON-INFRINGEMENT, ARE DISCLAIMED.  IN NO EVENT SHALL SYMISC SYSTEMS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
