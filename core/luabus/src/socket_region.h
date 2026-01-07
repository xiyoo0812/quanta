#pragma once
#include "lua_kit.h"
#include "socket_helper.h"

const uint32_t xdb_structure_20         = 2;
const uint32_t xdb_structure_30         = 3;
const uint32_t xdb_header_info_length   = 256;
const uint32_t xdb_vector_index_rows    = 256;
const uint32_t xdb_vector_index_cols    = 256;
const uint32_t xdb_vector_index_size    = 8;
const uint32_t xdb_v4_index_size        = 14;    // 4 + 4 + 2 + 4;
const uint32_t xdb_v6_index_size        = 38;    // 16 + 16 + 2 + 4;

// --- ip version info
const uint32_t xdb_ipv4_id              = 4;
const uint32_t xdb_ipv6_id              = 6;
const uint32_t xdb_ipv4_bytes           = 4;
const uint32_t xdb_ipv6_bytes           = 16;
// cache of vector_index_row × vector_index_rows × vector_index_size
const uint32_t xdb_vector_index_length  = 524288;

typedef int (*ip_compare_fn) (upchar, int, cpchar, int);

struct ip_version {
    int id;                 // version id
    cpchar name;            // version name
    int bytes;              // ip bytes number
    int segment_index_size; // segment index size in bytes
    ip_compare_fn ip_compare;
};

inline int ipv4_sub_compare(upchar ip_bytes, int bytes, cpchar buffer, int offset) {
    for (int i = 0, j = offset + bytes - 1; i < bytes; i++, j--) {
        int i0 = ip_bytes[i];
        int i1 = buffer[j] & 0xFF;
        if (i0 > i1) return 1;
        else if (i0 < i1) return -1;
    }
    return 0;
}

inline int ipv6_sub_compare(upchar ip1, int bytes, cpchar buffer, int offset) {
    for (int i = 0; i < bytes; i++) {
        int i1 = ip1[i];
        int i2 = buffer[offset + i] & 0xFF;
        if (i1 > i2) return 1;
        else if (i1 < i2) return -1;
    }
    return 0;
}

int32_t xdb_le_get_uint32(const char* buffer, int offset) {
    return (
        ((buffer[offset]) & 0x000000FF) |
        ((buffer[offset + 1] << 8) & 0x0000FF00) |
        ((buffer[offset + 2] << 16) & 0x00FF0000) |
        ((buffer[offset + 3] << 24) & 0xFF000000)
    );
}

int32_t xdb_le_get_uint16(const char* buffer, int offset) {
    return (
        ((buffer[offset]) & 0x000000FF) |
        ((buffer[offset + 1] << 8) & 0x0000FF00)
    );
}

const ip_version XDB_IPv4 = { xdb_ipv4_id, "IPv4", xdb_ipv4_bytes, xdb_v4_index_size, ipv4_sub_compare };
const ip_version XDB_IPv6 = { xdb_ipv6_id, "IPv6", xdb_ipv6_bytes, xdb_v6_index_size, ipv6_sub_compare };

struct socket_region {
public:
    ~socket_region() {
        if (buffer) {
            free(buffer);
            buffer = nullptr;
        }
    }

    bool load(cpchar db_path) {
        FILE* handle = fopen(db_path, "rb");
        if (handle) {
            fseek(handle, 0, SEEK_END);
            length = ftell(handle);
            fseek(handle, 0, SEEK_SET);
            buffer = (char*)malloc(length);
            if (fread(buffer, 1, length, handle) == length){
                fclose(handle);
                return true;
            }
            free(buffer);
            buffer = nullptr;
        }
        return false;
    }

    const ip_version* parse_ip(pchar ip, upchar buf, size_t length) {
        if (strchr(ip, '.')) {
            if (length < xdb_ipv4_bytes) return nullptr;
            if (inet_pton(AF_INET, ip, buf) != 1) return nullptr;
            return &XDB_IPv4;
        }
        if (strchr(ip, ':')) {
            if (length < xdb_ipv6_bytes) return nullptr;
            if (inet_pton(AF_INET6, ip, buf) != 1) return nullptr;
            return &XDB_IPv6;
        }
        return nullptr;
    }

    int search(lua_State* L, pchar ip) {
        unsigned char ip_bytes[17] = { '\0' };
        auto version = parse_ip(ip, ip_bytes, sizeof(ip_bytes));
        if (version) {
            uint8_t il0 = ip_bytes[0];
            uint8_t il1 = ip_bytes[1];
            char segment_buffer[xdb_v6_index_size];
            uint32_t seg_index_size = version->segment_index_size;
            uint32_t idx = il0 * xdb_vector_index_cols * xdb_vector_index_size + il1 * xdb_vector_index_size;
            uint32_t s_ptr = xdb_le_get_uint32(buffer, xdb_header_info_length + idx);
            uint32_t e_ptr = xdb_le_get_uint32(buffer, xdb_header_info_length + idx + 4);
            uint32_t high = (e_ptr - s_ptr) / seg_index_size;
            uint32_t low = 0, data_len = 0, data_ptr = 0;
            uint32_t d_bytes = version->bytes << 1;
            while (low <= high) {
                uint32_t mid = (low + high) >> 1;
                uint32_t offset = s_ptr + mid * seg_index_size;
                memcpy(segment_buffer, buffer + offset, seg_index_size);
                if (version->ip_compare(ip_bytes, version->bytes, segment_buffer, 0) < 0) {
                    high = mid - 1;
                } else if (version->ip_compare(ip_bytes, version->bytes, segment_buffer, version->bytes) > 0) {
                    low = mid + 1;
                } else {
                    data_len = xdb_le_get_uint16(segment_buffer, d_bytes);
                    data_ptr = xdb_le_get_uint32(segment_buffer, d_bytes + 2);
                    break;
                }
            }
            if (data_len > 0) {
                lua_pushboolean(L, true);
                lua_pushlstring(L, (buffer + data_ptr), data_len);
                return 2;
            }
        }
        lua_pushboolean(L, false);
        return 1;
    }

public:
    uint32_t length;
    char* buffer = nullptr;
};

