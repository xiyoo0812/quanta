#pragma once
#include <vector>
#include <cstdint>
#include <string_view>
#include <unordered_map>

#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace luapb{
    const uint32_t HOLD_OFFSET = 10;
    enum class wiretype : uint8_t {
        VARINT          = 0,    //int32, int64, uint32, uint64, sint32, sint64, bool, enum
        I64             = 1,    //fixed64, sfixed64, double
        LEN             = 2,    //string, bytes, embedded messages, packed repeated fields
        SGROUP          = 3,    //deprecated
        EGROUP          = 4,    //deprecated
        I32             = 5,    //fixed32, sfixed32, float
    };

    enum class field_type : uint8_t {
        TYPE_DOUBLE     = 1,   // double
        TYPE_FLOAT      = 2,   // float
        TYPE_INT64      = 3,   // int64/sint64
        TYPE_UINT64     = 4,   // uint64
        TYPE_INT32      = 5,   // int32/sint32
        TYPE_FIXED64    = 6,   // fixed64
        TYPE_FIXED32    = 7,   // fixed32
        TYPE_BOOL       = 8,   // bool
        TYPE_STRING     = 9,   // string
        TYPE_GROUP      = 10,  // group (deprecated)
        TYPE_MESSAGE    = 11,  // message（嵌套消息）
        TYPE_BYTES      = 12,  // bytes
        TYPE_UINT32     = 13,  // uint32
        TYPE_ENUM       = 14,  // enum
        TYPE_SFIXED32   = 15,  // sfixed32
        TYPE_SFIXED64   = 16,  // sfixed64
        TYPE_SINT32     = 17,  // sint32
        TYPE_SINT64     = 18,  // sint64
        MAX_TYPE        = 19   // 枚举最大值
    };

    constexpr int pb_tag(uint32_t fieldnum, wiretype wiretype) {
        return ((fieldnum << 3) | (((uint32_t)wiretype) & 7));
    }

    wiretype wiretype_by_fieldtype(field_type t) {
        switch (t) {
        case field_type::TYPE_FLOAT:    return wiretype::I64;
        case field_type::TYPE_INT64:    return wiretype::I32;
        case field_type::TYPE_UINT64:   return wiretype::VARINT;
        case field_type::TYPE_INT32:    return wiretype::VARINT;
        case field_type::TYPE_FIXED64:  return wiretype::I64;
        case field_type::TYPE_FIXED32:  return wiretype::I32;
        case field_type::TYPE_BOOL:     return wiretype::VARINT;
        case field_type::TYPE_STRING:   return wiretype::LEN;
        case field_type::TYPE_GROUP:    return wiretype::LEN;
        case field_type::TYPE_MESSAGE:  return wiretype::LEN;
        case field_type::TYPE_BYTES:    return wiretype::LEN;
        case field_type::TYPE_UINT32:   return wiretype::VARINT;
        case field_type::TYPE_ENUM:     return wiretype::VARINT;
        case field_type::TYPE_SFIXED32: return wiretype::I32;
        case field_type::TYPE_SFIXED64: return wiretype::I64;
        case field_type::TYPE_SINT32:   return wiretype::VARINT;
        case field_type::TYPE_SINT64:   return wiretype::VARINT;
        default:                        return wiretype::EGROUP;
        }
    }

    template<typename T>
    size_t decode_sint(T val) {
        return (val >> 1) ^ -(val & 1);
    }

    template<typename T>
    size_t encode_sint(T val) {
        return (val << 1) ^ -(val < 0);
    }

    template<typename T>
    T read_varint(slice* slice) {
        size_t len = 0;
        auto head = slice->data(&len);
        if (len == 0) throw length_error("length error");
        //小数直接返回
        T result = 0;
        if ((*head & 0x80) == 0) {
            result = *head;
            slice->erase(1);
            return result;
        }
        //大数的处理
        // ceil(bits/7)
        constexpr size_t max_bytes = (sizeof(T) * 8 + 6) / 7;
        for (size_t i = 0; i < max_bytes; ++i) {
            if (i >= len) throw length_error("length error");
            uint8_t byte = *head++;
            result |= static_cast<T>(byte & 0x7F) << (i * 7);
            if ((byte & 0x80) == 0) {
                slice->erase(i + 1);
                return result;
            }
        }
        throw length_error("struct error");
    }

    template<typename T>
    void write_varint(luabuf* buf, T val) {
        using unsignedt = typename std::make_unsigned<T>::type;
        unsignedt uval = static_cast<unsignedt>(val);
        do {
            uint8_t byte = static_cast<uint8_t>(uval & 0x7F);
            uval >>= 7;
            //设置最高位表示还有后续字节
            if (uval != 0) byte |= 0x80;
            if (buf->push_data(&byte, 1) == 0) throw length_error("length error");
        } while (uval != 0);
    }

    template<typename T>
    T read_fixtype(slice* slice) {
        auto data = slice->read<T>();
        if (data == nullptr) throw length_error("length error");
        return *data;
    }

    template<typename T>
    void write_fixtype(luabuf* buf, T value) {
        buf->push_data((uint8_t*)&value, sizeof(T));
    }

    string read_string(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        const char* data = (const char*)slice->erase(length);
        if (data == nullptr) throw length_error("length error");
        return string(data, length);
    }

    void write_string(luabuf* buf, string_view value) {
        uint32_t length = value.size();
        write_varint(buf, length);
        buf->push_data((uint8_t*)value.data(), length);
    }

    slice read_len_prefixed(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        auto data = slice->erase(length);
        if (data == nullptr) throw length_error("length error");
        return luakit::slice(data, length);
    }

    void write_len_prefixed(luabuf* buf, slice* lslice) {
        uint32_t length = lslice->size();
        write_varint(buf, length);
        if (buf->push_data(lslice->head(), length) == 0) throw length_error("length error");
    }

    void write_field_type(luabuf* buf, int field_num, field_type type) {
        auto value = (field_num << 3) | (((uint32_t)wiretype_by_fieldtype(type)) & 7);
        write_varint(buf, value);
    }

    void skip_field(slice* slice, uint32_t field_tag) {
        wiretype wire_type = (wiretype)(field_tag & 0x07);
        switch (wire_type) {
            case wiretype::VARINT: read_varint<uint64_t>(slice); break;
            case wiretype::I64: read_fixtype<int64_t>(slice); break;
            case wiretype::I32: read_fixtype<int32_t>(slice); break;
            case wiretype::LEN: read_len_prefixed(slice); break;
            default: throw length_error("struct error");
        }
    }

    class pb_enum {
    public:
        string name;
        unordered_map<string, int32_t> kvpair;
        unordered_map<int32_t, string> vkpair;
    };

    class pb_field;
    using pb_field_imap = unordered_map<int32_t, pb_field*>;
    using pb_field_smap = unordered_map<string, pb_field*>;
    class pb_message {
    public:
        string name;
        pb_field_imap fields;
        pb_field_smap sfields;
        vector<string> oneof_decl;
        bool is_map = false;
        ~pb_message();
    };

    class pb_descriptor {
    public:
        string syntax;
        map<string, pb_enum*> enums;
        map<string, pb_message*> messages;
        void clean() {
            for (auto& [_, e] : enums) delete e;
            for (auto& [_, m] : messages) delete m;
        }
        ~pb_descriptor() { clean(); }
    };
    static pb_descriptor descriptor;

    pb_message* find_message(string& name) {
        auto it = descriptor.messages.find(name);
        if (it != descriptor.messages.end()) return it->second;
        return nullptr;
    }

    pb_enum* find_enum(string& name) {
        auto it = descriptor.enums.find(name);
        if (it != descriptor.enums.end()) return it->second;
        return nullptr;
    }

    class pb_field {
    public:
        string name;
        string type_name;
        string default_value;
        int32_t number;
        int32_t label;
        field_type type;
        int32_t oneof_index = -1;
        pb_enum* penum = nullptr;
        pb_message* message = nullptr;
        bool packed = false;

        bool is_repeated() { return label == 3; }
        bool is_map() { return get_message() && message->is_map; }
        pb_message* get_message() {
            if (message) return message;
            if (type == field_type::TYPE_MESSAGE && !type_name.empty()) {
                message = find_message(type_name);
            }
            return message;
        }
        pb_enum* get_enum() {
            if (penum) return penum;
            if (type == field_type::TYPE_ENUM && !type_name.empty()) {
                penum = find_enum(type_name);
            }
            return penum;
        }
    };

    pb_message::~pb_message() {
        for (auto& [_, f] : fields) delete f;
    }

    pb_field* find_field_by_number(pb_message* msg, uint32_t field_num) {
        auto it = msg->fields.find(field_num);
        if (it != msg->fields.end()) return it->second;
        return nullptr;
    }

    pb_field* find_field(pb_message* msg, uint32_t tag) {
        return find_field_by_number(msg, tag >> 3);
    }

    pb_field* find_field(pb_message* msg, string name) {
        auto it = msg->sfields.find(name);
        if (it != msg->sfields.end()) return it->second;
        return nullptr;
    }

    void decode_message(lua_State* L, slice* slice, pb_message* msg);
    void decode_field(lua_State* L, slice* slice, pb_field* field) {
        switch (field->type) {
            case field_type::TYPE_FLOAT: lua_pushnumber(L, read_fixtype<float>(slice)); break;
            case field_type::TYPE_DOUBLE: lua_pushnumber(L, read_fixtype<double>(slice)); break;
            case field_type::TYPE_FIXED32: lua_pushinteger(L, read_fixtype<int32_t>(slice)); break;
            case field_type::TYPE_FIXED64: lua_pushinteger(L, read_fixtype<int64_t>(slice)); break;
            case field_type::TYPE_BOOL: lua_pushboolean(L, read_varint<int32_t>(slice)); break;
            case field_type::TYPE_INT32: lua_pushinteger(L, read_varint<int32_t>(slice)); break;
            case field_type::TYPE_UINT32: lua_pushinteger(L, read_varint<uint32_t>(slice)); break;
            case field_type::TYPE_INT64: lua_pushinteger(L, read_varint<int64_t>(slice)); break;
            case field_type::TYPE_UINT64: lua_pushinteger(L, read_varint<uint64_t>(slice)); break;
            case field_type::TYPE_SINT32: lua_pushinteger(L, decode_sint(read_varint<int32_t>(slice))); break;
            case field_type::TYPE_SINT64: lua_pushinteger(L, decode_sint(read_varint<int64_t>(slice))); break;
            case field_type::TYPE_SFIXED32: lua_pushinteger(L, decode_sint(read_fixtype<int32_t>(slice))); break;
            case field_type::TYPE_SFIXED64: lua_pushinteger(L, decode_sint(read_fixtype<int64_t>(slice))); break;
            case field_type::TYPE_ENUM: lua_pushinteger(L, read_varint<int32_t>(slice)); break;
            case field_type::TYPE_MESSAGE: {
                auto mslice = read_len_prefixed(slice);
                decode_message(L, &mslice, field->get_message());
                break;
            }
            case field_type::TYPE_BYTES:
            case field_type::TYPE_STRING: {
                auto s = read_string(slice);
                lua_pushlstring(L, s.c_str(), s.size());
                break;
            }
            default: throw length_error("struct error");
        }
    }

    void decode_map(lua_State* L, slice* slice, pb_field* field) {
        lua_getfield(L, -1, field->name.c_str());
        if (!lua_istable(L, -1)) {
            lua_pop(L, 1);
            lua_createtable(L, 0, 4);
            lua_pushvalue(L, -1);
            lua_setfield(L, -3, field->name.c_str());
        }
        auto msg = field->get_message();
        auto mslice = read_len_prefixed(slice);
        while (!mslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&mslice);
            pb_field* kvfield = find_field(msg, tag);
            decode_field(L, &mslice, kvfield);
            if (kvfield->number == 2) lua_rawset(L, -3);
        }
        lua_pop(L, 1);
    }

    void decode_repeated(lua_State* L, slice* slice, pb_field* field) {
        int len = 1;
        lua_createtable(L, 0, 4);
        auto rslice = read_len_prefixed(slice);
        while (!rslice.empty()) {
            decode_field(L, &rslice, field);
            lua_rawseti(L, -2, len++);
        }
        lua_setfield(L, -2, field->name.c_str());
    }

    void decode_message(lua_State* L, slice* slice, pb_message* msg) {
        lua_createtable(L, 0, msg->fields.size());
        while (!slice->empty()) {
            uint32_t tag = read_varint<uint32_t>(slice);
            pb_field* field = find_field(msg, tag);
            if (!field) {
                skip_field(slice, tag);
                continue;
            }
            if (field->is_map()) {
                decode_map(L, slice, field);
                continue;
            }
            if (field->is_repeated()) {
                decode_repeated(L, slice, field);
                continue;
            }
            decode_field(L, slice, field);
            //oneof名字引用
            if (field->oneof_index < 0) {
                lua_setfield(L, -2, field->name.c_str());
            } else {
                lua_setfield(L, -2, field->name.c_str());
                lua_pushstring(L, field->name.c_str());
                lua_setfield(L, -2, msg->oneof_decl[field->oneof_index].c_str());
            }
        }
    } 
    
    void encode_message(lua_State* L, luabuf* buff, pb_message* msg);
    void encode_field(lua_State* L, luabuf* buff, pb_field* field, int index) {
        switch (field->type) {
            case field_type::TYPE_FLOAT: write_fixtype<float>(buff, lua_tonumber(L, index)); break;
            case field_type::TYPE_DOUBLE: write_fixtype<double>(buff, lua_tonumber(L, index)); break;
            case field_type::TYPE_FIXED32: write_fixtype<int32_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_FIXED64: write_fixtype<int64_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_BOOL: write_varint<int32_t>(buff, lua_toboolean(L, index)); break;
            case field_type::TYPE_INT32: write_varint<int32_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_UINT32: write_varint<uint32_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_INT64: write_varint<int64_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_UINT64: write_varint<uint64_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_SINT32: write_varint<int32_t>(buff, encode_sint(lua_tointeger(L, index))); break;
            case field_type::TYPE_SINT64: write_varint<int64_t>(buff, encode_sint(lua_tointeger(L, index))); break;
            case field_type::TYPE_SFIXED32: write_fixtype<int32_t>(buff, encode_sint(lua_tointeger(L, index))); break;
            case field_type::TYPE_SFIXED64: write_fixtype<int32_t>(buff, encode_sint(lua_tointeger(L, index))); break;
            case field_type::TYPE_ENUM: write_varint<int32_t>(buff, lua_tointeger(L, index)); break;
            case field_type::TYPE_MESSAGE: {
                size_t base = buff->hold_place(HOLD_OFFSET);
                encode_message(L, buff, field->get_message());
                slice* slice = buff->truncature(base, HOLD_OFFSET);
                write_len_prefixed(buff, slice);
                break;
            }
            case field_type::TYPE_BYTES:
            case field_type::TYPE_STRING: {
                size_t len;
                auto s = lua_tolstring(L, index, &len);
                write_string(buff, string_view(s, len));
                break;
            }
            default: luaL_error(L, "encode failed: %s use unsuppert field type!", field->name);
        }
    }

    void encode_map(lua_State* L, luabuf* buff, pb_field* field, int index) {
        auto message = field->get_message();
        index = lua_absindex(L, index);
        lua_pushnil(L);
        while (lua_next(L, index)) {
            write_field_type(buff, field->number, field->type);
            size_t base = buff->hold_place(HOLD_OFFSET);
            pb_field* kfield = find_field_by_number(message, 1);
            write_field_type(buff, kfield->number, kfield->type);
            encode_field(L, buff, kfield, -2);
            pb_field* vfield = find_field_by_number(message, 2);
            write_field_type(buff, vfield->number, vfield->type);
            encode_field(L, buff, vfield, -1);
            slice* slice = buff->truncature(base, HOLD_OFFSET);
            write_len_prefixed(buff, slice);
            lua_pop(L, 1);
        }
    }
    
    void encode_repeated(lua_State* L, luabuf* buff, pb_field* field, int index) {
        write_field_type(buff, field->number, field_type::TYPE_MESSAGE);
        size_t base = buff->hold_place(HOLD_OFFSET);
        index = lua_absindex(L, index);
        lua_pushnil(L);
        while (lua_next(L, index)) {
            encode_field(L, buff, field, -1);
            lua_pop(L, 1);
        }
        slice* slice = buff->truncature(base, HOLD_OFFSET);
        write_len_prefixed(buff, slice);
    }

    void encode_message(lua_State* L, luabuf* buff, pb_message* msg) {
        lua_pushnil(L);
        bool oneofencode = false;
        while (lua_next(L, -2) != 0) {
            if (lua_isstring(L, -2)) {
                pb_field* field = find_field(msg, lua_tostring(L, -2));
                if (field) {
                    if (field->is_map()) {
                        encode_map(L, buff, field, -1);
                    } else if (field->is_repeated()) {
                        encode_repeated(L, buff, field, -1);
                    } else {
                        //oneof处理, 编码一个
                        if (field->oneof_index >= 0) {
                            if (oneofencode) {
                                lua_pop(L, 1);
                                continue;
                            }
                            oneofencode = true;
                        }
                        write_field_type(buff, field->number, field->type);
                        encode_field(L, buff, field, -1);
                    }
                }
            }
            lua_pop(L, 1);
        }
    }

    void read_enum_value(slice* slice, pb_enum* info) {
        int32_t value;
        auto pslice = read_len_prefixed(slice);
        while (!pslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&pslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): info->name = read_string(&pslice); break;
                case pb_tag(2, wiretype::VARINT): value = read_varint<int32_t>(&pslice); break;
                default: skip_field(&pslice, tag); break;
            }
        }
        info->kvpair.emplace(info->name, value);
        info->vkpair.emplace(value, info->name);
    }

    void read_enum(slice* slice, string package) {
        pb_enum* penum = new pb_enum();
        auto eslice = read_len_prefixed(slice);
        while (!eslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&eslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): penum->name = read_string(&eslice), package += "." + penum->name; break;
                case pb_tag(2, wiretype::LEN): read_enum_value(&eslice, penum); break;
                default: skip_field(&eslice, tag); break;
            }
        }
        descriptor.enums.emplace(package, penum);
    }

    void read_field_option(slice* slice, pb_field* field) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&oslice);
            switch (tag) {
                case pb_tag(2, wiretype::VARINT): {
                    auto packed = read_varint<uint32_t>(&oslice);
                    field->packed = packed > 0 ? true : (field->label == 3 && descriptor.syntax == "proto3");
                    break;
                }
                default: skip_field(&oslice, tag); break;
            }
        }
    }

    void read_message_option(slice* slice, pb_message* msg) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&oslice);
            switch (tag) {
                case pb_tag(7, wiretype::VARINT): msg->is_map = read_varint<uint32_t>(&oslice); break;
                default: skip_field(&oslice, tag); break;
            }
        }
    }

    void read_oneof(slice* slice, pb_message* msg) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&oslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN):msg->oneof_decl.emplace_back(read_string(&oslice)); break;
                default: skip_field(&oslice, tag); break;
            }
        }
    }

    void read_field(slice* slice, pb_message* msg) {
        pb_field* field = new pb_field();
        auto fslice = read_len_prefixed(slice);
        while (!fslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&fslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): field->name = read_string(&fslice); break;
                case pb_tag(3, wiretype::VARINT): field->number = read_varint<int32_t>(&fslice); break;
                case pb_tag(4, wiretype::VARINT): field->label = read_varint<int32_t>(&fslice); break;
                case pb_tag(5, wiretype::VARINT): field->type = (field_type)read_varint<int32_t>(&fslice); break;
                case pb_tag(6, wiretype::LEN): field->type_name = read_string(&fslice).substr(1); break;
                case pb_tag(7, wiretype::LEN): field->default_value = read_string(&fslice); break;
                case pb_tag(9, wiretype::VARINT): field->oneof_index = read_varint<int32_t>(&fslice); break;
                case pb_tag(8, wiretype::LEN): read_field_option(&fslice, field); break;
                default: skip_field(&fslice, tag); break;
            }
        }
        msg->fields.emplace(field->number, field);
        msg->sfields.emplace(field->name, field);
    }

    void read_message(slice* slice, string package) {
        pb_message* message = new pb_message();
        auto mslice = read_len_prefixed(slice);
        while (!mslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&mslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): message->name = read_string(&mslice), package += "." + message->name; break;
                case pb_tag(2, wiretype::LEN): read_field(&mslice, message); break;
                case pb_tag(3, wiretype::LEN): read_message(&mslice, package); break;
                case pb_tag(4, wiretype::LEN): read_enum(&mslice, package); break;
                case pb_tag(8, wiretype::LEN): read_oneof(&mslice, message); break;
                case pb_tag(7, wiretype::LEN): read_message_option(&mslice, message); break;
                default: skip_field(&mslice, tag); break;
            }
        }
        descriptor.messages.emplace(package, message);
    }

    void read_file_descriptor(slice* slice) {
        string package;
        auto fslice = read_len_prefixed(slice);
        while (!fslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&fslice);
            switch (tag) {
                case pb_tag(2, wiretype::LEN): package = read_string(&fslice); break;
                case pb_tag(4, wiretype::LEN): read_message(&fslice, package); break;
                case pb_tag(5, wiretype::LEN): read_enum(&fslice, package); break;
                case pb_tag(12, wiretype::LEN): descriptor.syntax = read_string(&fslice); break;
                default: skip_field(&fslice, tag); break;
            }
        }
    }

    void read_file_descriptor_set(slice* slice) {
        descriptor.clean();
        while (!slice->empty()) {
            uint32_t tag = read_varint<uint32_t>(slice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): read_file_descriptor(slice); break;
                default: skip_field(slice, tag); break;
            }
        }
    }

    
    int pb_clear(lua_State* L) {
        descriptor.clean();
        return 0;
    }

    int pb_enums(lua_State* L) {
        vector<string> enums;
        for (auto& e : descriptor.enums) {
            enums.emplace_back(e.first);
        }
        return luakit::variadic_return(L, enums);
    }


    int pb_messages(lua_State* L) {
        map<string, string> messages;
        for (auto& e : descriptor.messages) {
            messages.emplace(e.first, e.second->name);
        }
        return luakit::variadic_return(L, messages);
    }
}
