#include "hmac_sha.h"
#include "wolfssl/openssl/ssl.h"

#include <stdlib.h>

static void xor_key_256(uint8_t key[WC_SHA256_BLOCK_SIZE], uint32_t xor) {
    int i;
    for (i = 0; i < WC_SHA256_BLOCK_SIZE; i += sizeof(uint32_t)) {
        uint32_t* k = (uint32_t*)&key[i];
        *k ^= xor;
    }
}

static void xor_key_512(uint8_t key[WC_SHA512_BLOCK_SIZE], uint32_t xor) {
    int i;
    for (i = 0; i < WC_SHA512_BLOCK_SIZE; i += sizeof(uint32_t)) {
        uint32_t* k = (uint32_t*)&key[i];
        *k ^= xor;
    }
}

void hmac_sha1(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest) {
    SHA_CTX ctx1, ctx2;
    uint8_t rkey[WC_SHA256_BLOCK_SIZE];
    memset(rkey, 0, WC_SHA256_BLOCK_SIZE);
    if (key_len > WC_SHA256_BLOCK_SIZE) {
        SHA1(key, key_len, rkey);
        key_len = WC_SHA_DIGEST_SIZE;
    } else {
        memcpy(rkey, key, key_len);
    }
    xor_key_256(rkey, 0x5c5c5c5c);
    SHA1_Init(&ctx1);
    SHA1_Update(&ctx1, rkey, WC_SHA256_BLOCK_SIZE);
    xor_key_256(rkey, 0x5c5c5c5c ^ 0x36363636);
    SHA1_Init(&ctx2);
    SHA1_Update(&ctx2, rkey, WC_SHA256_BLOCK_SIZE);
    SHA1_Update(&ctx2, text, text_len);
    SHA1_Final(digest, &ctx2);
    SHA1_Update(&ctx1, digest, WC_SHA_DIGEST_SIZE);
    SHA1_Final(digest, &ctx1);
}

void hmac_sha224(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest) {
    SHA224_CTX ctx1, ctx2;
    uint8_t rkey[WC_SHA256_BLOCK_SIZE];
    memset(rkey, 0, WC_SHA256_BLOCK_SIZE);
    if (key_len > WC_SHA256_BLOCK_SIZE) {
        SHA1(key, key_len, rkey);
        key_len = WC_SHA224_DIGEST_SIZE;
    } else {
        memcpy(rkey, key, key_len);
    }
    xor_key_256(rkey, 0x5c5c5c5c);
    SHA224_Init(&ctx1);
    SHA224_Update(&ctx1, rkey, WC_SHA256_BLOCK_SIZE);
    xor_key_256(rkey, 0x5c5c5c5c ^ 0x36363636);
    SHA224_Init(&ctx2);
    SHA224_Update(&ctx2, rkey, WC_SHA256_BLOCK_SIZE);
    SHA224_Update(&ctx2, text, text_len);
    SHA224_Final(digest, &ctx2);
    SHA224_Update(&ctx1, digest, WC_SHA224_DIGEST_SIZE);
    SHA224_Final(digest, &ctx1);
}

void hmac_sha256(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest) {
    SHA256_CTX ctx1, ctx2;
    uint8_t rkey[WC_SHA256_BLOCK_SIZE];
    memset(rkey, 0, WC_SHA256_BLOCK_SIZE);
    if (key_len > WC_SHA256_BLOCK_SIZE) {
        SHA1(key, key_len, rkey);
        key_len = WC_SHA256_DIGEST_SIZE;
    } else {
        memcpy(rkey, key, key_len);
    }
    xor_key_256(rkey, 0x5c5c5c5c);
    SHA256_Init(&ctx1);
    SHA256_Update(&ctx1, rkey, WC_SHA256_BLOCK_SIZE);
    xor_key_256(rkey, 0x5c5c5c5c ^ 0x36363636);
    SHA256_Init(&ctx2);
    SHA256_Update(&ctx2, rkey, WC_SHA256_BLOCK_SIZE);
    SHA256_Update(&ctx2, text, text_len);
    SHA256_Final(digest,  &ctx2);
    SHA256_Update(&ctx1, digest, WC_SHA256_DIGEST_SIZE);
    SHA256_Final(digest, &ctx1);
}

void hmac_sha384(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest) {
    SHA384_CTX ctx1, ctx2;
    uint8_t rkey[WC_SHA512_BLOCK_SIZE];
    memset(rkey, 0, WC_SHA512_BLOCK_SIZE);
    if (key_len > WC_SHA512_BLOCK_SIZE) {
        SHA1(key, key_len, rkey);
        key_len = WC_SHA384_DIGEST_SIZE;
    }else {
        memcpy(rkey, key, key_len);
    }
    xor_key_512(rkey, 0x5c5c5c5c);
    SHA384_Init(&ctx1);
    SHA384_Update(&ctx1, rkey, WC_SHA512_BLOCK_SIZE);
    xor_key_512(rkey, 0x5c5c5c5c ^ 0x36363636);
    SHA384_Init(&ctx2);
    SHA384_Update(&ctx2, rkey, WC_SHA512_BLOCK_SIZE);
    SHA384_Update(&ctx2, text, text_len);
    SHA384_Final(digest, & ctx2);
    SHA384_Update(&ctx1, digest, WC_SHA384_DIGEST_SIZE);
    SHA384_Final(digest, &ctx1);
}

void hmac_sha512(const uint8_t* key, uint32_t key_len, const uint8_t* text, uint32_t text_len, uint8_t* digest) {
    SHA512_CTX ctx1, ctx2;
    uint8_t rkey[WC_SHA512_BLOCK_SIZE];
    memset(rkey, 0, WC_SHA512_BLOCK_SIZE);
    if (key_len > WC_SHA512_BLOCK_SIZE) {
        SHA1(key, key_len, rkey);
        key_len = WC_SHA512_DIGEST_SIZE;
    } else {
        memcpy(rkey, key, key_len);
    }
    xor_key_512(rkey, 0x5c5c5c5c);
    SHA512_Init(&ctx1);
    SHA512_Update(&ctx1, rkey, WC_SHA512_BLOCK_SIZE);
    xor_key_512(rkey, 0x5c5c5c5c ^ 0x36363636);
    SHA512_Init(&ctx2);
    SHA512_Update(&ctx2, rkey, WC_SHA512_BLOCK_SIZE);
    SHA512_Update(&ctx2, text, text_len);
    SHA512_Final(digest, &ctx2);
    SHA512_Update(&ctx1, digest, WC_SHA512_DIGEST_SIZE);
    SHA512_Final(digest, &ctx1);
}
