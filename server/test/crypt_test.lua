--log_test.lua
local lcrypt    = require("lcrypt")

local log_info      = logger.info
local lrandomkey    = lcrypt.randomkey
local lb64encode    = lcrypt.b64_encode
local lb64decode    = lcrypt.b64_decode

--guid
----------------------------------------------------------------
local guid = lcrypt.guid_new(5, 512)
local sguid = lcrypt.guid_tostring(guid)
log_info("newguid-> guid: %s, n2s: %s", guid, sguid)
local nguid = lcrypt.guid_number(sguid)
local s2guid = lcrypt.guid_tostring(nguid)
log_info("convert-> guid: %s, n2s: %s", nguid, s2guid)
local nsguid = lcrypt.guid_string(5, 512)
log_info("newguid: %s", nsguid)
local group = lcrypt.guid_group(nsguid)
local index = lcrypt.guid_index(guid)
local time = lcrypt.guid_time(guid)
log_info("ssource-> group: %s, index: %s, time:%s", group, index, time)
local group2, index2, time2 = lcrypt.guid_source(guid)
log_info("nsource-> group: %s, index: %s, time:%s", group2, index2, time2)

--base64
local ran = lrandomkey();
local nonce = lb64encode(ran)
local dnonce = lb64decode(nonce)
log_info("b64encode-> ran: %s, nonce: %s, dnonce:%s", ran, nonce, dnonce)
