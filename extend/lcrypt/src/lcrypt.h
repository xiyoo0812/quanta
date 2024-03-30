
#pragma once

#ifdef _MSC_VER
#ifdef LCRYPT_EXPORT
#ifdef _WINDLL
#define LCRYPT_API _declspec(dllexport)
#else
#define LCRYPT_API
#endif
#else
#define LCRYPT_API _declspec(dllimport)
#endif
#else
#define LCRYPT_API extern
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define SMALL_CHUNK 256
#define LZ_MAX_SIZE_CHUNK 65536

#include "lz4.h"
#include "crc.h"
#include "md5.h"
#include "rsa.h"
#include "sha1.h"
#include "sha2.h"
#include "xxtea.h"
#include "des56.h"
#include "base64.h"

#ifdef __cplusplus
}
#endif
