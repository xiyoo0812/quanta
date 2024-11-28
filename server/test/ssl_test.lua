--ssl_test.lua

local log_info      = logger.info
local lmd5          = ssl.md5
local lrandomkey    = ssl.randomkey
local lb64encode    = ssl.b64_encode
local lb64decode    = ssl.b64_decode
local lhex_encode   = ssl.hex_encode

local lsha1         = ssl.sha1
local lsha256       = ssl.sha256
local lsha512       = ssl.sha512

local lhmac_sha1    = ssl.hmac_sha1
local lhmac_sha256  = ssl.hmac_sha256
local lhmac_sha512  = ssl.hmac_sha512

--base64
local ran = lrandomkey()
log_info("lrandomkey-> ran: {}", lhex_encode(ran))
local text = "aTmEiujIXS9aezbfaADYGd5fFr2ExUPvw9t0Pijxjw8WMCQQDDsGLBH4RTQwPe"
local nonce = lb64encode(text)
local dnonce = lb64decode(nonce)
log_info("b64encode-> nonce: {}, dnonce:{}", lhex_encode(nonce), dnonce)

--sha
local value = "123456779"
local sha1 = lhex_encode(lsha1(value))
log_info("sha1: {}", sha1)
local sha256 = lhex_encode(lsha256(value))
log_info("sha256: {}", sha256)
local sha512 = lhex_encode(lsha512(value))
log_info("sha512: {}", sha512)

--md5
local omd5 = lmd5(value)
local nmd5 = lmd5(value, 1)
local hmd5 = lhex_encode(omd5)
log_info("md5: {}", nmd5)
log_info("omd5: {}, hmd5: {}", omd5, hmd5)

--hmac_sha
local key = "1235456"
local hmac_sha1 = lhex_encode(lhmac_sha1(key, value))
log_info("hmac_sha1: {}", hmac_sha1)
local hmac_sha256 = lhex_encode(lhmac_sha256(key, value))
log_info("hmac_sha256: {}", hmac_sha256)
local hmac_sha512 = lhex_encode(lhmac_sha512(key, value))
log_info("hmac_sha512: {}", hmac_sha512)

--rsa
local pem_pub = [[
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCWKUc5BTsvNKLv389mqShFhg7l
HbG8SyyAiHZ5gMMMoBGayBGgOCGXHDRDUabr0E8xFtSApu9Ppuj3frzwRDcj4Q69
yXc/x1+a18Jt96DI/DJEkmkmo/Mr+pmY4mVFk4a7pxnXpynBUz7E7vp9/XvMs84L
DFqqvGiSmW/YKJfsAQIDAQAB
]]

local pem_pri = [[
MIICWwIBAAKBgQCWKUc5BTsvNKLv389mqShFhg7lHbG8SyyAiHZ5gMMMoBGayBGg
OCGXHDRDUabr0E8xFtSApu9Ppuj3frzwRDcj4Q69yXc/x1+a18Jt96DI/DJEkmkm
o/Mr+pmY4mVFk4a7pxnXpynBUz7E7vp9/XvMs84LDFqqvGiSmW/YKJfsAQIDAQAB
AoGANhfDnPJZ+izbf07gH0rTg4wB5J5YTwzDiL/f8fAlE3C8NsZYtx9RVmamGxQY
bf158aSYQ4ofTlHBvZptxJ3GQLzJQd2K15UBzBe67y2umN7oP3QD+nUhw83PnD/R
A+aTmEiujIXS9aezbfaADYGd5fFr2ExUPvw9t0Pijxjw8WMCQQDDsGLBH4RTQwPe
koVHia72LF7iQPP75AaOZIuhCTffaLsimA2icO+8/XT2yaeyiXqHn1Wzyk1ZrGgy
MTeTu9jPAkEAxHDPRxNpPUhWQ6IdPWflecKpzT7fPcNJDyd6/Mg3MghWjuWc1xTl
nmBDdlQGOvKsOY4K4ihDZjVMhBnqp16CLwJAOvaT2wMHGRtxOAhIFnUa/dwCvwO5
QGXFv/P1ypD/f9aLxHGycga7heOM8atzVy1reR/+b8z+H43+W1lPGLmaKwJAJ2zA
nPIvX+ZBsec6WRWd/5bq/09L/JhR9GGnFE6WjUsRHDLHDH+cKfIF+Bya93+2wwJX
+tW72Sp/Rc/xwU99bwJAfUw9Nfv8llVA2ZCHkHGNc70BjTyaT/TxLV6jcouDYMTW
RfSHi27F/Ew6pENe4AwY2sfEV2TXrwEdrvfjNWFSPw==
]]

local pubkey = ssl.rsa_init_pubkey(pem_pub)
local prikey = ssl.rsa_init_prikey(pem_pri)
log_info("rsa_init: {}, {}",  pubkey, prikey)

local rsav1 = pubkey.pub_encode(pem_pri)
log_info("rsa_pencode: {}, {}",  #rsav1, lhex_encode(rsav1))
local rsav2 = prikey.pri_decode(rsav1)
log_info("rsa_sdecode: {}, {}",  #rsav2, rsav2)
local rsav3 = prikey.pri_encode(pem_pri)
log_info("rsa_sencode: {}, {}",  #rsav3, lhex_encode(rsav3))
local rsav4 = pubkey.pub_decode(rsav3)
log_info("rsa_pdecode: {}, {}",  #rsav4, rsav4)

local data = {}
for i = 1, 200 do
    data[i] = {
        index = i,
        name = "name"..i,
        age = i,
        sex = i % 2 == 0 and "male" or "female"
    }
end

local j1 = timer.now_ns()
local jdata = json.encode(data)
log_info("data: {}=>{}",  #jdata, timer.now_ns() - j1)

local t1 = timer.now_ms()
local zstdc = ssl.zstd_encode(jdata)
for i = 1, 20000 do
    ssl.zstd_encode(jdata)
end
log_info("zstd_encode: {}=>{}",  #zstdc, timer.now_ms() - t1)
local t2 = timer.now_ms()
local zstdd = ssl.zstd_decode(zstdc)
for i = 1, 20000 do
    ssl.zstd_decode(zstdc)
end
log_info("zstd_decode: {}=>{}",  #zstdd, timer.now_ms() - t2)

local s1 = timer.now_ms()
local lz4c = ssl.lz4_encode(jdata)
for i = 1, 20000 do
    ssl.lz4_encode(jdata)
end
log_info("lz4_encode: {}=>{}",  #lz4c, timer.now_ms() - s1)
local s2 = timer.now_ms()
local lz4d = ssl.lz4_decode(lz4c)
for i = 1, 20000 do
    ssl.lz4_decode(lz4c)
end
log_info("lz4_decode: {}=>{}",  #lz4d, timer.now_ms() - s2)
