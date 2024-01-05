--rpnexpr.lua
--luacheck: ignore
local mceil     = math.ceil
local mfloor    = math.floor
local qrand     = qmath.rand
local sgsub     = string.gsub
local tunpack   = table.unpack
local qcount    = qstring.count

local Stack     = import("container/stack.lua")

--操作数类型定义
local OperandType = enum("OperandType", 100,
    "VARIABLE",     -- 变量
    "NUMBER" ,      -- 数字
    "EVALUATE"      -- 评估值
)

--操作符类型定义
local OperatorType = enum("OperatorType", 0,
    "OP_LB",        -- 左括号:(,left bracket
    "OP_RB",        -- 右括号),right bracket
    "OP_NOT",       -- 逻辑非,!,NOT
    "OP_NS",        -- 负号,-,negative sign
    "OP_FLOOR",     -- 向下取整
    "OP_CEIL",      -- 向下取整
    "OP_LEN",       -- 取长度
    "OP_POW",       -- 幂函数, ^
    "OP_MUL",       -- 乘,*,multiplication
    "OP_DIV",       -- 除,/,division
    "OP_MOD",       -- 余,%,modulus
    "OP_ADD",       -- 加,+,Addition
    "OP_SUB",       -- 减,-,subtraction
    "OP_LT",        -- 小于,less than
    "OP_LE",        -- 小于或等于,less than or equal to
    "OP_GT",        -- 大于,>,greater than
    "OP_GE",        -- 大于或等于,>=,greater than or equal to
    "OP_ET",        -- 等于,=,equal to
    "OP_UT",        -- 不等于,unequal to
    "OP_AND",       -- 逻辑与,&,AND
    "OP_OR",        -- 逻辑或,|,OR
    "OP_MIN",       -- 最小值
    "OP_MAX",       -- 最大值
    "OP_IF",        -- ?:
    "OP_RAND",      --随机函数
    "OP_DOU",       --,
    "OP_END",       --@
    "OP_ERR"        --错误符号
)

--操作符关键字表
local OperatorMap = {
    [ "("] = OperatorType.OP_LB,
    [ ")"] = OperatorType.OP_RB,
    [ ","] = OperatorType.OP_DOU,
    [ "@"] = OperatorType.OP_END,
    [ "!"] = OperatorType.OP_NOT,
    [ "^"] = OperatorType.OP_POW,
    [ "*"] = OperatorType.OP_MUL,
    [ "/"] = OperatorType.OP_DIV,
    [ "%"] = OperatorType.OP_MOD,
    [ "<"] = OperatorType.OP_LT,
    [ ">"] = OperatorType.OP_GT,
    [ "<="] = OperatorType.OP_LE,
    [ ">="] = OperatorType.OP_GE,
    [ "<>"] = OperatorType.OP_UT,
    [ "=="] = OperatorType.OP_ET,
    [ "|"] = OperatorType.OP_OR,
    ["OR"] = OperatorType.OP_OR,
    ["IF"] = OperatorType.OP_IF,
    [ "+"] = OperatorType.OP_ADD,
    [ "-"] = OperatorType.OP_SUB,
    [ "&"] = OperatorType.OP_AND,
    ["LEN"] = OperatorType.OP_LEN,
    ["MIN"] = OperatorType.OP_MIN,
    ["MAX"] = OperatorType.OP_MAX,
    ["AND"] = OperatorType.OP_AND,
    ["CEIL"] = OperatorType.OP_CEIL,
    ["INT"] = OperatorType.OP_FLOOR,
    ["FLOOR"] = OperatorType.OP_FLOOR,
    ["RANDBETWEEN"] = OperatorType.OP_RAND,
}

--操作符优先级定义
local PriorityMap = {
    [OperatorType.OP_NOT] = 2,
    [OperatorType.OP_NS] = 2,
    [OperatorType.OP_POW] = 3,
    [OperatorType.OP_MIN] = 3,
    [OperatorType.OP_MAX] = 3,
    [OperatorType.OP_FLOOR] = 3,
    [OperatorType.OP_CEIL] = 3,
    [OperatorType.OP_RAND] = 3,
    [OperatorType.OP_LEN] = 3,
    [OperatorType.OP_MUL] = 4,
    [OperatorType.OP_DIV] = 4,
    [OperatorType.OP_MOD] = 4,
    [OperatorType.OP_ADD] = 5,
    [OperatorType.OP_SUB] = 5,
    [OperatorType.OP_LT] = 6,
    [OperatorType.OP_LE] = 6,
    [OperatorType.OP_GT] = 6,
    [OperatorType.OP_GE] = 6,
    [OperatorType.OP_ET] = 7,
    [OperatorType.OP_UT] = 7,
    [OperatorType.OP_AND] = 8,
    [OperatorType.OP_OR] = 8,
    [OperatorType.OP_IF] = 9,
}

--定位操作符
local function convert_operator(opt, opd)
    if opt ~= "-" then
        return OperatorMap[opt] or OperatorType.OP_ERR
    end
    if opd ~= "" then
        return OperatorType.OP_SUB
    end
    return OperatorType.OP_NS
end

--比较权限
local function compare_priority(opta, optb)
    if PriorityMap[opta] and PriorityMap[optb] then
        return PriorityMap[opta] < PriorityMap[optb]
    end
    return false
end

--查询操作符
local function find_operator(expr)
    for i = 1, #expr do
        for opt in pairs(OperatorMap) do
            local pos = i + #opt - 1
            local chr = expr:sub(i, pos)
            if chr == opt then
                return expr:sub(1, i-1), opt, expr:sub(pos + 1)
            end
        end
    end
end

--是否合法公式
local function is_valid(expr)
    --表达式不能为空
    if expr == "" then
        return false
    end
    --括号必须配对
    if qcount(expr, "(") ~= qcount(expr, ")") then
        return false
    end
    return true
end

--是否操作符
local function is_operator(elem)
    return elem.type < OperandType.VARIABLE
end

--放入操作数堆栈
local function push_operand(operands, cur_opd)
    local value = tonumber(cur_opd)
    if value then
        operands:push({ value = value, type = OperandType.NUMBER })
    else
        operands:push({ value = cur_opd, type = OperandType.VARIABLE })
    end
end

--计算elem的值
local function calc_elem_value(tokens, vt)
    if tokens:empty() then
        return 0
    end
    local elem = tokens:pop()
    if elem.type ~= OperandType.VARIABLE then
        return elem.value
    end
    if vt.calc_value and type(vt.calc_value) == "function" then
        return vt:calc_value(elem.value)
    end
    return vt[elem.value]
end

--公式解析器
----------------------------------------------------------------------
local RpnExpr = singleton()
local prop = property(RpnExpr)
prop:reader("expr_tokens", {})

function RpnExpr:__init()
end

--解析公式
function RpnExpr:parse(expr, attr_id)
    if attr_id then
        local tokens = self.expr_tokens[attr_id]
        if tokens then
            return true, tunpack(tokens)
        end
    end
    --是否合法
    if not is_valid(expr) then
        return false
    end
    --去掉空格
    expr = sgsub(expr, " ", "")
    --添加结束操作符
    expr = expr .. "@"

    local depends ={}
    local tokens = Stack()
    local operands = Stack()        		--操作数堆栈
    local operators = Stack()       		--运算符堆栈
    local cur_opd, cur_opt
    while true do
        cur_opd, cur_opt, expr = find_operator(expr)
        --存储当前操作数到操作数堆栈
        if cur_opd ~= "" then
            push_operand(operands, cur_opd)
        end
        --若当前运算符为结束运算符，则停止循环
        if cur_opt == "@" then
            break
        end
        --若当前运算符为左括号,则直接存入堆栈。
        if cur_opt == "(" then
            operators:push({ value = cur_opt, type = OperatorType.OP_LB })
            goto continue
        end
        if cur_opt == "," then
            while not operators:empty() do
                local elem = operators:top()
                if elem.type == OperatorType.OP_LB then
                    break
                end
                operands:push(elem)
                operators:pop()
            end
            goto continue
        end
        --若当前运算符为右括号,则依次弹出运算符堆栈中的运算符并存入到操作数堆栈,直到遇到左括号为止,此时抛弃该左括号.
        if cur_opt == ")" then
            while not operators:empty() do
                local elem = operators:pop()
                if elem.type == OperatorType.OP_LB then
                    break
                end
                operands:push(elem)
            end
            goto continue
        end
        --调整运算符
        local opt_type = convert_operator(cur_opt, cur_opd)
        if opt_type == OperatorType.OP_ERR then
            break
        end
        --若运算符堆栈为空,或者若运算符堆栈栈顶为左括号,则将当前运算符直接存入运算符堆栈.
        if operators:empty() or operators:top().type == OperatorType.OP_LB then
            operators:push({ value = cur_opt, type = opt_type })
            goto continue
        end
        --若当前运算符优先级大于运算符栈顶的运算符,则将当前运算符直接存入运算符堆栈.
        if compare_priority(opt_type, operators:top().type) then
            operators:push({ value = cur_opt, type = opt_type })
        else
            --若当前运算符若比运算符堆栈栈顶的运算符优先级低或相等，则输出栈顶运算符到操作数堆栈，直至运算符栈栈顶运算符低于（不包括等于）该运算符优先级，
            --或运算符栈栈顶运算符为左括号
            --并将当前运算符压入运算符堆栈。
            while not operators:empty() do
                local elem = operators:top()
                if not compare_priority(opt_type, elem.type) and elem.type ~= OperatorType.OP_LB then
                    operands:push(elem)
                    operators:pop()
                    if operators:empty() then
                        operators:push({ value = cur_opt, type = opt_type })
                        break
                    end
                else
                    operators:push({ value = cur_opt, type = opt_type })
                    break
                end
            end
        end
        :: continue ::
    end
    --转换完成,若运算符堆栈中尚有运算符时,
    --则依序取出运算符到操作数堆栈,直到运算符堆栈为空
    while not operators:empty() do
        operands:push(operators:pop())
    end
    --调整操作数栈中对象的顺序并输出到最终栈
    while not operands:empty() do
        local elem = operands:top()
        --保存表达式依赖的变量列表
        if not is_operator(elem) then
            depends[elem.value] = true
        end
        tokens:push(elem)
        operands:pop()
    end
    if attr_id then
        self.expr_tokens[attr_id] = { tokens, depends }
    end
    return true, tokens, depends
end

--操作符计算方式
local OP_CALC_FUNCS = {
    [OperatorType.OP_POW] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb ^ pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_MUL] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb * pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_DIV] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb / pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_MOD] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb % pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_ADD] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb + pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_SUB] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb - pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_MIN] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = (pa > pb) and pb or pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_MAX] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = (pa > pb) and pa or pb, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_AND] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = (pa and pb) and true or false, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_OR] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = (pa or pb) and true or false, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_FLOOR] = function(opds, vt)
        local vv = calc_elem_value(opds, vt)
        opds:push({ value = mfloor(vv), type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_LEN] = function(opds, vt)
        local vv = calc_elem_value(opds, vt)
        local canlen = (type(vv) == "table" or type(vv) == "string")
        opds:push({ value = (canlen and #vv or 0), type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_CEIL] = function(opds, vt)
        local vv = calc_elem_value(opds, vt)
        opds:push({ value = mceil(vv), type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_NOT] = function(opds, vt)
        local vv = calc_elem_value(opds, vt)
        opds:push({ value = vv and true or false, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_NS] = function(opds, vt)
        local vv = calc_elem_value(opds, vt)
        opds:push({ value = (-1 * vv), type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_IF] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        local pc = calc_elem_value(opds, vt)
        opds:push({ value = pc and pb or pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_LT] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb < pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_LE] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb <= pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_GT] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb > pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_GE] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb >= pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_ET] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb == pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_UT] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = pb ~= pa, type = OperandType.EVALUATE })
    end,
    [OperatorType.OP_RAND] = function(opds, vt)
        local pa = calc_elem_value(opds, vt)
        local pb = calc_elem_value(opds, vt)
        opds:push({ value = qrand(pb, pa), type = OperandType.EVALUATE })
    end
}

--公式求值
function RpnExpr:calculation(vt, prototype)
    --[[
    逆波兰表达式求值算法：
    1、循环扫描语法单元的项目。
    2、如果扫描的项目是操作数，则将其压入操作数堆栈，并扫描下一个项目。
    3、如果扫描的项目是一个二元运算符，则对栈的顶上两个操作数执行该运算。
    4、如果扫描的项目是一个一元运算符，则对栈的最顶上操作数执行该运算。
    5、将运算结果重新压入堆栈。
    6、重复步骤2-5，堆栈中即为结果值。
    ]]
    if prototype:empty() then
        return 0
    end
    local value = 0
    local opds = Stack()
    local tokens = prototype:clone()
    while not tokens:empty() do
        local elem = tokens:pop()
        if not is_operator(elem) then
            --如果为操作数则压入操作数堆栈
            opds:push(elem)
            goto continue
        end
        local handler = OP_CALC_FUNCS[elem.type]
        if handler then
            handler(opds, vt)
        end
        :: continue ::
    end
    if opds:size() == 1 then
        value = calc_elem_value(opds, vt)
    end
    return value
end

quanta.rpnexpr = RpnExpr()
--[[
local log_debug = logger.debug

local VT = {
    calc_value = function(self, key)
        return self[key]
    end
}

local p = quanta.rpnexpr
local function test(xxx, vt)
    setmetatable(vt, {__index = VT})
    local ok, tokens, depends = p:parse(xxx)
    if ok then
        log_debug("============depends: {}: ", depends)
        local args = {}
        for _, d in pairs(tokens.datas) do
            args[#args+1] = tostring(d.value)
        end
        log_debug("============>: {}: ", table.concat(args, " "))
        local val = p:calculation(vt, tokens)
        log_debug("============calculation: {}: ", val)
    end
end
local obj = { lvl = 10 }
local obj2 = { a = 10, b=2 }
test("IF(lvl<1,1,IF(lvl>100,100,lvl))", obj)
test("-a+(b+-3)*(4%3)", obj2)
]]

return RpnExpr
