#pragma once

#include <stdint.h>

#if defined (__cplusplus)
extern "C" {
#endif

// LSB-first
uint8_t crc8_lsb(const char* buf, int len);

// MSB-first
uint8_t crc8_msb(const char* buf, int len);

/* crc16 hash */
uint16_t crc16(const char* buf, int len);

/* crc32 hash */
uint32_t crc32(const char* s, int len);

/* crc64 hash */
uint64_t crc64(const char* s, int l);

#if defined (__cplusplus)
}
#endif
