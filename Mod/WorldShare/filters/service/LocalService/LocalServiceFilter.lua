--[[
Title: Local Service Filter
Author(s):  Big
Date: 2021.04.16
Desc: 
use the lib:
------------------------------------------------------------
local LocalServiceFilter = NPL.load('(gl)Mod/WorldShare/filters/service/LocalService/LocalServiceFilter.lua')
LocalServiceFilter:Init()
------------------------------------------------------------
]]

-- service
local LocalService = NPL.load('(gl)Mod/WorldShare/service/LocalService.lua')

local LocalServiceFilter = NPL.export()

function LocalServiceFilter:Init()
    -- filter move zip to folder
    GameLogic.GetFilters():add_filter(
        'service.local_service.move_zip_to_folder',
        function(...)
            LocalService:MoveZipToFolder(...)
        end
    )

    -- filter move folder to zip
    GameLogic.GetFilters():add_filter(
        'service.local_service.move_folder_to_zip',
        function(...)
            LocalService:MoveFolderToZip(...)
        end
    )

    -- filter load files
    GameLogic.GetFilters():add_filter(
        'service.local_service.load_files',
        function(...)
            return LocalService:LoadFiles(...)
        end
    )
end
