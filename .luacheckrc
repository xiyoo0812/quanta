self=false
stds.quanta = {
    globals = {
        --common
        "coroutine", "qtable", "qstring", "qmath", "ncmd_cs",
        "quanta", "environ", "signal", "luabt", "service", "logger",
        "import", "class", "enum", "mixin", "property", "singleton", "super", "implemented",
        "logfeature", "db_property", "classof", "is_class", "is_subclass", "instanceof", "conv_class",
        "codec", "crypt", "stdfs", "luabus", "luakit", "json", "protobuf", "curl", "timer", "aoi", "log", "worker", "http", "bson", "detour"
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
    "server/robot/accord/page/*",
    "extend/lmake/share.lua"
}
include_files = {
    "script/*",
    "server/*",
    "worker/*",
    "bin/proto/*.lua",
    "tools/encrypt/*",
    "tools/excel2lua/*",
    "extend/lmake/*.lua",
    "extend/lmake/ltemplate/*.lua",
}
ignore = {"212", "213", "512"}

