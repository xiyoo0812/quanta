print("hello luatuo file!")
print(test_value)

for k, v in pairs(testtb) do
    print("testtb", k, v)
end

for k, v in pairs(LOG_LEVEL) do
    print("LOG_LEVEL", k, v)
end

print("test_lua_func", test_lua_func(3, 4))

ltest.fn1()
print(ltest.a, ltest.b)
print(ltest.fn2(6))
print(ltest.b)

test_value = 222
test_func(22)

print(test_func2(333))

print(testtb.tbf(444))

for k, v in pairs(lvec) do
    print("lvec", k, v)
end

for k, v in pairs(lmap) do
    print("lmap", k, v)
end

lvec2 = { 4, 5, 6}

function lua_gcall(a, b, c)
	print("exec lua global func", a, b, c)
	return a + b
end

function testtb.lua_tcall(a, b, c)
	print("exec lua table func", a, b, c)
	return a, b
end
