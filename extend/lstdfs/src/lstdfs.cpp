#define LUA_LIB

#include <chrono>
#include "lua_kit.h"

using namespace std;
using namespace luakit;
using namespace std::chrono;
using namespace std::filesystem;
using fspath = std::filesystem::path;

namespace lstdfs {
    struct file_info {
        fspath name;
        string type;
    };
    using path_vector = vector<string>;
    using file_vector = vector<file_info*>;

    fspath lstdfs_absolute(fspath path) {
        return absolute(path);
    }

    fspath lstdfs_current_path() {
        return current_path();
    }

    fspath lstdfs_temp_dir() {
        return temp_directory_path();
    }

    int lstdfs_chdir(lua_State* L, fspath path) {
        try {
            current_path(path);
            return variadic_return(L, true);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    int lstdfs_mkdir(lua_State* L, fspath path) {
        try {
            bool res = create_directories(path);
            return variadic_return(L, res);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    int lstdfs_remove(lua_State* L, fspath path, bool rmall) {
        try {
            if (rmall) {
                auto size = remove_all(path);
                return variadic_return(L, size > 0);
            }
            bool res = remove(path);
            return variadic_return(L, res);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    int lstdfs_remove_file(lua_State* L, fspath path) {
        try {
            bool res = remove(path);
            return variadic_return(L, res);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    int lstdfs_copy(lua_State* L, fspath from, fspath to, copy_options option) {
        try {
            filesystem::copy(from, to, option);
            return variadic_return(L, true);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }
    int lstdfs_copy_file(lua_State* L, fspath from, fspath to, copy_options option) {
        try {
            copy_file(from, to, option);
            return variadic_return(L, true);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    int lstdfs_rename(lua_State* L, fspath pold, fspath pnew) {
        try {
            rename(pold, pnew);
            return variadic_return(L, true);
        } catch (exception const& e) {
            return variadic_return(L, false, e.what());
        }
    }

    bool lstdfs_exists(fspath path) {
        return exists(path);
    }

    fspath lstdfs_root_name(fspath path) {
        return path.root_name();
    }

    fspath lstdfs_filename(fspath path) {
        return path.filename();
    }

    fspath lstdfs_extension(fspath path) {
        return path.extension();
    }

    fspath lstdfs_root_path(fspath path) {
        return path.root_path();
    }

    fspath lstdfs_parent_path(fspath path) {
        return path.parent_path();
    }

    fspath lstdfs_relative_path(fspath path) {
        return path.relative_path();
    }

    fspath lstdfs_relative(fspath path, fspath base) {
        return relative(path, base);
    }

    fspath lstdfs_append(fspath path, string_view append_path) {
        return path.append(append_path);
    }

    fspath lstdfs_concat(fspath path, string_view concat_path) {
        return path.concat(concat_path);
    }

    fspath lstdfs_remove_filename(fspath path) {
        return path.remove_filename();
    }

    fspath lstdfs_replace_filename(fspath path, fspath filename) {
        return path.replace_filename(filename);
    }

    fspath lstdfs_replace_extension(fspath path, fspath extens) {
        return path.replace_extension(extens);
    }

    fspath lstdfs_make_preferred(fspath path) {
        return path.make_preferred();
    }

    size_t lstdfs_file_size(fspath path) {
        return file_size(path);
    }

    fspath lstdfs_stem(fspath path) {
        return path.stem();
    }

    bool lstdfs_is_directory(fspath path) {
        return is_directory(path);
    }

    bool lstdfs_is_absolute(fspath path) {
        return path.is_absolute();
    }

    int lstdfs_last_write_time(lua_State* L, fspath path) {
        try {
            auto ftime = last_write_time(path);
            auto sctp = time_point_cast<system_clock::duration>(ftime - file_time_type::clock::now() + system_clock::now());
            time_t cftime = system_clock::to_time_t(sctp);
            return variadic_return(L, cftime);
        } catch (exception const& e) {
            return variadic_return(L, 0, e.what());
        }
    }

    string get_file_type(fspath path) {
        switch (auto s = status(path); s.type()) {
        case file_type::none: return "none";
        case file_type::not_found: return "not_found";
        case file_type::regular: return "regular";
        case file_type::directory: return "directory";
        case file_type::symlink: return "symlink";
        case file_type::block: return "block";
        case file_type::character: return "character";
        case file_type::fifo: return "fifo";
        case file_type::socket: return "socket";
        case file_type::unknown: return "unknown";
        default: return "implementation-defined";
        }
    }

    string lstdfs_filetype(fspath path) {
        return get_file_type(path);
    }

    int lstdfs_dir(lua_State* L, fspath path, bool recursive) {
        try {
            file_vector files;
            if (recursive) {
                for (auto entry : recursive_directory_iterator(path)) {
                    files.push_back(new file_info({ entry.path(), get_file_type(entry.path())}));
                }
                return variadic_return(L, files);
            }
            for (auto entry : directory_iterator(path)) {
                files.push_back(new file_info({ entry.path(), get_file_type(entry.path()) }));
            }
            return variadic_return(L, files);
        } catch (exception const& e) {
            return variadic_return(L, nullptr, e.what());
        }
    }

    path_vector lstdfs_split(fspath path) {
        path_vector values;
        for (auto it = path.begin(); it != path.end(); ++it) {
            values.push_back((*it).string());
        }
        return values;
    }

    int lstdfs_cleanbytime(lua_State* L, fspath path, fspath ext, uint64_t time) {
        try {
            uint32_t count = 0;
            for (auto entry : recursive_directory_iterator(path)) {
                if (entry.is_directory() || entry.path().extension() != ext) continue;
                if (entry.path().stem().has_extension()) {
                    auto ftime = last_write_time(entry.path());
                    if ((size_t)duration_cast<seconds>(file_time_type::clock::now() - ftime).count() > time) {
                        remove(entry.path());
                        count++;
                    }
                }
            }
            return variadic_return(L, count);
        }
        catch (exception const& e) {
            return variadic_return(L, nullptr, e.what());
        }
    }

    lua_table open_lstdfs(lua_State* L) {
        kit_state kit_state(L);
        kit_state.new_class<file_info>("name", &file_info::name, "type", &file_info::type);
        auto lstdfs = kit_state.new_table("stdfs");
        lstdfs.new_enum("copy_options",
            "none", copy_options::none,
            "recursive", copy_options::recursive,
            "copy_symlinks", copy_options::copy_symlinks,
            "skip_symlinks", copy_options::skip_symlinks,
            "skip_existing", copy_options::skip_existing,
            "update_existing", copy_options::update_existing,
            "create_symlinks", copy_options::create_symlinks,
            "directories_only", copy_options::directories_only,
            "create_hard_links", copy_options::create_hard_links,
            "overwrite_existing", copy_options::overwrite_existing
        );
        lstdfs.set_function("dir", lstdfs_dir);
        lstdfs.set_function("stem", lstdfs_stem);
        lstdfs.set_function("copy", lstdfs_copy);
        lstdfs.set_function("mkdir", lstdfs_mkdir);
        lstdfs.set_function("chdir", lstdfs_chdir);
        lstdfs.set_function("split", lstdfs_split);
        lstdfs.set_function("rename", lstdfs_rename);
        lstdfs.set_function("exists", lstdfs_exists);
        lstdfs.set_function("remove", lstdfs_remove);
        lstdfs.set_function("append", lstdfs_append);
        lstdfs.set_function("concat", lstdfs_concat);
        lstdfs.set_function("temp_dir", lstdfs_temp_dir);
        lstdfs.set_function("absolute", lstdfs_absolute);
        lstdfs.set_function("relative", lstdfs_relative);
        lstdfs.set_function("filetype", lstdfs_filetype);
        lstdfs.set_function("filename", lstdfs_filename);
        lstdfs.set_function("copy_file", lstdfs_copy_file);
        lstdfs.set_function("file_size", lstdfs_file_size);
        lstdfs.set_function("extension", lstdfs_extension);
        lstdfs.set_function("root_name", lstdfs_root_name);
        lstdfs.set_function("root_path", lstdfs_root_path);
        lstdfs.set_function("cleanbytime", lstdfs_cleanbytime);
        lstdfs.set_function("parent_path", lstdfs_parent_path);
        lstdfs.set_function("remove_file", lstdfs_remove_file);
        lstdfs.set_function("is_absolute", lstdfs_is_absolute);
        lstdfs.set_function("is_directory", lstdfs_is_directory);
        lstdfs.set_function("current_path", lstdfs_current_path);
        lstdfs.set_function("relative_path", lstdfs_relative_path);
        lstdfs.set_function("make_preferred", lstdfs_make_preferred);
        lstdfs.set_function("last_write_time", lstdfs_last_write_time);
        lstdfs.set_function("remove_filename", lstdfs_remove_filename);
        lstdfs.set_function("replace_filename", lstdfs_replace_filename);
        lstdfs.set_function("replace_extension", lstdfs_replace_extension);
        return lstdfs;
    }
}

extern "C" {
    LUALIB_API int luaopen_lstdfs(lua_State* L) {
        auto lstdfs = lstdfs::open_lstdfs(L);
        return lstdfs.push_stack();
    }
}
