-- sqlite_test.lua
local sqlite        = require("lsqlite")

local sformat       = string.format
local log_debug     = logger.debug
local jsoncodec     = json.jsoncodec

local driver = sqlite.create()
local jcodec = jsoncodec()

driver.set_codec(jcodec)
driver.open("./sqlite/xxx.db")

local c, ce = driver.exec("CREATE TABLE PLAYER (KEY INT PRIMARY KEY NOT NULL, VALUE BLOB);")
log_debug("CREATE: {}:{}", c, ce)

local i, ie = driver.exec("INSERT INTO PLAYER (KEY, VALUE) VALUES (1, 'Paul1');")
log_debug("INSERT: {}:{}", i, ie)
i, ie = driver.exec("INSERT INTO PLAYER (KEY, VALUE) VALUES (2, 'Paul2');")
log_debug("INSERT: {}:{}", i, ie)
i, ie = driver.exec("INSERT INTO PLAYER (KEY, VALUE) VALUES (3, 'Paul3');")
log_debug("INSERT: {}:{}", i, ie)
i, ie = driver.exec("INSERT INTO PLAYER (KEY, VALUE) VALUES (3, 'Paul33');")
log_debug("INSERT: {}:{}", i, ie)

for j = 1, 6 do
    local rc, roe = driver.find(sformat("SELECT * FROM PLAYER WHERE KEY = '%s'", j))
    log_debug("SELECT1-{}: {}-{}", j, rc, roe)
end

local r, re = driver.exec("REPLACE INTO PLAYER (KEY, VALUE) VALUES (3, 'Paul33');")
log_debug("REPLACE: {}:{}", r, re)
r, re = driver.exec("REPLACE INTO PLAYER (KEY, VALUE) VALUES (4, 'Paul4');")
log_debug("REPLACE: {}:{}", r, re)
local u, ue = driver.exec("UPDATE PLAYER set VALUE ='Paul222' where KEY=2")
log_debug("UPDATE: {}:{}", u, ue)
u, ue = driver.exec("UPDATE PLAYER set VALUE ='Paul222' where KEY=5")
log_debug("UPDATE: {}:{}", u, ue)
local d, de = driver.exec("DELETE FROM PLAYER where KEY=1")
log_debug("DELETE: {}:{}", d, de)
d, de = driver.exec("DELETE FROM PLAYER where KEY=5")
log_debug("DELETE: {}:{}", d, de)

for j = 1, 6 do
    local rc, roe = driver.find(sformat("SELECT * FROM PLAYER WHERE KEY = %s", j))
    log_debug("SELECT2-{}: {}-{}", j, rc, roe)
end

local dd, dde = driver.exec("DROP TABLE PLAYER")
log_debug("DROP: {}:{}", dd, dde)

--stmt
local scc, st_create = driver.prepare("CREATE TABLE PLAYER (KEY INT PRIMARY KEY NOT NULL, VALUE BLOB);")
log_debug("prepare CREATE: {}:{}", scc, st_create)
local sc, sce = st_create.exec()
log_debug("SCREATE: {}:{}", sc, sce)

local sic, st_insert = driver.prepare("INSERT INTO PLAYER (KEY, VALUE) VALUES (?, ?);")
log_debug("prepare INSERT: {}:{}", sic, st_insert)
local src, st_replace = driver.prepare("REPLACE INTO PLAYER (KEY, VALUE) VALUES (?, ?);")
log_debug("prepare REPLACE: {}:{}", src, st_replace)
local suc, st_update = driver.prepare("UPDATE PLAYER set VALUE = ? where KEY=?")
log_debug("prepare UPDATE: {}:{}", suc, st_update)
local ssc, st_select = driver.prepare("SELECT * FROM PLAYER WHERE KEY = ?")
log_debug("prepare SELECT: {}:{}", ssc, st_select)
local sdc, st_delete = driver.prepare("DELETE FROM PLAYER where KEY=?")
log_debug("prepare DELETE: {}:{}", sdc, st_delete)

for j = 1, 3 do
    st_insert.bind(1, j)
    st_insert.bind(2, "aaa" .. j)
    local cc, cce = st_insert.exec()
    log_debug("st_insert: {} => {}:{}", j, cc, cce)
end
st_insert.bind(1, 3)
st_insert.bind(2, "aaa4")
local icc, icce = st_insert.exec()
log_debug("st_insert: 3 => {}:{}", icc, icce)

for j = 4, 5 do
    local cc, cce = st_insert.run(j, {value = j})
    log_debug("st_insert: {} => {}:{}", j, cc, cce)
end

st_select.bind(1, 4)
local secc, item = st_select.exec()
log_debug("st_select: => {}:{}", secc, item)
local secc2, item2 = st_select.run(5)
log_debug("st_select: => {}:{}", secc2, item2)
