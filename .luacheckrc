self=false
stds.quanta = {
    globals = {
        --common
        "qtable", "qstring", "qmath", "ncmd_cs",
        "quanta", "environ", "signal", "service", "logger", "logfeature",
        "import", "class", "enum", "mixin", "property", "singleton", "super",
        "implemented", "storage", "classof", "is_class", "conv_class", "class_review",
        "codec", "stdfs", "luabus", "luakit", "json", "protobuf", "timer", "aoi", "log", "worker", 
        "http", "bson", "detour", "ssl", "xml", "zip", "yaml", "toml", "csv", "xlsx", "profile"
    }
}
std = "max+quanta"
max_cyclomatic_complexity = 13
max_code_line_length = 160
max_comment_line_length = 160
exclude_files = {
    "extend/lmake/share.lua",
    "server/robot/accord/page/*"
}
include_files = {
    "script/*.lua",
    "server/*.lua",
    "script/*/*.lua",
    "server/*/*.lua",
    "script/*/*/*.lua",
    "server/*/*/*.lua",
    "script/*/*/*/*.lua",
    "server/*/*/*/*.lua",
    "extend/lmake/*.lua",
    "tools/*/*.lua",
}
ignore = {"212", "213", "512"}

