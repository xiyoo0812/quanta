--encrypt.lua
local lfs = require('lfs')

local ldir          = lfs.dir
local lmkdir        = lfs.mkdir
local lcurdir       = lfs.currentdir
local lattributes   = lfs.attributes
local oexec         = os.execute
local ogetenv       = os.getenv
local sfind         = string.find

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

        if not sfind(file, ".lua") then
            goto continue
        end

        local luac_path = lcurdir() .. slash .. "luac"
        local params = " -o " .. encrypt_dir .. slash .. file .. " " .. full_name
        oexec(luac_path..params)

        :: continue ::
    end
end

if quanta.platform == "linux" then
    local input = lcurdir()
    local output = lcurdir()
    local env_input = ogetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        print("input dir not config!")
    else
        input = input .. slash .. env_input
    end
    local env_output = ogetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
    else
        output = output .. slash .. env_output
        lmkdir(output)
    end

    encrypt(input, output)
end
os.exit()
