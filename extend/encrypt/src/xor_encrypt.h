#pragma once


#include <cstdint>

inline bool xor_encrypt(uint16_t key, uint8_t* data_ptr, size_t data_len)
{
    for (size_t n = 0; n < data_len; ++n)
    {
        data_ptr[n] ^= key;
    }

    return true;
}

inline bool xor_decrypt(uint16_t key, uint8_t* data_ptr, size_t data_len)
{
    for (size_t n = 0; n < data_len; ++n)
    {
        data_ptr[n] ^= key;
    }

    return true;
}
