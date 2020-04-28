self=false
stds.quanta = {
    globals = {
        --common
        "tonubmer", "lfs", "util", "coroutine",
        "quanta_const", "table_ext", "string_ext", "math_ext",
        "quanta", "environ", "signal", "http", "guid", "luabt", "service", "logger", "utility", "platform",
        "import", "class", "interface", "property", "singleton", "super", "implemented", "classof", "is_class", "is_subclass", "instanceof", "conv_class",
    }
}
std = "max+quanta"
max_cyclomatic_complexity = 12
max_code_line_length = 160
max_comment_line_length = 160
include_files = {
    "bin/lua/*",
    "bin/proto/*.lua",
}
ignore = {"212", "213", "512"}

