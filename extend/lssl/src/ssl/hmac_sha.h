#pragma once

#include <stdint.h>


#if defined (__cplusplus)
extern "C" {
#endif

void hmac_sha1(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest);

void hmac_sha224(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest);
void hmac_sha256(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest);
void hmac_sha384(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest);
void hmac_sha512(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest);

#if defined (__cplusplus)
}
#endif
