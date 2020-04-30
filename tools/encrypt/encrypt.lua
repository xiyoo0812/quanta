--encrypt.lua
local lfs = require('lfs')

local ldir = lfs.dir
local lmkdir = lfs.mkdir
local lcurdir = lfs.currentdir
local lattributes = lfs.attributes
local oexec = os.execute

local slash = "/"

-- 加密lua
local function encrypt(lua_dir, encrypt_dir)
    for file in ldir(lua_dir) do
        if file == "." or file == ".." then
            goto continue
        end

        local full_name = lua_dir .. slash .. file
        local attr = lattributes(full_name)
        if attr.mode == "directory" then
            local new_dir = encrypt_dir .. slash .. file
            lmkdir(new_dir)
            encrypt(full_name, new_dir)
            goto continue
        end

        local luac_path = lcurdir() .. slash .. "luac"
        local params = " -o " .. encrypt_dir .. slash .. file .. " " .. full_name
        oexec(luac_path..params)

        :: continue ::
    end
end

if quanta.platform == "linux" then
    local encrypt_dir = lcurdir() .. slash .. "encrypt_lua"
    lmkdir(encrypt_dir)

    local lua_dir = lcurdir() .. slash .. "lua"
    print("lua_dir:", lua_dir)

    encrypt(lua_dir, encrypt_dir)
end
os.exit()
