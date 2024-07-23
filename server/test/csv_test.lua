--csv_test.lua
--luacheck: ignore 631

local log_dump  = logger.dump

local csvdata = [[
a,b,c,d
1,2,,4
5,6,,8
]]

local xlua = csv.decode(csvdata, 1)
log_dump("lcsv decode csv:{}",  xlua)

local yxml = csv.encode(xlua)
log_dump("lcsv encode csv:{}", yxml)

local ok = csv.save("./bb.csv", xlua)
log_dump("lcsv save csv:{}", ok)

local flua = csv.read("./bb.csv")
log_dump("lcsv read csv:{}", flua)
