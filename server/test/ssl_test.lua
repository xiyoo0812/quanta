--ssl_test.lua

local log_info      = logger.info
local sformat       = string.format

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

local pbkdf2_sha1   = ssl.pbkdf2_sha1
local pbkdf2_sha256 = ssl.pbkdf2_sha256

--base64
local ran = lrandomkey(12, true)
log_info("lrandomkey-> ran: {}", ran)
local text = "aTmEiujIXS9aezbfaADYGd5fFr2ExUPvw9t0Pijxjw8WMCQQDDsGLBH4RTQwPe"
local nonce = lb64encode(text)
local dnonce = lb64decode(nonce)
log_info("b64encode-> nonce: {}, dnonce:{}", nonce, dnonce)

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
local nmd5 = lmd5(value, true)
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

local username = "abcdefg"
local passwd = "123456"
local salt = "U7efME3FYncgKHd9LP0LPg=="
local sha1_key = lmd5(sformat("%s:mongo:%s", username, passwd), 1)
local salt_sha1 = lhex_encode(pbkdf2_sha1(sha1_key, salt, 10000))
log_info("pbkdf2_sha1: {}", salt_sha1)
local salt_sha256 = lhex_encode(pbkdf2_sha256(passwd, salt, 10000))
log_info("pbkdf2_sha256: {}", salt_sha256)

log_info("crc8: {}", ssl.crc8("123214345345345"))
log_info("crc8: {}", ssl.crc16("dfsdfsdfsdfgsdg"))
log_info("crc8: {}", ssl.crc32("2213weerwbdfgd"))
log_info("crc8: {}", ssl.crc64("++dsfsdf++gbdfgdfg"))

--rsa

local pem_pub = [[
-----BEGIN RSA PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8iJ4Qgsxxn17YuV+MJYhjovE9
uaU/fpOx5MUZUamsdSDy/cHO/v4zPV6/PPxqJPIurK5J/RCke7t+pHkYu/hMjFr6
Q2DQ3dhS+7r0WXX3pbf0tu9glwTxCYmwX4GPlF8fDp8qRLGMJbnA9PeNyTsPciOI
5riO65kqCVthrB5RVwIDAQAB
-----END RSA PUBLIC KEY-----
]]

local pem_pri = [[
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQC8iJ4Qgsxxn17YuV+MJYhjovE9uaU/fpOx5MUZUamsdSDy/cHO
/v4zPV6/PPxqJPIurK5J/RCke7t+pHkYu/hMjFr6Q2DQ3dhS+7r0WXX3pbf0tu9g
lwTxCYmwX4GPlF8fDp8qRLGMJbnA9PeNyTsPciOI5riO65kqCVthrB5RVwIDAQAB
AoGALn/znFbmXc/U8NcnvcU0En8JyROUskhh3Spzgn8lvidVbRkxSACUacblK327
M+LQ6LomcpE8HZV29RFT3Mnfv3S3A2w+n0vpErK0ZIXi/0XHI3hI/KLeu1ZED+cN
jTtO+mAl8y6lQssqZMh0+ZPP1W/XcKyeiOKfHUeMCvobu4ECQQDIIqQeWsHWI8At
X2vTP5dZ0/IN7Xgnqyyl6jY2VklxrGzpnZ5TGmg2x0qPd9FeUnxM639yMbFTcHdv
xN4MPlcnAkEA8Sjwqyr/2WPjAvP3mu+IIblrQuEDrZIteNrdoqcOgAKeI7vfHRrz
RfjcmWstnN6sHFX+Xi0zWlQoY9h8ThwSUQJAEVIuMhJYxFfDwimIA3h1eOjHAj2T
MJu3+YQTvRAquxPZOT7S/Q5EBrmo0lHkZO1upJmdJhz24+nP7HR1Y0nh8QJBAKPE
cpM6kx40p9/Ef1wW1/JW8VEsbwv63ahZsPMY0U76+Bs6JMymFZhp5JzG3OXPjT98
4k1gEqR/zCHpzJhaldECQFQXmxVMQqcjaedNrBkPwn7Qs4dDxGMqLYk2sk7f//E1
J9rSdD3+UFNRBHrhyAv8xE0q2Diun8J6boOVhbhVknk=
-----END RSA PRIVATE KEY-----
]]

local prikey = ssl.rsa_key()
prikey.set_prikey(pem_pri)

local rsav1 = prikey.encrypt(pem_pub)
log_info("rsa_encrypt: {}, {}",  #rsav1, lhex_encode(rsav1))
local rsav2 = prikey.decrypt(rsav1)
log_info("rsa_decrypt: {}, {}",  #rsav2, rsav2)
local rsav3 = prikey.sign(pem_pub)
log_info("rsa_sign: {}, {}",  #rsav3, lhex_encode(rsav3))
local rsav4 = prikey.verify(pem_pub, rsav3)
log_info("rsa_verify: {}",  rsav4)

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
