--xlsx_test.lua
local log_debug     = logger.debug

local xlsx = require("luaxlsx")

local excel = xlsx.open("test.xlsx")

local book  = excel.open("Sheet1")
local a1    = book.get_cell_value(1, 1)
local b1    = book.get_cell_value(1, 2)
local a14   = book.get_cell_value(14, 1)
local b14   = book.get_cell_value(14, 2)
local c14   = book.get_cell_value(14, 3)
local c1    = book.get_cell_value(1, 3)

log_debug("get cell a1: {}", a1)
log_debug("get cell b1: {}", b1)
log_debug("get cell c1: {}", c1)
log_debug("get cell a14: {}", a14)
log_debug("get cell b14: {}", b14)
log_debug("get cell c14: {}", c14)

book.set_cell_value(1, 1, "word")
book.set_cell_value(1, 2, 0.5)
book.set_cell_value(14, 1, 0.6)
book.set_cell_value(14, 2, 18880)
book.set_cell_value(14, 3, 0.6)
book.set_cell_value(1, 3, 88)
book.set_cell_value(13, 4, nil)

excel.save("test2.xlsx")