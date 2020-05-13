
#include "map_encrypt.h"

// version: 1588153191
const static uint8_t s_map_table[] =
{
    225,71,78,22,37,203,84,159,112,99,253,165,21,42,196,180,
    96,189,34,120,29,26,110,109,251,27,76,129,41,178,134,136,
    115,14,1,5,131,227,164,48,65,151,184,104,80,32,67,13,
    69,186,126,222,121,44,98,102,20,254,97,38,77,246,142,130,
    86,72,89,90,138,166,193,106,242,64,101,247,215,183,81,58,
    241,179,105,30,228,156,127,239,39,100,223,137,145,61,153,199,
    205,45,4,24,43,170,36,119,57,123,185,220,95,17,235,113,
    243,35,240,144,181,252,128,33,233,140,122,255,191,28,229,75,
    6,93,68,60,169,175,161,231,139,154,190,217,88,40,0,116,
    245,10,192,234,197,195,204,148,176,152,2,209,168,173,250,174,
    187,118,188,59,82,210,171,132,74,143,182,55,103,163,202,207,
    230,237,150,213,66,214,244,63,201,198,236,167,52,133,226,125,
    224,208,16,47,107,158,194,7,147,49,8,124,219,9,25,146,
    70,3,50,211,238,46,117,177,12,157,172,15,216,51,79,91,
    212,92,249,11,135,232,73,218,23,111,94,83,149,114,200,53,
    221,62,108,206,155,160,162,31,54,87,19,85,248,141,18,56,
};
const static uint8_t s_unmap_table[] =
{
    142,34,154,209,98,35,128,199,202,205,145,227,216,47,33,219,
    194,109,254,250,56,12,3,232,99,206,21,25,125,20,83,247,
    45,119,18,113,102,4,59,88,141,28,13,100,53,97,213,195,
    39,201,210,221,188,239,248,171,255,104,79,163,131,93,241,183,
    73,40,180,46,130,48,208,1,65,230,168,127,26,60,2,222,
    44,78,164,235,6,251,64,249,140,66,67,223,225,129,234,108,
    16,58,54,9,89,74,55,172,43,82,71,196,242,23,22,233,
    8,111,237,32,143,214,161,103,19,52,122,105,203,191,50,86,
    118,27,63,36,167,189,30,228,31,91,68,136,121,253,62,169,
    115,92,207,200,151,236,178,41,153,94,137,244,85,217,197,7,
    245,134,246,173,38,11,69,187,156,132,101,166,218,157,159,133,
    152,215,29,81,15,116,170,77,42,106,49,160,162,17,138,124,
    146,70,198,149,14,148,185,95,238,184,174,5,150,96,243,175,
    193,155,165,211,224,179,181,76,220,139,231,204,107,240,51,90,
    192,0,190,37,84,126,176,135,229,120,147,110,186,177,212,87,
    114,80,72,112,182,144,61,75,252,226,158,24,117,10,57,123,
};


bool map_encrypt(uint8_t key, uint8_t* data_ptr, size_t data_len)
{
    for (size_t n = 0; n < data_len; ++n)
    {
        data_ptr[n] += key;
        data_ptr[n] = s_map_table[data_ptr[n]];   
    }

    return true;
}

bool map_decrypt(uint8_t key, uint8_t* data_ptr, size_t data_len)
{
    for (size_t n = 0; n < data_len; ++n)
    {
        data_ptr[n] = s_unmap_table[data_ptr[n]] - key;
    }

    return true;
}