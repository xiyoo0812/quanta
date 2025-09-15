--csv_test.lua
--luacheck: ignore 631

require("luacsv")

local log_dump  = logger.dump

local csvdata = [[
a,b,c,d
1,2,,4
5,6,,8
]]

local xlua = csv.decode(csvdata, 1)
log_dump("luacsv decode csv:{}",  xlua)

local yxml = csv.encode(xlua)
log_dump("luacsv encode csv:{}", yxml)

local ok = csv.save("./bb.csv", xlua)
log_dump("luacsv save csv:{}", ok)

local flua = csv.read("./bb.csv")
log_dump("luacsv read csv:{}", flua)
