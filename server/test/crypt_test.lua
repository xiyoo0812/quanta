--log_test.lua
local llog = require("lualog")
local lcrypt = require("lcrypt")

local sformat = string.format

local guid = lcrypt.guid_new(5, 512)
local sguid = lcrypt.guid_tostring(guid)
local nguid = lcrypt.guid_number(sguid)
local s2guid = lcrypt.guid_tostring(nguid)

local nsguid = lcrypt.guid_string(5, 512)
local group = lcrypt.guid_group(guid)
local index = lcrypt.guid_index(guid)
local time = lcrypt.guid_time(guid)
local group2, index2, time2 = lcrypt.guid_source(nguid)

llog.debug(sformat("guid: %s", guid))
llog.debug(sformat("sguid: %s", sguid))
llog.debug(sformat("nguid: %s", nguid))
llog.debug(sformat("s2guid: %s", s2guid))
llog.debug(sformat("ssguid: %s", nsguid))
llog.debug(sformat("group: %s", group))
llog.debug(sformat("index: %s", index))
llog.debug(sformat("time: %s", time))
llog.debug(sformat("group2: %s", group2))
llog.debug(sformat("index2: %s", index2))
llog.debug(sformat("time2: %s", time2))

