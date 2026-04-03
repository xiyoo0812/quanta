#define LUA_LIB

#include "lua_kit.h"
#include "pugixml.hpp"

using namespace luakit;
using namespace pugi;

namespace luaxml {

    static void push_elem2lua(lua_State* L, const xml_node& elem) {
        auto childs = elem.children();
        auto attrs = elem.attributes();
        cpchar value = elem.text().as_string(nullptr);
        if (childs.empty() && attrs.empty()) {
            value = value ? value : "";
            if (lua_stringtonumber(L, value) == 0) {
                lua_pushstring(L, value);
            }
            return;
        }
        lua_createtable(L, 0, 4);
        if (value) {
            if (lua_stringtonumber(L, value) == 0) {
                lua_pushstring(L, value);
            }
            lua_setfield(L, -2, "__text");
        }
        if (!attrs.empty()) {
            lua_createtable(L, 0, 4);
            for (auto it = attrs.begin(); it != attrs.end(); ++it) {
                if (lua_stringtonumber(L, it->value()) == 0) {
                    lua_pushstring(L, it->value());
                }
                lua_setfield(L, -2, it->name());
            }
            lua_setfield(L, -2, "__attr");
        }
        if (!childs.empty()) {
            std::unordered_map<std::string, std::vector<xml_node>> elems;
            for (auto child = childs.begin(); child != childs.end(); ++child) {
                if (child->type() != node_element) continue;
                if (auto it = elems.find(child->name()); it != elems.end()) {
                    it->second.push_back(*child);
                } else {
                    elems.insert(std::make_pair(child->name(), std::vector{ *child }));
                }
            }
            for (auto& [key, velem] : elems) {
                if (size_t child_size = velem.size(); child_size == 1) {
                    push_elem2lua(L, velem[0]);
                } else {
                    lua_createtable(L, 0, 4);
                    for (size_t i = 0; i < child_size; ++i) {
                        push_elem2lua(L, velem[i]);
                        lua_seti(L, -2, i + 1);
                    }
                }
                lua_setfield(L, -2, key.c_str());
            }
        }
    }
    static void load_elem4lua(lua_State* L, xml_node& root);
    static void load_table4lua(lua_State* L, xml_node& root) {
        lua_guard g(L);
        if (lua_getfield(L, -1, "__attr") == LUA_TTABLE) {
            lua_pushnil(L);
            while (lua_next(L, -2) != 0) {
                auto attr = root.append_attribute(lua_tostring(L, -2));
                switch (lua_type(L, -1)) {
                case LUA_TSTRING: attr.set_value(lua_tostring(L, -1)); break;
                case LUA_TBOOLEAN: attr.set_value(lua_toboolean(L, -1)); break;
                case LUA_TNUMBER: lua_isinteger(L, -1) ? attr.set_value(lua_tointeger(L, -1)) : attr.set_value(lua_tonumber(L, -1)); break;
                }
                lua_pop(L, 1);
            }
        }
        lua_pushnil(L);
        lua_setfield(L, -3, "__attr");
        switch (lua_getfield(L, -2, "__text")) {
        case LUA_TSTRING: root.text().set(lua_tostring(L, -1)); break;
        case LUA_TBOOLEAN: root.text().set(lua_toboolean(L, -1)); break;
        case LUA_TNUMBER: lua_isinteger(L, -1) ? root.text().set(lua_tointeger(L, -1)) : root.text().set(lua_tonumber(L, -1)); break;
        }
        lua_pushnil(L);
        lua_setfield(L, -4, "__text");
        lua_pushnil(L);
        while (lua_next(L, -4) != 0) {
            load_elem4lua(L, root);
            lua_pop(L, 1);
        }
    }

    static void load_elem4lua(lua_State* L, xml_node& root) {
        cpchar key = lua_tostring(L, -2);
        if (!is_lua_array(L, -1)) {
            auto node = root.append_child(key);
            switch (lua_type(L, -1)) {
            case LUA_TTABLE: load_table4lua(L, node); break;
            case LUA_TSTRING: node.text().set(lua_tostring(L, -1)); break;
            case LUA_TBOOLEAN: node.text().set(lua_toboolean(L, -1)); break;
            case LUA_TNUMBER: lua_isinteger(L, -1) ? node.text().set(lua_tointeger(L, -1)) : node.text().set(lua_tonumber(L, -1)); break;
            }
            return;
        }
        lua_pushstring(L, key);
        int raw_len = lua_rawlen(L, -2);
        for (int i = 1; i <= raw_len; ++i) {
            lua_rawgeti(L, -2, i);
            load_elem4lua(L, root);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
    }

    static int decode_xml(lua_State* L, cpchar xml) {
        xml_document doc;
        if (auto result = doc.load_string(xml); result) {
            lua_createtable(L, 0, 4);
            auto child = doc.first_child();
            push_elem2lua(L, child);
            lua_setfield(L, -2, child.name());
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "parse xml doc failed!");
        return 2;
    }

    static int encode_xml(lua_State* L) {
        xml_document doc;
        std::ostringstream oss;
        //declaration
        xml_node decl = doc.prepend_child(node_declaration);
        decl.append_attribute("version").set_value(luaL_optstring(L, 2, "1.0"));
        decl.append_attribute("encoding").set_value(luaL_optstring(L, 3, "UTF-8"));
        //sava
        lua_pushnil(L);
        while (lua_next(L, 1) != 0) {
            load_elem4lua(L, doc);
            lua_pop(L, 1);
        }
        doc.save(oss);
        std::string xml_str = oss.str();
        lua_pushlstring(L, xml_str.c_str(), xml_str.size());
        return 1;
    }

    static int open_xml(lua_State* L, cpchar xmlfile) {
        xml_document doc;
        if (auto result = doc.load_file(xmlfile); result) {
            lua_createtable(L, 0, 4);
            auto child = doc.first_child();
            push_elem2lua(L, child);
            lua_setfield(L, -2, child.name());
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "parse xml doc failed!");
        return 2;
    }

    static int save_xml(lua_State* L, cpchar xmlfile) {
        xml_document doc;
        //declaration
        xml_node decl = doc.prepend_child(node_declaration);
        decl.append_attribute("version").set_value(luaL_optstring(L, 3, "1.0"));
        decl.append_attribute("encoding").set_value(luaL_optstring(L, 4, "UTF-8"));
        //sava
        lua_pushnil(L);
        while (lua_next(L, 2) != 0) {
            load_elem4lua(L, doc);
            lua_pop(L, 1);
        }
        doc.save_file(xmlfile, "  ", format_default | format_indent | format_write_bom);
        lua_pushboolean(L, true);
        return 1;
    }

    lua_table open_luaxml(lua_State* L) {
        kit_state kit_state(L);
        lua_table lxml = kit_state.new_table("xml");
        lxml.set_function("decode", decode_xml);
        lxml.set_function("encode", encode_xml);
        lxml.set_function("open", open_xml);
        lxml.set_function("save", save_xml);
        return lxml;
    }
}

extern "C" {
    LUALIB_API int luaopen_luaxml(lua_State* L) {
        auto lxml = luaxml::open_luaxml(L);
        return lxml.push_stack();
    }
}
