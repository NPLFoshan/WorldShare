--[[
Title: Pipe Command
Author(s): big
CreateDate: 2020.9.17
ModifyDate: 2021.9.10
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/WorldShare/command/Pipe.lua")
-------------------------------------------------------
]]

-- load lib
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser")
local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands")
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager")

-- UI
local CommonLoadWorld = NPL.load('(gl)Mod/WorldShare/cellar/Common/LoadWorld/CommonLoadWorld.lua')

local PipeCommand = NPL.export()

function PipeCommand:Init()
    local pipe = {
        name="pipe", 
        quick_ref="/pipe [id|classId|ip address]", 
        desc=[[]],
        mode_deny = "",
        handler = function(cmd_name, cmd_text, cmd_params)
            local options;
            options, cmd_text = CmdParser.ParseOptions(cmd_text)
    
            local word, cmd_text = CmdParser.ParseWord(cmd_text)

            if not word then
                return false
            end

            if cmd_params and cmd_params.value then
                local pid = Mod.WorldShare.Utils.GetProjectId(cmd_params.value)

                if pid then
                    CommonLoadWorld:EnterWorldById(pid)
                else
                    CommonLoadWorld.GotoUrl(cmd_params.value)
                end
            end
        end,
    }

    Commands['pipe'] = pipe

    return pipe
end
