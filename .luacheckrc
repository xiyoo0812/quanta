self=false
stds.quanta = {
    globals = {
        --common
        "tonubmer", "lfs", "util", "coroutine",
        "quanta_const", "table_ext", "string_ext", "math_ext",
        "quanta", "environ", "signal", "http", "guid", "luabt", "service", "logger", "utility", "platform",
        "import", "class", "enum", "mixin", "property", "singleton", "super", "implemented", "logfeature", 
        "classof", "is_class", "is_subclass", "instanceof", "conv_class",
        "ncmd_cs"
    }
}
std = "max+quanta"
max_cyclomatic_complexity = 13
max_code_line_length = 160
max_comment_line_length = 160
exclude_files = {
    "script/luabt/*.*",
    "script/luaoop/*.*",
    "script/luabt/luaoop/*.*",
    "script/luabt/LICENSE",
    "script/luaoop/LICENSE",
    "script/luabt/luaoop/LICENSE",
    "extend/lmake/share.lua"
}
include_files = {
    "script/*",
    "server/*",
    "bin/proto/*.lua",
    "tools/encrypt/*",
    "tools/excel2lua/*",
    "extend/lmake/*.lua",
    "extend/lmake/ltemplate/*.lua",
}
ignore = {"212", "213", "512"}

