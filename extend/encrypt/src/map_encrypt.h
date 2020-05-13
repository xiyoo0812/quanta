#pragma once

#include <cstdint>

bool map_encrypt(uint8_t key, uint8_t* data_ptr, size_t data_len);

bool map_decrypt(uint8_t key, uint8_t* data_ptr, size_t data_len);