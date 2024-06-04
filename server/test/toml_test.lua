--toml_test.lua
--luacheck: ignore 631

local log_dump  = logger.dump

local ctoml = [[
[animals]
cats = [ "tiger", "lion", "puma" ]
birds = [ "macaw", "pigeon", "canary" ]
fish = [ "salmon", "trout", "carp" ]
]]

local xlua = toml.decode(ctoml)
log_dump("ltoml decode toml:{}",  xlua)

local txml = toml.encode(xlua)
log_dump("ltoml encode toml:{}", txml)

local ok = toml.save("./bb.toml", xlua)
log_dump("ltoml save toml:{}", ok)

local flua = toml.open("./bb.toml")
log_dump("ltoml open toml:{}", flua)
