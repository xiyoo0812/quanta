#pragma once
#include <vector>
#include <cstdint>
#include <string_view>
#include <unordered_map>

#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace luapb{
    const uint32_t HOLD_OFFSET = 1;
    const uint32_t VARI_OFFSET = 10;
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

    template<typename T>
    inline int64_t decode_sint(T val) {
        int64_t mask = static_cast<int64_t>(val & 1) * -1;
        return (val >> 1) ^ mask;
    }

    template<typename T>
    inline size_t encode_sint(T val) {
        return (val << 1) ^ -(val < 0);
    }

    template<typename T>
    inline T read_varint(slice* slice) {
        size_t len = 0;
        auto head = slice->data(&len);
        if (len == 0) throw length_error("read_varint buffer length not engugh");
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
            if (i >= len) throw length_error("read_varint buffer length not engugh");
            uint8_t byte = *head++;
            result |= static_cast<T>(byte & 0x7F) << (i * 7);
            if ((byte & 0x80) == 0) {
                slice->erase(i + 1);
                return result;
            }
        }
        throw length_error("read_varint invalid binrary");
    }

    template<typename T>
    inline size_t write_varint(luabuf* buf, T val) {
        uint8_t* data = buf->peek_space(VARI_OFFSET);
        if (data == nullptr) throw lua_exception("write_varint buffer overflow");
        if (val < 0x80) {
            *data = static_cast<uint8_t>(val);
            return buf->pop_space(1);
        }
        size_t len = 0;
        while (val >= 0x80) {
            data[len++] = static_cast<uint8_t>((val & 0x7F) | 0x80);
            val >>= 7;
        }
        data[len++] = static_cast<uint8_t>(val);
        return buf->pop_space(len);
    }

    template<typename T>
    inline T read_fixtype(slice* slice) {
        auto data = slice->read<T>();
        if (data == nullptr) throw length_error("read_fixtype buffer length not engugh");
        return *data;
    }

    template<typename T>
    inline void write_fixtype(luabuf* buf, T value) {
        buf->write<T>(value);
    }

    inline string_view read_string(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        const char* data = (const char*)slice->erase(length);
        if (data == nullptr) throw length_error("read_string buffer length not engugh");
        return string_view(data, length);
    }

    inline void write_string(luabuf* buf, string_view value) {
        uint32_t length = value.size();
        write_varint(buf, length);
        buf->push_data((uint8_t*)value.data(), length);
    }

    inline slice read_len_prefixed(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        auto data = slice->erase(length);
        if (data == nullptr) throw length_error("read_len_prefixed buffer length not engugh");
        return luakit::slice(data, length);
    }

    inline void write_len_prefixed(luabuf* buf, slice* lslice) {
        uint32_t length = lslice ? lslice->size() : 0;
        if (length < 0x80) {
            buf->write(static_cast<uint8_t>(length));
            buf->pop_space(length);
            return;
        }
        if (length < 0x4000) {
            buf->copy(buf->size() + 2, lslice->head(), length);
            size_t len = write_varint(buf, length);
            buf->pop_space(length);
            return;
        }
        size_t offset = length + VARI_OFFSET + HOLD_OFFSET;
        size_t base = buf->hold_place(offset);
        size_t len = write_varint(buf, length);
        buf->copy(base + len, lslice->head(), length);
        slice* var = buf->free_place(base, offset);
        buf->copy(base, var->head(), len);
        buf->pop_space(length + len);
    }

    inline void skip_field(slice* slice, uint32_t field_tag) {
        wiretype wire_type = (wiretype)(field_tag & 0x07);
        switch (wire_type) {
            case wiretype::VARINT: read_varint<uint64_t>(slice); break;
            case wiretype::I64: read_fixtype<int64_t>(slice); break;
            case wiretype::I32: read_fixtype<int32_t>(slice); break;
            case wiretype::LEN: read_len_prefixed(slice); break;
            default: throw length_error("skip_field invalid wiretype");
        }
    }

    class pb_enum {
    public:
        string name;
        unordered_map<string, int32_t> kvpair;
        unordered_map<int32_t, string> vkpair;
    };

    struct field {
        string name;
        string type_name;
        int32_t number;
        int32_t label;
        field_type type;
        int32_t oneof_index = -1;
        bool packed = false;
    };

    class pb_field;
    using pb_field_imap = unordered_map<int32_t, pb_field*>;
    using pb_field_smap = unordered_map<string_view, pb_field*>;
    class pb_message {
    public:
        ~pb_message();
        string name;
        int32_t meta_ref;
        pb_field_imap fields;
        pb_field_imap tfields;
        pb_field_smap sfields;
        vector<string> oneof_decl;
        bool is_map = false;

        void create_metatable(lua_State* L);
    };

    class pb_descriptor {
    public:
        string syntax;
        bool use_mteatable = false;
        bool encode_default = false;
        unordered_map<string, pb_enum*> enums;
        unordered_map<string, pb_message*> messages;
        unordered_map<string_view, int32_t> field_refs;
        void clean() {
            for (auto& [_, e] : enums) delete e;
            for (auto& [_, m] : messages) delete m;
            messages.clear();
            enums.clear();
        }
        ~pb_descriptor() { clean(); }
    };
    thread_local pb_descriptor descriptor;

    inline pb_message* find_message(const char* name) {
        auto it = descriptor.messages.find(name);
        if (it != descriptor.messages.end()) return it->second;
        return nullptr;
    }

    inline int32_t find_ref(lua_State* L, string& name) {
        auto it = descriptor.field_refs.find(name);
        if (it != descriptor.field_refs.end()) return it->second;
        lua_pushlstring(L, name.c_str(), name.size());
        int32_t ref = luaL_ref(L, LUA_REGISTRYINDEX);
        descriptor.field_refs.emplace(name, ref);
        return ref;
    }

    inline pb_enum* find_enum(const char* name) {
        auto it = descriptor.enums.find(name);
        if (it != descriptor.enums.end()) return it->second;
        return nullptr;
    }

    class pb_field {
    public:
        string name;
        string type_name;
        int32_t number;
        int32_t label;
        wiretype wtype;
        field_type type;
        int32_t name_ref = 0;
        int32_t oneof_index = -1;
        pb_message* message = nullptr;
        uint32_t tag = 0;
        bool fill = false;
        bool packed = false;

        pb_field(const field& f, wiretype w) : name(f.name), type_name(f.type_name), number(f.number), label(f.label)
            , wtype(w), type(f.type), oneof_index(f.oneof_index) {
            tag = (number << 3) | (((uint32_t)wtype) & 7);
        }
        virtual ~pb_field() {};

        virtual void push_field(lua_State* L) = 0;
        virtual void push_default(lua_State* L) = 0;
        virtual void decode(lua_State* L, slice* s) = 0;
        virtual void encode(lua_State* L, int idx, luabuf* buff, bool enc_tag = true, bool enc_default = false) = 0;
        inline bool is_repeated() { return label == 3; }
        inline bool is_map() { return message && message->is_map; }
        inline bool need_fill() {
            if (fill) { fill = false; return false; }
            return true;
        }
        inline bool not_fill() {
            if (fill) return false;
            fill = true;
            return true;
        }
        inline void location(lua_State* L) {
            name_ref = find_ref(L, name);
            if (type == field_type::TYPE_MESSAGE && !type_name.empty()) {
                message = find_message(type_name.c_str());
            }
        }
    };

    void decode_message(lua_State* L, slice* slice, pb_message* msg);
    void encode_message(lua_State* L, int index, luabuf* buff, pb_message* msg);

    template<typename T, field_type FT>
    class pb_field_impl : public pb_field {
    public:
        pb_field_impl(const field& f, wiretype w) : pb_field(f, w) {}

        virtual void push_field(lua_State* L) {
            if (name_ref > 0) {
                lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
            } else {
                lua_pushlstring(L, name.c_str(), name.size());
            }
        }
        virtual void push_default(lua_State* L) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
            if constexpr (is_integral_v<T>) lua_pushinteger(L, 0);
            else if constexpr (is_floating_point_v<T>) lua_pushnumber(L, 0);
            else if constexpr (is_same_v<T, bool>) lua_pushboolean(L, false);
            else if constexpr (is_same_v<T, string_view>) lua_pushstring(L, "");
            else if constexpr (is_pointer_v<T>) decode_message(L, nullptr, message);
        }
        virtual void decode(lua_State* L, slice* s) {
            if constexpr (FT == field_type::TYPE_FLOAT) lua_pushnumber(L, read_fixtype<float>(s));
            else if constexpr (FT == field_type::TYPE_DOUBLE) lua_pushnumber(L, read_fixtype<double>(s));
            else if constexpr (FT == field_type::TYPE_FIXED32) lua_pushinteger(L, read_fixtype<uint32_t>(s));
            else if constexpr (FT == field_type::TYPE_FIXED64) lua_pushinteger(L, read_fixtype<uint64_t>(s));
            else if constexpr (FT == field_type::TYPE_BOOL) lua_pushboolean(L, read_varint<uint32_t>(s));
            // TYPE_INT32在负数的时候，会被扩展位uint64编码，因此使用int64_t去解码
            else if constexpr (FT == field_type::TYPE_INT32) lua_pushinteger(L, read_varint<int64_t>(s));
            else if constexpr (FT == field_type::TYPE_INT64) lua_pushinteger(L, read_varint<int64_t>(s));
            else if constexpr (FT == field_type::TYPE_UINT32) lua_pushinteger(L, read_varint<uint32_t>(s));
            else if constexpr (FT == field_type::TYPE_UINT64) lua_pushinteger(L, read_varint<uint64_t>(s));
            else if constexpr (FT == field_type::TYPE_SINT32) lua_pushinteger(L, decode_sint(read_varint<uint32_t>(s)));
            else if constexpr (FT == field_type::TYPE_SINT64) lua_pushinteger(L, decode_sint(read_varint<uint64_t>(s)));
            else if constexpr (FT == field_type::TYPE_SFIXED32) lua_pushinteger(L, read_fixtype<int32_t>(s));
            else if constexpr (FT == field_type::TYPE_SFIXED64) lua_pushinteger(L, read_fixtype<int64_t>(s));
            else if constexpr (FT == field_type::TYPE_ENUM) lua_pushinteger(L, read_varint<uint32_t>(s));
            else if constexpr (FT == field_type::TYPE_MESSAGE) {
                auto mslice = read_len_prefixed(s);
                decode_message(L, &mslice, message);
            }
            else if constexpr (FT == field_type::TYPE_BYTES || FT == field_type::TYPE_STRING) {
                auto str = read_string(s);
                lua_pushlstring(L, str.data(), str.size());
            }
            else throw length_error("decode_field invalid field_type");
        }
        virtual void encode(lua_State* L, int idx, luabuf* buff, bool enc_tag = true, bool enc_default = false) {
            T val = read_field(L, idx, buff);
            if (enc_default || not_default(val)) {
                if (enc_tag) write_varint(buff, tag);
                write_field(L, idx, buff, val);
            }
        }
    private:
        inline T read_field(lua_State* L, int idx, luabuf* buff) {
            if constexpr (is_integral_v<T>) return static_cast<T>(lua_tointeger(L, idx));
            else if constexpr (is_floating_point_v<T>) return static_cast<T>(lua_tonumber(L, idx));
            else if constexpr (is_same_v<T, bool>) return lua_toboolean(L, idx);
            else if constexpr (is_pointer_v<T>) return nullptr;
            else if constexpr (is_same_v<T, string_view>) {
                size_t len;
                const char* str = lua_tolstring(L, idx, &len);
                return (str == nullptr ? "" : string_view(str, len));
            }
        }
        inline bool not_default(T& val) {
            if constexpr (is_integral_v<T>) return val != 0;
            else if constexpr (is_floating_point_v<T>) return val != 0;
            else if constexpr (is_same_v<T, bool>) return val == true;
            else if constexpr (is_same_v<T, string_view>) return val.size() > 0;
            return true;
        }
        inline void write_field(lua_State* L, int idx, luabuf* buff, T& val) {
            if constexpr (FT == field_type::TYPE_UINT32) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_UINT64) write_varint<uint64_t>(buff, val);
            //int32, int64的负数会被视为 64 位无符号整数，因此使用uint64_t去生成varint
            else if constexpr (FT == field_type::TYPE_INT32) write_varint<uint64_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_INT64) write_varint<uint64_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_STRING) write_string(buff, val);
            else if constexpr (FT == field_type::TYPE_BOOL) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_BYTES) write_string(buff, val);
            else if constexpr (FT == field_type::TYPE_SINT32) write_varint<uint32_t>(buff, encode_sint<int32_t>(val));
            else if constexpr (FT == field_type::TYPE_SINT64) write_varint<uint64_t>(buff, encode_sint<int64_t>(val));
            else if constexpr (FT == field_type::TYPE_SFIXED32) write_fixtype<int32_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_SFIXED64) write_fixtype<int64_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_ENUM) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_FLOAT) write_fixtype<float>(buff, val);
            else if constexpr (FT == field_type::TYPE_DOUBLE) write_fixtype<double>(buff, val);
            else if constexpr (FT == field_type::TYPE_FIXED32) write_fixtype<uint32_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_FIXED64) write_fixtype<uint64_t>(buff, val);
            else if constexpr (FT == field_type::TYPE_MESSAGE) {
                size_t base = buff->hold_place(HOLD_OFFSET);
                encode_message(L, idx, buff, message);
                write_len_prefixed(buff, buff->free_place(base, HOLD_OFFSET));
            }
            else throw lua_exception("encode failed: %s use unsuppert field type!", name.c_str());
        }
    };

    pb_field* new_pbfield(const field& f) {
        switch (f.type) {
        case field_type::TYPE_DOUBLE:   return new pb_field_impl<double, field_type::TYPE_DOUBLE>(f, wiretype::I64);
        case field_type::TYPE_FLOAT:    return new pb_field_impl<float, field_type::TYPE_FLOAT>(f, wiretype::I32);
        case field_type::TYPE_INT64:    return new pb_field_impl<int64_t, field_type::TYPE_INT64>(f, wiretype::VARINT);
        case field_type::TYPE_UINT64:   return new pb_field_impl<uint64_t, field_type::TYPE_UINT64>(f, wiretype::VARINT);
        case field_type::TYPE_INT32:    return new pb_field_impl<int32_t, field_type::TYPE_INT32>(f, wiretype::VARINT);
        case field_type::TYPE_FIXED64:  return new pb_field_impl<int64_t, field_type::TYPE_FIXED64>(f, wiretype::I64);
        case field_type::TYPE_FIXED32:  return new pb_field_impl<int32_t, field_type::TYPE_FIXED32>(f, wiretype::I32);
        case field_type::TYPE_BOOL:     return new pb_field_impl<bool, field_type::TYPE_BOOL>(f, wiretype::VARINT);
        case field_type::TYPE_STRING:   return new pb_field_impl<string_view, field_type::TYPE_STRING>(f, wiretype::LEN);
        case field_type::TYPE_GROUP:    return new pb_field_impl<int64_t, field_type::TYPE_GROUP>(f, wiretype::LEN);
        case field_type::TYPE_MESSAGE:  return new pb_field_impl<slice*, field_type::TYPE_MESSAGE>(f, wiretype::LEN);
        case field_type::TYPE_BYTES:    return new pb_field_impl<string_view, field_type::TYPE_BYTES>(f, wiretype::LEN);
        case field_type::TYPE_UINT32:   return new pb_field_impl<uint32_t, field_type::TYPE_UINT32>(f, wiretype::VARINT);
        case field_type::TYPE_ENUM:     return new pb_field_impl<uint32_t, field_type::TYPE_ENUM>(f, wiretype::VARINT);
        case field_type::TYPE_SFIXED32: return new pb_field_impl<uint32_t, field_type::TYPE_SFIXED32>(f, wiretype::I32);
        case field_type::TYPE_SFIXED64: return new pb_field_impl<uint64_t, field_type::TYPE_SFIXED64>(f, wiretype::I64);
        case field_type::TYPE_SINT32:   return new pb_field_impl<uint32_t, field_type::TYPE_SINT32>(f, wiretype::VARINT);
        case field_type::TYPE_SINT64:   return new pb_field_impl<uint64_t, field_type::TYPE_SINT64>(f, wiretype::VARINT);
        default:                        return new pb_field_impl<uint32_t, field_type::MAX_TYPE>(f, wiretype::EGROUP);
        }
    }

    pb_message::~pb_message() {
        for (auto& [_, f] : fields) delete f;
    }

    void pb_message::create_metatable(lua_State* L) {
        lua_createtable(L, 0, 1);
        lua_createtable(L, 0, fields.size());
        for (auto& [name, field] : sfields) {
            if (field->is_map() || field->is_repeated()) continue;
            field->push_default(L);
            lua_settable(L, -3);
        }
        lua_setfield(L, -2, "__index");
        meta_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    inline pb_field* find_field_by_number(pb_message* msg, uint32_t field_num) {
        auto it = msg->fields.find(field_num);
        if (it != msg->fields.end()) return it->second;
        return nullptr;
    }

    inline pb_field* find_field(pb_message* msg, uint32_t tag) {
        auto it = msg->tfields.find(tag);
        if (it != msg->tfields.end()) return it->second;
        return nullptr;
    }

    inline pb_field* find_field(pb_message* msg, const char* name) {
        auto it = msg->sfields.find(name);
        if (it != msg->sfields.end()) return it->second;
        return nullptr;
    }

    void decode_map(lua_State* L, slice* slice, pb_field* field) {
        lua_getfield(L, -1, field->name.c_str());
        auto msg = field->message;
        auto mslice = read_len_prefixed(slice);
        while (!mslice.empty()) {
            uint32_t ktag = read_varint<uint32_t>(&mslice);
            pb_field* kfield = find_field(msg, ktag);
            kfield->decode(L, &mslice);
            uint32_t vtag = read_varint<uint32_t>(&mslice);
            pb_field* vfield = find_field(msg, vtag);
            vfield->decode(L, &mslice);
            lua_rawset(L, -3);
        }
        lua_pop(L, 1);
    }

    void decode_repeated(lua_State* L, slice* slice, pb_field* field) {
        lua_getfield(L, -1, field->name.c_str());
        if (field->packed) {
            int len = 1;
            auto rslice = read_len_prefixed(slice);
            while (!rslice.empty()) {
                field->decode(L, &rslice);
                lua_rawseti(L, -2, len++);
            }
        }
        else {
            int len = lua_rawlen(L, -1);
            field->decode(L, slice);
            lua_rawseti(L, -2, len + 1);
        }
        lua_pop(L, 1);
    }

    void decode_message(lua_State* L, slice* slice, pb_message* msg) {
        lua_createtable(L, 0, msg->fields.size());
        while (slice && !slice->empty()) {
            uint32_t tag = read_varint<uint32_t>(slice);
            pb_field* field = find_field(msg, tag);
            if (!field) {
                skip_field(slice, tag);
                continue;
            }
            bool nfill = field->not_fill();
            if (field->is_map()) {
                if (nfill) {
                    field->push_field(L);
                    lua_createtable(L, 0, 4);
                    lua_settable(L, -3);
                }
                decode_map(L, slice, field);
                continue;
            }
            if (field->is_repeated()) {
                if (nfill) {
                    field->push_field(L);
                    lua_createtable(L, 0, 4);
                    lua_settable(L, -3);
                }
                decode_repeated(L, slice, field);
                continue;
            }
            field->push_field(L);
            field->decode(L, slice);
            //oneof名字引用
            if (field->oneof_index < 0) {
                lua_settable(L, -3);
            }
            else {
                lua_settable(L, -3);
                field->push_field(L);
                lua_setfield(L, -2, msg->oneof_decl[field->oneof_index].c_str());
            }
        }
        if (descriptor.use_mteatable) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, msg->meta_ref);
            lua_setmetatable(L, -2);
        }
        for (auto& [name, field] : msg->sfields) {
            if (field->need_fill() && !descriptor.use_mteatable) {
                field->push_default(L);
                lua_settable(L, -3);
            }
        }
    }

    void encode_map(lua_State* L, luabuf* buff, pb_field* field, int index) {
        auto message = field->message;
        index = lua_absindex(L, index);
        lua_pushnil(L);
        while (lua_next(L, index)) {
            write_varint(buff, field->tag);
            size_t base = buff->hold_place(HOLD_OFFSET);
            pb_field* kfield = find_field_by_number(message, 1);
            kfield->encode(L, -2, buff);
            pb_field* vfield = find_field_by_number(message, 2);
            vfield->encode(L, -1, buff);
            slice* slice = buff->free_place(base, HOLD_OFFSET);
            write_len_prefixed(buff, slice);
            lua_pop(L, 1);
        }
    }

    void encode_repeated(lua_State* L, luabuf* buff, pb_field* field, int index) {
        int rawlen = lua_rawlen(L, index);
        if (rawlen == 0 && !descriptor.encode_default) return;
        if (field->packed) {
            write_varint(buff, field->tag);
            size_t base = buff->hold_place(HOLD_OFFSET);
            for (int i = 1; i <= rawlen; ++i) {
                lua_geti(L, index, i);
                field->encode(L, -1, buff, false);
                lua_pop(L, 1);
            }
            slice* slice = buff->free_place(base, HOLD_OFFSET);
            write_len_prefixed(buff, slice);
        } else {
            for (int i = 1; i <= rawlen; ++i) {
                lua_geti(L, index, i);
                field->encode(L, -1, buff);
                lua_pop(L, 1);
            }
        }
    }

    void encode_message(lua_State* L, int index, luabuf* buff, pb_message* msg) {
        int idx = lua_absindex(L, index);
        lua_pushnil(L);
        bool oneofencode = false;
        while (lua_next(L, idx) != 0) {
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
                        field->encode(L, -1, buff, true, descriptor.encode_default);
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

    void read_field_option(slice* slice, field* f) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&oslice);
            switch (tag) {
                case pb_tag(2, wiretype::VARINT): {
                    f->packed = read_varint<uint32_t>(&oslice);
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
        field f;
        auto fslice = read_len_prefixed(slice);
        while (!fslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&fslice);
            switch (tag) {
                case pb_tag(1, wiretype::LEN): f.name = read_string(&fslice); break;
                case pb_tag(3, wiretype::VARINT): f.number = read_varint<int32_t>(&fslice); break;
                case pb_tag(4, wiretype::VARINT): f.label = read_varint<int32_t>(&fslice); break;
                case pb_tag(5, wiretype::VARINT): f.type = (field_type)read_varint<int32_t>(&fslice); break;
                case pb_tag(6, wiretype::LEN): f.type_name = read_string(&fslice).substr(1); break;
                case pb_tag(9, wiretype::VARINT): f.oneof_index = read_varint<int32_t>(&fslice); break;
                case pb_tag(8, wiretype::LEN): read_field_option(&fslice, &f); break;
                default: skip_field(&fslice, tag); break;
            }
        }
        auto field = new_pbfield(f);
        //Only repeated fields of primitive numeric types (types which use the varint, 32-bit, or 64-bit wire types) can be declared as packed.
        field->packed = (field->wtype != wiretype::LEN) && (f.packed || (f.label == 3 && descriptor.syntax == "proto3"));
        msg->sfields.emplace(field->name.c_str(), field);
        msg->tfields.emplace(field->tag, field);
        msg->fields.emplace(field->number, field);
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

    void read_file_descriptor_set(lua_State* L, slice* slice) {
        descriptor.clean();
        while (!slice->empty()) {
            uint32_t tag = read_varint<uint32_t>(slice);
            switch (tag) {
            case pb_tag(1, wiretype::LEN): read_file_descriptor(slice); break;
            default: skip_field(slice, tag); break;
            }
        }
        for (auto& [_, message] : descriptor.messages) {
            for (auto& [_, field] : message->fields) {
                field->location(L);
            }
        }
        for (auto& [_, message] : descriptor.messages) {
            message->create_metatable(L);
        }
    }

    int pb_clear(lua_State* L) {
        for (auto& [_, ref] : descriptor.field_refs) {
            luaL_unref(L, LUA_REGISTRYINDEX, ref);
        }
        for (auto& [_, message] : descriptor.messages) {
            luaL_unref(L, LUA_REGISTRYINDEX, message->meta_ref);
        }
        descriptor.clean();
        return 0;
    }

    int pb_enums(lua_State* L) {
        vector<string_view> enums;
        for (auto& [name, _] : descriptor.enums) {
            enums.emplace_back(name);
        }
        return luakit::variadic_return(L, enums);
    }

    int pb_messages(lua_State* L) {
        map<string_view, string_view> messages;
        for (auto& [name, message] : descriptor.messages) {
            messages.emplace(name, message->name);
        }
        return luakit::variadic_return(L, messages);
    }

    int pb_fields(lua_State* L, const char* fulname) {
        map<string_view, int> fields;
        auto message = find_message(fulname);
        if (message) {
            for (auto& [name, field] : message->sfields) {
                fields.emplace(name, (int)field->type);
            }
        }
        return luakit::variadic_return(L, fields);
    }
}
