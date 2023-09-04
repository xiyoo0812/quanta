#pragma once

#include "lcrypt.h"

// LSB-first
LCRYPT_API uint8_t crc8_lsb(const char* buf, int len);

// MSB-first
LCRYPT_API uint8_t crc8_msb(const char* buf, int len);

/* crc16 hash */
LCRYPT_API uint16_t crc16(const char* buf, int len);

/* crc32 hash */
LCRYPT_API uint32_t crc32(const char* s, int len);

/* crc64 hash */
LCRYPT_API uint64_t crc64(const char* s, int l);
