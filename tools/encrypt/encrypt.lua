--encrypt.lua
local lstdfs        = require("lstdfs")

local ldir          = lstdfs.dir
local lmkdir        = lstdfs.mkdir
local lappend       = lstdfs.append
local lfilename     = lstdfs.filename
local lextension    = lstdfs.extension
local labsolute     = lstdfs.absolute
local lcurdir       = lstdfs.current_path
local sformat       = string.format
local qgetenv       = quanta.getenv
local oexec         = os.execute

-- 加密lua
local function encrypt(input_dir, output_dir)
    local dir_files = ldir(input_dir)
    for _, file in pairs(dir_files) do
        local fullname = file.name
        local fname = lfilename(fullname)
        if file.type == "directory" then
            local chind_dir = lappend(output_dir, fname)
            lmkdir(chind_dir)
            encrypt(fullname, chind_dir)
            goto continue
        end
        if lextension(fname) ~= ".lua" then
            goto continue
        end
        local luac = lappend(lcurdir(), "luac")
        local outfile = lappend(output_dir, fname)
        oexec(sformat("%s -o %s %s", luac, outfile, fullname))
        print("encrypt:", fullname)
        :: continue ::
    end
end

local input = lcurdir()
local output = lcurdir()
local env_input = qgetenv("QUANTA_INPUT")
if not env_input or #env_input == 0 then
    print("input dir not config!")
else
    input = lappend(input, env_input)
end
local env_output = qgetenv("QUANTA_OUTPUT")
if not env_output or #env_output == 0 then
    print("output dir not config!")
else
    output = lappend(output, env_output)
    lmkdir(output)
end

print("start encrypt!")
local input_path = labsolute(input)
local output_path = labsolute(output)
encrypt(input_path, output_path)
print("encrypt success!")

os.exit()
