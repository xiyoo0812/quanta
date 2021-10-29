--crypt_test.lua
local lcrypt    = require("lcrypt")

local log_info      = logger.info
local lmd5          = lcrypt.md5
local lrandomkey    = lcrypt.randomkey
local lb64encode    = lcrypt.b64_encode
local lb64decode    = lcrypt.b64_decode
local lhex_encode   = lcrypt.hex_encode

local lsha1         = lcrypt.sha1
local lsha224       = lcrypt.sha224
local lsha256       = lcrypt.sha256
local lsha384       = lcrypt.sha384
local lsha512       = lcrypt.sha512

local lhmac_sha1    = lcrypt.hmac_sha1
local lhmac_sha224  = lcrypt.hmac_sha224
local lhmac_sha256  = lcrypt.hmac_sha256
local lhmac_sha384  = lcrypt.hmac_sha384
local lhmac_sha512  = lcrypt.hmac_sha512

--guid
----------------------------------------------------------------
local guid = lcrypt.guid_new(5, 512)
local sguid = lcrypt.guid_tostring(guid)
log_info("newguid-> guid: %s, n2s: %s", guid, sguid)
local nguid = lcrypt.guid_number(sguid)
local s2guid = lcrypt.guid_tostring(nguid)
log_info("convert-> guid: %s, n2s: %s", nguid, s2guid)
local nsguid = lcrypt.guid_string(5, 512)
log_info("newguid: %s", nsguid)
local group = lcrypt.guid_group(nsguid)
local index = lcrypt.guid_index(guid)
local time = lcrypt.guid_time(guid)
log_info("ssource-> group: %s, index: %s, time:%s", group, index, time)
local group2, index2, time2 = lcrypt.guid_source(guid)
log_info("nsource-> group: %s, index: %s, time:%s", group2, index2, time2)

--base64
local ran = lrandomkey()
local nonce = lb64encode(ran)
local dnonce = lb64decode(nonce)
log_info("b64encode-> ran: %s, nonce: %s, dnonce:%s", lhex_encode(ran), lhex_encode(nonce), lhex_encode(dnonce))

--sha
local value = "123456779"
local sha1 = lhex_encode(lsha1(value))
log_info("sha1: %s", sha1)
local sha224 = lhex_encode(lsha224(value))
log_info("sha224: %s", sha224)
local sha256 = lhex_encode(lsha256(value))
log_info("sha256: %s", sha256)
local sha384 = lhex_encode(lsha384(value))
log_info("sha384: %s", sha384)
local sha512 = lhex_encode(lsha512(value))
log_info("sha512: %s", sha512)

--md5
local md5 = lhex_encode(lmd5(value))
log_info("md5: %s", md5)


--hmac_sha
local key = "1235456"
local hmac_sha1 = lhex_encode(lhmac_sha1(key, value))
log_info("hmac_sha1: %s", hmac_sha1)
local hmac_sha224 = lhex_encode(lhmac_sha224(key, value))
log_info("hmac_sha224: %s", hmac_sha224)
local hmac_sha256 = lhex_encode(lhmac_sha256(key, value))
log_info("hmac_sha256: %s", hmac_sha256)
local hmac_sha384 = lhex_encode(lhmac_sha384(key, value))
log_info("hmac_sha384: %s", hmac_sha384)
local hmac_sha512 = lhex_encode(lhmac_sha512(key, value))
log_info("hmac_sha512: %s", hmac_sha512)

--hash
local hash_n1 = quanta.hash_code(12345)
local hash_n2 = quanta.hash_code(guid, 1000)
log_info("hash_code number: %s, %s", hash_n1, hash_n2)
-- -1792800413050876852

local hash_s1 = quanta.hash_code("12345")
local hash_s2 = quanta.hash_code(sguid, 1000)
log_info("hash_code string: %s, %s", hash_s1, hash_s2)
-- -1912366794928059912