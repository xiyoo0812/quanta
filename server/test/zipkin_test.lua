-- zipkin_test.lua
import("driver/zipkin.lua")

local zipkin        = quanta.get("zipkin")

local function zipkin_func4(span)
    local key4 = 44
    local nspan = zipkin:sub_span("zipkin_func4", span.id)
    zipkin:set_tag(nspan, "key4", key4)
    zipkin:set_annotation(nspan, "call zipkin_func4!")
    zipkin:finish_span(nspan)
end

local function zipkin_func3(span)
    local key3 = 33
    local nspan = zipkin:sub_span("zipkin_func3", span.id)
    zipkin:set_tag(nspan, "key3", key3)
    zipkin:set_annotation(nspan, "call zipkin_func3!")
    zipkin_func4(nspan)
end

local function zipkin_func2(span)
    local key2 = 22
    local nspan = zipkin:sub_span("zipkin_func2", span.id)
    zipkin:set_tag(nspan, "key2", key2)
    zipkin:set_annotation(nspan, "call zipkin_func2!")
    zipkin_func3(nspan)
end

local function zipkin_func1()
    local key1 = 11
    local span = zipkin:new_span("zipkin_func1")
    zipkin:set_tag(span, "key1", key1)
    zipkin:set_annotation(span, "call zipkin_func1!")
    zipkin_func2(span)
end

zipkin_func1()
