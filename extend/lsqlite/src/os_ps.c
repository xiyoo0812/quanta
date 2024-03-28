/*
	Copyright 2021 Port for Orbis by Antonio Jose Ramos Marquez aka bigboss contact @psxdev
	Based on SQLite package from EAWEBKIT code from https://gpl.ea.com/eawebkit.html and
	sqlite library for VITA from https://github.com/VitaSmith/libsqlite
	I used this flags -DSQLITE_ENABLE_MEMORY_MANAGEMENT -DSQLITE_OS_OTHER=1  -DSQLITE_OMIT_WAL
	
	Based on PS Vita override for R/W SQLite functionality
	Copyright © 2017 VitaSmith
	Based on original work © 2015 xyzz
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#if defined(__ORBIS__) || defined(__PROSPERO__)

#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <kernel.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include "sqlite3.h"


#ifndef SQLITE_DEFAULT_SECTOR_SIZE
#define SQLITE_DEFAULT_SECTOR_SIZE 512
#endif

static int sLastError = SQLITE_OK;
typedef struct OrbisFile
{
	sqlite3_file base;
	unsigned fd;
}OrbisFile;

static int orbis_xClose(sqlite3_file *pFile)
{
	OrbisFile *p=(OrbisFile*)pFile;
	sceKernelClose(p->fd);
	return SQLITE_OK;
}

static int orbis_xRead(sqlite3_file *pFile,void *zBuf,int iAmt,sqlite_int64 iOfst)
{
	OrbisFile *p=(OrbisFile*)pFile;
	memset(zBuf,0,iAmt);
	sceKernelLseek(p->fd,iOfst,SEEK_SET);
	int read_bytes=sceKernelRead(p->fd,zBuf,iAmt);
	if(read_bytes==iAmt)
	{
		return SQLITE_OK;
	}
	else if(read_bytes<0)
	{
		sLastError=SQLITE_IOERR_READ;
		return SQLITE_IOERR_READ;
	}
	sLastError=SQLITE_IOERR_SHORT_READ;
	return SQLITE_IOERR_SHORT_READ;
}

static int orbis_xWrite(sqlite3_file *pFile,const void *zBuf,int iAmt,sqlite_int64 iOfst)
{
	OrbisFile *p=(OrbisFile*)pFile;
	int ofst=sceKernelLseek(p->fd,iOfst,SEEK_SET);
	if (ofst!=iOfst)
	{
		sLastError=SQLITE_IOERR_WRITE;
		return SQLITE_IOERR_WRITE;
	}
	int write_bytes=sceKernelWrite(p->fd,zBuf,iAmt);
	if(write_bytes!=iAmt)
	{
		sLastError=SQLITE_IOERR_WRITE;
		return SQLITE_IOERR_WRITE;
	}
	return SQLITE_OK;
}

static int orbis_xTruncate(sqlite3_file *pFile,sqlite_int64 size)
{
	return SQLITE_OK;
}

static int orbis_xSync(sqlite3_file *pFile,int flags)
{
	sceKernelSync();
	return SQLITE_OK;
}

static int orbis_xFileSize(sqlite3_file *pFile,sqlite_int64 *pSize)
{
	OrbisFile *p=(OrbisFile*)pFile;
	struct stat stat={0};
	fstat(p->fd,&stat);
	*pSize=stat.st_size;
	return SQLITE_OK;
}

static int orbis_xLock(sqlite3_file *pFile,int eLock)
{
	return SQLITE_OK;
}

static int orbis_xUnlock(sqlite3_file *pFile,int eLock)
{
	return SQLITE_OK;
}

static int orbis_xCheckReservedLock(sqlite3_file *pFile,int *pResOut)
{
	*pResOut=0;
	return SQLITE_OK;
}

static int orbis_xFileControl(sqlite3_file *pFile,int op,void *pArg)
{
	return SQLITE_OK;
}

static int orbis_xSectorSize(sqlite3_file *pFile)
{
	return SQLITE_DEFAULT_SECTOR_SIZE;
}

static int orbis_xDeviceCharacteristics(sqlite3_file *pFile)
{
	return SQLITE_OK;
}

static int orbis_xOpen(sqlite3_vfs *vfs,const char *name,sqlite3_file *file,int flags,int *outFlags)
{
	static const sqlite3_io_methods orbis_io=
	{
		3,
		orbis_xClose,
		orbis_xRead,
		orbis_xWrite,
		orbis_xTruncate,
		orbis_xSync,
		orbis_xFileSize,
		orbis_xLock,
		orbis_xUnlock,
		orbis_xCheckReservedLock,
		orbis_xFileControl,
		orbis_xSectorSize,
		orbis_xDeviceCharacteristics,
	};
	OrbisFile *p=(OrbisFile*)file;
	unsigned oflags=0;
	if(flags & SQLITE_OPEN_EXCLUSIVE)
		oflags |= O_EXCL;
	if(flags & SQLITE_OPEN_CREATE)
		oflags |= O_CREAT;
	if(flags & SQLITE_OPEN_READONLY)
		oflags |= O_RDONLY;
	if(flags & SQLITE_OPEN_READWRITE)
		oflags |= O_CREAT|O_RDWR;
	memset(p,0,sizeof(*p));
	// SQLite expects a journal file to be created if SQLITE_OPEN_READWRITE was
	// specified, *EVEN* if SQLITE_OPEN_CREATE wasn't
	int fd=sceKernelOpen(name,O_RDONLY,0666);
	if(fd<0)
	{
		fd=sceKernelOpen(name,O_CREAT|O_RDWR,0666);
	}
	if(fd>0)
	{
		sceKernelClose(fd);
	}
	else
	{
		sLastError=SQLITE_CANTOPEN;
		return SQLITE_CANTOPEN;
	}
	p->fd=sceKernelOpen(name,O_RDWR,0666);
	if(p->fd<0)
	{
		sLastError=SQLITE_CANTOPEN;
		return SQLITE_CANTOPEN;
	}
	if(outFlags)
	{
		*outFlags=SQLITE_OPEN_READONLY;
		if(flags & SQLITE_OPEN_READWRITE)
		{
			*outFlags=SQLITE_OPEN_READWRITE;
		}
	}
	p->base.pMethods=&orbis_io;
	return SQLITE_OK;
}

static int orbis_xDelete(sqlite3_vfs *vfs,const char *name,int syncDir)
{
	unlink(name);
	return SQLITE_OK;
}

static int orbis_xAccess(sqlite3_vfs *vfs, const char *name,int flags,int *pResOut)
{
	*pResOut=1;
	return SQLITE_OK;
}

static int orbis_xFullPathname(sqlite3_vfs *vfs,const char *zName,int nOut,char *zOut)
{
	sqlite3_snprintf(nOut,zOut,"%s",zName);
	return SQLITE_OK;
}

static void* orbis_xDlOpen(sqlite3_vfs *vfs,const char *zFilename)
{
	return NULL;
}

static void orbis_xDlError(sqlite3_vfs *vfs,int nByte,char *zErrMsg)
{
	return;
}

static void(*orbis_xDlSym(sqlite3_vfs *vfs,void *p,const char *zSymbol))(void)
{
	return NULL;
}

static void orbis_xDlClose(sqlite3_vfs *vfs,void*p)
{
	return;
}

static int orbis_xRandomness(sqlite3_vfs *vfs,int nByte,char *zOut)
{
	for(int i = 0; i < nByte; i++)
		zOut[i] = (((uint32_t)time(0) ^ i) + zOut[i]) & 0xFF;

	return nByte;
}

static int orbis_xSleep(sqlite3_vfs *vfs,int microseconds)
{
	sceKernelUsleep(microseconds);
	return SQLITE_OK;
}

static int orbis_xCurrentTime(sqlite3_vfs *vfs,double *pTime)
{
	struct timespec ts={0};
	clock_gettime(CLOCK_MONOTONIC,&ts);
	*pTime=ts.tv_sec+ts.tv_nsec/1000000000.0;
	return SQLITE_OK;
}

static int orbis_xGetLastError(sqlite3_vfs *vfs, int e, char *err)
{
	sqlite3_snprintf(e,err,"OsError 0x%x (%u)",sLastError,sLastError);
	return SQLITE_OK;
}

static sqlite3_vfs orbis_vfs= 
{
	// VFS settings
	3,					// iVersion 
	sizeof(OrbisFile),	// szOsFile
	512,				// mxPathname
	0,					// pNext
	"orbis_rw",			// zName
	0,					// pAppData
	// File access functions
	orbis_xOpen,		// xOpen
	orbis_xDelete,		// xDelete
	orbis_xAccess,		// xAccess
	orbis_xFullPathname,// xFullPathname
	// these four functions are for opening a shared library, finding code entry points
	// with in the library and closing the library.  These are not currently supported!
	orbis_xDlOpen,		// xDlOpen
	orbis_xDlError,		// xDlError
	orbis_xDlSym,		// xDlSym
	orbis_xDlClose,		// xDlClose
	// Utility functions
	orbis_xRandomness,	// xRandomness
	orbis_xSleep,		// xSleep
	orbis_xCurrentTime,	// xCurrentTime
	orbis_xGetLastError	// xGetLastError  
};

int sqlite3_os_init(void)
{
	return sqlite3_vfs_register(&orbis_vfs, 1);
}

int sqlite3_os_end(void)
{
	return SQLITE_OK;
}

#endif