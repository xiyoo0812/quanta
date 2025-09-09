#pragma once
#include <map>
#include <vector>
#include <ranges>
#include <string_view>
#include <unordered_set>

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
    using enum wiretype;

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
    using enum field_type;

    constexpr int pb_tag(uint32_t fieldnum, wiretype wiretype) {
        return (fieldnum << 3) | ((uint8_t)wiretype);
    }

    template<std::unsigned_integral T>
    inline int64_t decode_sint(T val) {
        int64_t mask = static_cast<int64_t>(val & 1) * -1;
        return (val >> 1) ^ mask;
    }

    template<std::integral T>
    inline size_t encode_sint(T val) {
        return (val << 1) ^ -(val < 0);
    }

    template<std::integral T>
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

    template<std::integral T>
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

    inline string_view read_string(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        if (auto data = (const char*)slice->erase(length); data) return string_view(data, length);
        throw length_error("read_string buffer length not engugh");
    }

    inline void write_string(luabuf* buf, string_view value) {
        uint32_t length = value.size();
        write_varint(buf, length);
        buf->push_data((uint8_t*)value.data(), length);
    }

    inline slice read_len_prefixed(slice* slice) {
        uint32_t length = read_varint<uint32_t>(slice);
        if (auto data = slice->erase(length); data) return luakit::slice(data, length);
        throw length_error("read_len_prefixed buffer length not engugh");
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
        auto base = buf->hold_place(offset);
        size_t len = write_varint(buf, length);
        buf->copy(base + len, lslice->head(), length);
        slice* var = buf->free_place(base, offset);
        buf->copy(base, var->head(), len);
        buf->pop_space(length + len);
    }

    inline void skip_field(slice* slice, uint32_t field_tag) {
        switch (auto wire_type = (wiretype)(field_tag & 0x07); wire_type) {
            case VARINT: read_varint<uint64_t>(slice); break;
            case I64: slice->read<int64_t>(); break;
            case I32: slice->read<int32_t>(); break;
            case LEN: read_len_prefixed(slice); break;
            default: throw length_error("skip_field invalid wiretype");
        }
    }

    struct pb_enum {
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

    struct pb_field;
    using pb_field_imap = unordered_map<int32_t, pb_field*>;
    using pb_field_smap = unordered_map<string_view, pb_field*>;
    struct pb_message {
        ~pb_message();
        string name;
        pb_field_imap fields;
        pb_field_imap tfields;
        pb_field_smap sfields;
        vector<string> oneof_decl;
        bool is_map = false;
        int32_t meta_ref = -1;
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
        unordered_map<string, map<string, map<string, string>>> services;
        void clean() {
            for (auto& [_, e] : enums) delete e;
            for (auto& [_, m] : messages) delete m;
            services.clear();
            messages.clear();
            enums.clear();
        }
        ~pb_descriptor() { clean(); }
    };
    thread_local pb_descriptor descriptor;

    inline pb_message* find_message(const char* name) {
        if (auto it = descriptor.messages.find(name); it != descriptor.messages.end()) return it->second;
        return nullptr;
    }

    inline int32_t find_ref(lua_State* L, string& name) {
        if (auto it = descriptor.field_refs.find(name); it != descriptor.field_refs.end()) return it->second;
        lua_pushlstring(L, name.c_str(), name.size());
        int32_t ref = luaL_ref(L, LUA_REGISTRYINDEX);
        descriptor.field_refs.emplace(name, ref);
        return ref;
    }

    inline pb_enum* find_enum(const char* name) {
        if (auto it = descriptor.enums.find(name); it != descriptor.enums.end()) return it->second;
        return nullptr;
    }

    struct pb_field {
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
        bool complex = false;

        pb_field(const field& f, wiretype w) : name(f.name), type_name(f.type_name), number(f.number), label(f.label)
            , wtype(w), type(f.type), oneof_index(f.oneof_index) {
            tag = (number << 3) | (((uint32_t)wtype) & 7);
        }
        virtual ~pb_field() {};

        virtual void push_field(lua_State* L) = 0;
        virtual void decode(lua_State* L, slice* s) = 0;
        virtual void push_default(lua_State* L, int index) = 0;
        virtual void encode(lua_State* L, int idx, luabuf* buff, bool enc_tag = true, bool enc_default = false) = 0;
        inline bool is_repeated() { return label == 3; }
        inline bool is_map() { return message && message->is_map; }
        inline void location(lua_State* L) {
            name_ref = find_ref(L, name);
            if (type == TYPE_MESSAGE && !type_name.empty()) {
                message = find_message(type_name.c_str());
            }
            complex = is_repeated() || is_map();
        }
        inline void check_type(lua_State* L, int i, int t) {
            if (auto vt = lua_type(L, i); vt != t) {
                luaL_error(L, "pb encode field: %s expected %s got %s", name.c_str(), lua_typename(L, t), lua_typename(L, vt));
            }
        }
        inline void check_table(lua_State* L, bool repeated) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
            lua_gettable(L, -2);
            if (lua_isnil(L, -1)) {
                lua_pop(L, 1);
                lua_createtable(L, repeated ? 4 : 0, repeated ? 0 : 4);
                lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
                lua_pushvalue(L, -2);
                lua_settable(L, -4);
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
            lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
        }
        virtual void push_default(lua_State* L, int index) {
            if constexpr (is_pointer_v<T>) return;
            lua_rawgeti(L, LUA_REGISTRYINDEX, name_ref);
            if constexpr (is_integral_v<T>) lua_pushinteger(L, 0);
            else if constexpr (is_floating_point_v<T>) lua_pushnumber(L, 0);
            else if constexpr (is_same_v<T, bool>) lua_pushboolean(L, false);
            else if constexpr (is_same_v<T, string_view>) lua_pushstring(L, "");
            lua_settable(L, -3);
        }
        virtual void decode(lua_State* L, slice* s) {
            if constexpr (FT == TYPE_FLOAT) lua_pushnumber(L, s->read<float>());
            else if constexpr (FT == TYPE_DOUBLE) lua_pushnumber(L, s->read<double>());
            else if constexpr (FT == TYPE_FIXED32) lua_pushinteger(L, s->read<uint32_t>());
            else if constexpr (FT == TYPE_FIXED64) lua_pushinteger(L, s->read<uint64_t>());
            else if constexpr (FT == TYPE_BOOL) lua_pushboolean(L, read_varint<uint32_t>(s));
            // TYPE_INT32在负数的时候，会被扩展位uint64编码，因此使用int64_t去解码
            else if constexpr (FT == TYPE_INT32) lua_pushinteger(L, read_varint<int64_t>(s));
            else if constexpr (FT == TYPE_INT64) lua_pushinteger(L, read_varint<int64_t>(s));
            else if constexpr (FT == TYPE_UINT32) lua_pushinteger(L, read_varint<uint32_t>(s));
            else if constexpr (FT == TYPE_UINT64) lua_pushinteger(L, read_varint<uint64_t>(s));
            else if constexpr (FT == TYPE_SINT32) lua_pushinteger(L, decode_sint(read_varint<uint32_t>(s)));
            else if constexpr (FT == TYPE_SINT64) lua_pushinteger(L, decode_sint(read_varint<uint64_t>(s)));
            else if constexpr (FT == TYPE_SFIXED32) lua_pushinteger(L, s->read<int32_t>());
            else if constexpr (FT == TYPE_SFIXED64) lua_pushinteger(L, s->read<int64_t>());
            else if constexpr (FT == TYPE_ENUM) lua_pushinteger(L, read_varint<uint32_t>(s));
            else if constexpr (FT == TYPE_MESSAGE) {
                auto mslice = read_len_prefixed(s);
                decode_message(L, &mslice, message);
            }
            else if constexpr (FT == TYPE_BYTES || FT == TYPE_STRING) {
                auto str = read_string(s);
                lua_pushlstring(L, str.data(), str.size());
            }
            else throw length_error("decode_field invalid field_type");
        }
        virtual void encode(lua_State* L, int idx, luabuf* buff, bool enc_tag = true, bool enc_default = false) {
            T val = read_field(L, idx, buff);
            if (enc_default || is_not_default(val)) {
                if (enc_tag) write_varint(buff, tag);
                write_field(L, idx, buff, val);
            }
        }
        virtual void check_field(lua_State* L, int idx) {
            if constexpr (is_same_v<T, bool>) check_type(L, idx, LUA_TBOOLEAN);
            else if constexpr (is_arithmetic_v<T>) check_type(L, idx, LUA_TNUMBER);
            else if constexpr (is_same_v<T, string_view>) check_type(L, idx, LUA_TSTRING);
        }
    private:
        inline T read_field(lua_State* L, int idx, luabuf* buff) {
            if constexpr (is_pointer_v<T>) return nullptr;
            check_field(L, idx);
            return lua_to_native<T>(L, idx);
        }
        inline bool is_not_default(T& val) {
            if constexpr (is_integral_v<T>) return val != 0;
            else if constexpr (is_floating_point_v<T>) return val != 0;
            else if constexpr (is_same_v<T, bool>) return val == true;
            else if constexpr (is_same_v<T, string_view>) return val.size() > 0;
            return true;
        }
        inline void write_field(lua_State* L, int idx, luabuf* buff, T& val) {
            if constexpr (FT == TYPE_UINT32) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == TYPE_UINT64) write_varint<uint64_t>(buff, val);
            //int32, int64的负数会被视为 64 位无符号整数，因此使用uint64_t去生成varint
            else if constexpr (FT == TYPE_INT32) write_varint<uint64_t>(buff, val);
            else if constexpr (FT == TYPE_INT64) write_varint<uint64_t>(buff, val);
            else if constexpr (FT == TYPE_STRING) write_string(buff, val);
            else if constexpr (FT == TYPE_BOOL) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == TYPE_BYTES) write_string(buff, val);
            else if constexpr (FT == TYPE_SINT32) write_varint<uint32_t>(buff, encode_sint<int32_t>(val));
            else if constexpr (FT == TYPE_SINT64) write_varint<uint64_t>(buff, encode_sint<int64_t>(val));
            else if constexpr (FT == TYPE_SFIXED32) buff->write<int32_t>(val);
            else if constexpr (FT == TYPE_SFIXED64) buff->write<int64_t>(val);
            else if constexpr (FT == TYPE_ENUM) write_varint<uint32_t>(buff, val);
            else if constexpr (FT == TYPE_FLOAT) buff->write<float>(val);
            else if constexpr (FT == TYPE_DOUBLE) buff->write<double>(val);
            else if constexpr (FT == TYPE_FIXED32) buff->write<uint32_t>(val);
            else if constexpr (FT == TYPE_FIXED64) buff->write<uint64_t>(val);
            else if constexpr (FT == TYPE_MESSAGE) {
                size_t base = buff->hold_place(HOLD_OFFSET);
                encode_message(L, idx, buff, message);
                write_len_prefixed(buff, buff->free_place(base, HOLD_OFFSET));
            }
            else throw lua_exception("encode failed: {} use unsuppert field type!", name.c_str());
        }
    };

    pb_field* new_pbfield(const field& f) {
        switch (f.type) {
        case TYPE_DOUBLE:   return new pb_field_impl<double, TYPE_DOUBLE>(f, I64);
        case TYPE_FLOAT:    return new pb_field_impl<float, TYPE_FLOAT>(f, I32);
        case TYPE_INT64:    return new pb_field_impl<int64_t, TYPE_INT64>(f, VARINT);
        case TYPE_UINT64:   return new pb_field_impl<uint64_t, TYPE_UINT64>(f, VARINT);
        case TYPE_INT32:    return new pb_field_impl<int32_t, TYPE_INT32>(f, VARINT);
        case TYPE_FIXED64:  return new pb_field_impl<int64_t, TYPE_FIXED64>(f, I64);
        case TYPE_FIXED32:  return new pb_field_impl<int32_t, TYPE_FIXED32>(f, I32);
        case TYPE_BOOL:     return new pb_field_impl<bool, TYPE_BOOL>(f, VARINT);
        case TYPE_STRING:   return new pb_field_impl<string_view, TYPE_STRING>(f, LEN);
        case TYPE_GROUP:    return new pb_field_impl<int64_t, TYPE_GROUP>(f, LEN);
        case TYPE_MESSAGE:  return new pb_field_impl<slice*, TYPE_MESSAGE>(f, LEN);
        case TYPE_BYTES:    return new pb_field_impl<string_view, TYPE_BYTES>(f, LEN);
        case TYPE_UINT32:   return new pb_field_impl<uint32_t, TYPE_UINT32>(f, VARINT);
        case TYPE_ENUM:     return new pb_field_impl<uint32_t, TYPE_ENUM>(f, VARINT);
        case TYPE_SFIXED32: return new pb_field_impl<uint32_t, TYPE_SFIXED32>(f, I32);
        case TYPE_SFIXED64: return new pb_field_impl<uint64_t, TYPE_SFIXED64>(f, I64);
        case TYPE_SINT32:   return new pb_field_impl<uint32_t, TYPE_SINT32>(f, VARINT);
        case TYPE_SINT64:   return new pb_field_impl<uint64_t, TYPE_SINT64>(f, VARINT);
        default:            return new pb_field_impl<uint32_t, MAX_TYPE>(f, EGROUP);
        }
    }

    pb_message::~pb_message() {
        for (auto& [_, f] : fields) delete f;
    }

    void pb_message::create_metatable(lua_State* L) {
        lua_createtable(L, 0, 1);
        lua_createtable(L, 0, fields.size());
        for (auto& [name, field] : sfields) {
            if (field->complex) continue;
            field->push_default(L, -3);
        }
        lua_setfield(L, -2, "__index");
        meta_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    inline pb_field* find_field_by_number(pb_message* msg, uint32_t field_num) {
        if (auto it = msg->fields.find(field_num); it != msg->fields.end()) return it->second;
        return nullptr;
    }

    inline pb_field* find_field(pb_message* msg, uint32_t tag) {
        if (auto it = msg->tfields.find(tag); it != msg->tfields.end()) return it->second;
        return nullptr;
    }

    inline pb_field* find_field(pb_message* msg, const char* name) {
        if (auto it = msg->sfields.find(name); it != msg->sfields.end()) return it->second;
        return nullptr;
    }

    void decode_map(lua_State* L, slice* slice, pb_field* field) {
        field->check_table(L, false);
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
        field->check_table(L, true);
        if (field->packed) {
            int len = 1;
            auto rslice = read_len_prefixed(slice);
            while (!rslice.empty()) {
                field->decode(L, &rslice);
                lua_rawseti(L, -2, len++);
            }
        } else {
            int len = lua_rawlen(L, -1);
            field->decode(L, slice);
            lua_rawseti(L, -2, len + 1);
        }
        lua_pop(L, 1);
    }

    void decode_message(lua_State* L, slice* slice, pb_message* msg) {
        unordered_set<uint32_t> tags;
        lua_createtable(L, 0, msg->fields.size());
        while (slice && !slice->empty()) {
            uint32_t tag = read_varint<uint32_t>(slice);
            pb_field* field = find_field(msg, tag);
            tags.emplace(tag);
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
            field->push_field(L);
            field->decode(L, slice);
            //oneof名字引用
            if (field->oneof_index < 0) {
                lua_settable(L, -3);
            } else {
                lua_settable(L, -3);
                field->push_field(L);
                lua_setfield(L, -2, msg->oneof_decl[field->oneof_index].c_str());
            }
        }
        if (descriptor.use_mteatable) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, msg->meta_ref);
            lua_setmetatable(L, -2);
            return;
        }
        for (auto& [tag, field] : msg->tfields | std::views::filter([&tags](const auto& item) {
            return !tags.contains(item.first) && !item.second->complex;
        })) {
            field->push_default(L, -3);
        }
    }

    void encode_map(lua_State* L, luabuf* buff, pb_field* field, int index) {
        field->check_type(L, index, LUA_TTABLE);
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
        field->check_type(L, index, LUA_TTABLE);
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
        int32_t value = 0; string ename;
        auto pslice = read_len_prefixed(slice);
        while (!pslice.empty()) {
            uint32_t tag = read_varint<uint32_t>(&pslice);
            switch (tag) {
                case pb_tag(1, LEN): ename = read_string(&pslice); break;
                case pb_tag(2, VARINT): value = read_varint<int32_t>(&pslice); break;
                default: skip_field(&pslice, tag); break;
            }
        }
        info->kvpair.emplace(ename, value);
        info->vkpair.emplace(value, ename);
    }

    void read_enum(slice* slice, string package) {
        pb_enum* penum = new pb_enum();
        auto eslice = read_len_prefixed(slice);
        while (!eslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&eslice); tag) {
            case pb_tag(1, LEN): package.append(".").append(read_string(&eslice)); break;
                case pb_tag(2, LEN): read_enum_value(&eslice, penum); break;
                default: skip_field(&eslice, tag); break;
            }
        }
        descriptor.enums.emplace(package, penum);
    }

    void read_field_option(slice* slice, field* f) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&oslice); tag) {
                case pb_tag(2, VARINT): {
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
            switch (auto tag = read_varint<uint32_t>(&oslice); tag) {
                case pb_tag(7, VARINT): msg->is_map = read_varint<uint32_t>(&oslice); break;
                default: skip_field(&oslice, tag); break;
            }
        }
    }

    void read_oneof(slice* slice, pb_message* msg) {
        auto oslice = read_len_prefixed(slice);
        while (!oslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&oslice); tag) {
                case pb_tag(1, LEN):msg->oneof_decl.emplace_back(read_string(&oslice)); break;
                default: skip_field(&oslice, tag); break;
            }
        }
    }

    void read_field(slice* slice, pb_message* msg) {
        field f;
        auto fslice = read_len_prefixed(slice);
        while (!fslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&fslice); tag) {
                case pb_tag(1, LEN): f.name = read_string(&fslice); break;
                case pb_tag(3, VARINT): f.number = read_varint<int32_t>(&fslice); break;
                case pb_tag(4, VARINT): f.label = read_varint<int32_t>(&fslice); break;
                case pb_tag(5, VARINT): f.type = (field_type)read_varint<int32_t>(&fslice); break;
                case pb_tag(6, LEN): f.type_name = read_string(&fslice).substr(1); break;
                case pb_tag(9, VARINT): f.oneof_index = read_varint<int32_t>(&fslice); break;
                case pb_tag(8, LEN): read_field_option(&fslice, &f); break;
                default: skip_field(&fslice, tag); break;
            }
        }
        auto field = new_pbfield(f);
        //Only repeated fields of primitive numeric types (types which use the varint, 32-bit, or 64-bit wire types) can be declared as packed.
        field->packed = (field->wtype != LEN) && (f.packed || (f.label == 3 && descriptor.syntax == "proto3"));
        msg->sfields.emplace(field->name.c_str(), field);
        msg->tfields.emplace(field->tag, field);
        msg->fields.emplace(field->number, field);
    }

    void read_message(slice* slice, string package) {
        pb_message* message = new pb_message();
        auto mslice = read_len_prefixed(slice);
        while (!mslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&mslice); tag) {
                case pb_tag(1, LEN): message->name = read_string(&mslice), package += "." + message->name; break;
                case pb_tag(2, LEN): read_field(&mslice, message); break;
                case pb_tag(3, LEN): read_message(&mslice, package); break;
                case pb_tag(4, LEN): read_enum(&mslice, package); break;
                case pb_tag(7, LEN): read_message_option(&mslice, message); break;
                case pb_tag(8, LEN): read_oneof(&mslice, message); break;
                default: skip_field(&mslice, tag); break;
            }
        }
        if (auto nh = descriptor.messages.extract(package); !nh.empty()) {
            delete nh.mapped();
        }
        descriptor.messages.emplace(package, message);
    }
    
    void read_method_option(slice* slice, map<string, string>& method) {
        auto oslice = read_len_prefixed(slice);
        auto taghttp = read_varint<uint32_t>(&oslice);
        auto hslice = read_len_prefixed(&oslice);
        while (!hslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&hslice); tag) {
                case pb_tag(2, LEN): method.emplace("method", "get"); method.emplace("path", read_string(&hslice)); break;
                case pb_tag(3, LEN): method.emplace("method", "put"); method.emplace("path", read_string(&hslice)); break;
                case pb_tag(4, LEN): method.emplace("method", "post"); method.emplace("path", read_string(&hslice)); break;
                case pb_tag(5, LEN): method.emplace("method", "delete"); method.emplace("path", read_string(&hslice)); break;
                case pb_tag(6, LEN): method.emplace("method", "patch"); method.emplace("path", read_string(&hslice)); break;
                case pb_tag(7, LEN): method.emplace("reqbody", read_string(&hslice)); break;
                case pb_tag(12, LEN): method.emplace("resbody", read_string(&hslice)); break;
                default: skip_field(&hslice, tag); break;
            }
        }
    }

    void read_method(slice* slice, map<string, map<string, string>>& service) {
        string name;
        map<string, string> method;
        auto mslice = read_len_prefixed(slice);
        while (!mslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&mslice); tag) {
                case pb_tag(1, LEN): name = read_string(&mslice); break;
                case pb_tag(2, LEN): method["input_type"] = read_string(&mslice).substr(1); break;
                case pb_tag(3, LEN): method["output_type"] = read_string(&mslice).substr(1); break;
                case pb_tag(4, LEN): read_method_option(&mslice, method); break;
                default: skip_field(&mslice, tag); break;
            }
        }
        service.emplace(name, method);
    }

    void read_service(slice* slice, string package) {
        map<string, map<string, string>> service;
        auto sslice = read_len_prefixed(slice);
        while (!sslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&sslice); tag) {
                case pb_tag(1, LEN): package.append(".").append(read_string(&sslice)); break;
                case pb_tag(2, LEN): read_method(&sslice, service); break;
                default: skip_field(&sslice, tag); break;
            }
        }
        descriptor.services.extract(package);
        descriptor.services.emplace(package, service);
    }

    void read_comments(slice* slice, string package) {
    }

    void read_file_descriptor(slice* slice) {
        string package;
        auto fslice = read_len_prefixed(slice);
        while (!fslice.empty()) {
            switch (auto tag = read_varint<uint32_t>(&fslice); tag) {
                case pb_tag(2, LEN): package = read_string(&fslice); break;
                case pb_tag(4, LEN): read_message(&fslice, package); break;
                case pb_tag(5, LEN): read_enum(&fslice, package); break;
                case pb_tag(6, wiretype::LEN): read_service(&fslice, package); break;
                case pb_tag(9, wiretype::LEN): read_comments(&fslice, package); break;
                case pb_tag(12, LEN): descriptor.syntax = read_string(&fslice); break;
                default: skip_field(&fslice, tag); break;
            }
        }
    }

    void read_file_descriptor_set(lua_State* L, slice* slice) {
        while (!slice->empty()) {
            switch (auto tag = read_varint<uint32_t>(slice); tag) {
                case pb_tag(1, LEN): read_file_descriptor(slice); break;
                default: skip_field(slice, tag); break;
            }
        }
        for (auto& [_, message] : descriptor.messages) {
            for (auto& [_, field] : message->fields) {
                field->location(L);
            }
        }
        if (descriptor.use_mteatable) {
            for (auto& [_, message] : descriptor.messages) {
                message->create_metatable(L);
            }
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
        auto view = descriptor.enums | views::transform([](const auto& pair) -> string_view {
            return pair.first;
        });
        return luakit::variadic_return(L, vector<string_view>(view.begin(), view.end()));
    }

    int pb_messages(lua_State* L) {
        auto view = descriptor.messages | views::transform([](const auto& pair) {
            return make_pair<string_view, string_view>(pair.first, pair.second->name);
        });
        return luakit::variadic_return(L, map<string_view, string_view>(view.begin(), view.end()));
    }

    int pb_services(lua_State* L) {
        return luakit::variadic_return(L, descriptor.services);
    }

    int pb_fields(lua_State* L, const char* msg_name) {
        auto message = find_message(msg_name);
        if (message) {
            auto view = message->sfields | views::transform([](const auto& pair) {
                return make_pair(pair.first, static_cast<int>(pair.second->type));
            });
            return luakit::variadic_return(L, map<string_view, int>(view.begin(), view.end()));
        }
        return luakit::variadic_return(L, map<string_view, int>());
    }
}
