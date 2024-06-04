--yaml_test.lua
--luacheck: ignore 631

local log_dump  = logger.dump

local cxml = [[
base: &base
  name: Everyone has same name
  id: 123456

foo: &foo
  <<: *base
  age: 10

bar: &bar
  <<: *base
  age: 20

]]

local xlua = yaml.decode(cxml)
log_dump("lyaml decode yaml:{}",  xlua)
local yxml = yaml.encode(xlua)
log_dump("lyaml encode yaml:{}", yxml)

local ok = yaml.save("./bb.yaml", xlua)
log_dump("lyaml save yaml:{}", ok)
local flua = yaml.open("./bb.yaml")
log_dump("lyaml open yaml:{}", flua)
