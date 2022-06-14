--serialize.lua

local lbuffer   = require("lbuffer")
local serializer= lbuffer.new_serializer()

function quanta.encode(...)
    return serializer.encode(...)
end

function quanta.decode(slice)
    return serializer.decode(slice)
end

function quanta.encode_string(...)
    return serializer.encode_string(...)
end

function quanta.decode_string(data, len)
    return serializer.decode_string(data, len)
end

function quanta.serialize(tab, line)
    return serializer.serialize(tab, line)
end

function quanta.unserialize(str)
    return serializer.unserialize(str)
end
