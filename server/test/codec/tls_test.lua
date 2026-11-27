-- tls_test.lua
local tls       = require("luatls")

local hex       = codec.hex_encode

--测试用 RSA 密钥对(base64 DER)
local PEM_PUB   = [[
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8iJ4Qgsxxn17YuV+MJYhjovE9
uaU/fpOx5MUZUamsdSDy/cHO/v4zPV6/PPxqJPIurK5J/RCke7t+pHkYu/hMjFr6
Q2DQ3dhS+7r0WXX3pbf0tu9glwTxCYmwX4GPlF8fDp8qRLGMJbnA9PeNyTsPciOI
5riO65kqCVthrB5RVwIDAQAB
]]
local PEM_PRI   = [[
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
]]

local TestCase     = import("test/case.lua")
local TlsTest      = class(TestCase)

function TlsTest:run()
    local value = "123456779"
    ------------------------------------------------------------------
    --1. hash: 返回固定长度二进制
    ------------------------------------------------------------------
    self:report("md5 length", #tls.md5(value) == 16, #tls.md5(value), 16)
    self:report("sha1 length", #tls.sha1(value) == 20, #tls.sha1(value), 20)
    self:report("sha256 length", #tls.sha256(value) == 32, #tls.sha256(value), 32)
    self:report("sha512 length", #tls.sha512(value) == 64, #tls.sha512(value), 64)
    self:report("md5 hex", hex(tls.md5("123456")) == "e10adc3949ba59abbe56e057f20f883e",
        hex(tls.md5("123456")), "e10adc3949ba59abbe56e057f20f883e")
    --md5 第二参数 true 返回 hex 字符串
    local md5hex = tls.md5(value, true)
    self:report("md5 as hex string", type(md5hex) == "string" and #md5hex == 32, md5hex, "32 chars")

    ------------------------------------------------------------------
    --2. base64 往返
    ------------------------------------------------------------------
    local text = "aTmEiujIXS9aezbfaADYGd5fFr2ExUPvw9t0Pijxjw8WMCQQDDsGLBH4RTQwPe"
    local nonce = tls.b64_encode(text)
    self:report("base64 encode", type(nonce) == "string" and #nonce > #text, type(nonce), "string")
    self:report("base64 roundtrip", tls.b64_decode(nonce) == text, true, true)

    ------------------------------------------------------------------
    --3. hmac / pbkdf2
    ------------------------------------------------------------------
    self:report("hmac_sha1", #tls.hmac_sha1("key", value) == 20, true, true)
    self:report("hmac_sha256", #tls.hmac_sha256("key", value) == 32, true, true)
    self:report("hmac_sha512", #tls.hmac_sha512("key", value) == 64, true, true)
    local salt = "U7efME3FYncgKHd9LP0LPg=="
    self:report("pbkdf2_sha1", #tls.pbkdf2_sha1("key", salt, 1000) == 20, true, true)
    self:report("pbkdf2_sha256", #tls.pbkdf2_sha256("passwd", salt, 1000) == 32, true, true)

    ------------------------------------------------------------------
    --4. crc
    ------------------------------------------------------------------
    for _, name in ipairs({ "crc8", "crc16", "crc32", "crc64" }) do
        self:report(name, type(tls[name]("123214345345345")) == "number", true, true)
    end

    ------------------------------------------------------------------
    --5. rsa: 加解密 / 签名验签
    --   encrypt 用 pubkey, sign 用 prikey, 两者都要设置
    ------------------------------------------------------------------
    local key = tls.rsa_key()
    --PEM 带换行, base64 decode 可能失败; 用 pcall 保护, 实际可用性由加解密/验签验证
    local ok_pub = pcall(key.set_pubkey, PEM_PUB)
    self:report("set_pubkey callable", ok_pub == true, ok_pub, true)
    self:report("set_prikey", key.set_prikey(PEM_PRI) == true, true, true)
    local plain = "hello rsa"
    local cipher = key.encrypt(plain)
    self:report("rsa encrypt", type(cipher) == "string" and #cipher > 0, type(cipher), "string")
    self:report("rsa decrypt", key.decrypt(cipher) == plain, key.decrypt(cipher), plain)
    local sig = key.sign(plain)
    self:report("rsa sign", type(sig) == "string" and #sig > 0, type(sig), "string")
    self:report("rsa verify", key.verify(plain, sig) == true, key.verify(plain, sig), true)
end

return TlsTest
