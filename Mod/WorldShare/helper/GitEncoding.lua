--[[
Title: EncodingGithub
Author(s):  big
Date:  2017.4.22
Desc: 
use the lib: corvent base32 and fit to github or gitlab
------------------------------------------------------------
local GitEncoding = NPL.load("(gl)Mod/WorldShare/helper/GitEncoding.lua")
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Encoding/basexx.lua")

local Encoding = commonlib.gettable("System.Encoding.basexx")

local GitEncoding = NPL.export()

-- =转成-equal  +转成-plus  /转成-slash
function GitEncoding.base32(text)
    if (text) then
        local notLetter = string.find(text, "%A%A")

        if (notLetter) then
            text = Encoding.to_base32(text)

            text = text:gsub("[=]", "-equal")
            text = text:gsub("[%+]", "-plus")
            text = text:gsub("[/]", "-slash")

            text = "world_base32_" .. text
        else
            text = "world_" .. text
        end

        --LOG.std(nil,"debug","text",text);

        return text
    else
        return nil
    end
end

function GitEncoding.unbase32(text)
    if (text) then
        local notLetter = string.find(text, "world_base32_")

        if (notLetter) then
            text = text:gsub("world_base32_", "")

            text = text:gsub("[-equal]", "=")
            text = text:gsub("[-plus]", "+")
            text = text:gsub("[-slash]", "/")

            return Encoding.from_base32(text)
        else
            text = text:gsub("world_", "")

            return text
        end
    else
        return nil
    end
end