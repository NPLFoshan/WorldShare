--[[
Title: SyncMain
Author(s):  big
Date:  2017.4.17
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/WorldShare/SyncMain.lua");
local SyncMain  = commonlib.gettable("Mod.WorldShare.sync.SyncMain");
------------------------------------------------------------
]]

NPL.load("(gl)script/apps/Aries/Creator/WorldCommon.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/World/WorldRevision.lua");
NPL.load("(gl)Mod/WorldShare/login.lua");
NPL.load("(gl)Mod/WorldShare/service/GithubService.lua");
NPL.load("(gl)Mod/WorldShare/service/GitlabService.lua");
NPL.load("(gl)Mod/WorldShare/service/LocalService.lua");
NPL.load("(gl)Mod/WorldShare/service/HttpRequest.lua");
NPL.load("(gl)Mod/WorldShare/sync/SyncGUI.lua");
NPL.load("(gl)script/ide/Encoding.lua");
NPL.load("(gl)script/ide/System/Encoding/base64.lua");
NPL.load("(gl)Mod/WorldShare/helper/GitEncoding.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Areas/ShareWorldPage.lua");
NPL.load("(gl)Mod/WorldShare/main.lua");
NPL.load("(gl)Mod/WorldShare/helper/KeepworkGen.lua");

local SyncGUI            = commonlib.gettable("Mod.WorldShare.sync.SyncGUI");
local WorldCommon        = commonlib.gettable("MyCompany.Aries.Creator.WorldCommon")
local MainLogin		     = commonlib.gettable("MyCompany.Aries.Game.MainLogin");
local WorldRevision      = commonlib.gettable("MyCompany.Aries.Creator.Game.WorldRevision");
local login              = commonlib.gettable("Mod.WorldShare.login");
local GithubService      = commonlib.gettable("Mod.WorldShare.service.GithubService");
local GitlabService      = commonlib.gettable("Mod.WorldShare.service.GitlabService");
local LocalService       = commonlib.gettable("Mod.WorldShare.service.LocalService");
local HttpRequest		 = commonlib.gettable("Mod.WorldShare.service.HttpRequest");
local Encoding           = commonlib.gettable("commonlib.Encoding");
local EncodingS          = commonlib.gettable("System.Encoding");
local GitEncoding        = commonlib.gettable("Mod.WorldShare.helper.GitEncoding");
local CommandManager     = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local InternetLoadWorld  = commonlib.gettable("MyCompany.Aries.Creator.Game.Login.InternetLoadWorld");
local ShareWorldPage     = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop.Areas.ShareWorldPage");
local WorldShare         = commonlib.gettable("Mod.WorldShare");
local KeepworkGen        = commonlib.gettable("Mod.WorldShare.helper.KeepworkGen");

local SyncMain = commonlib.gettable("Mod.WorldShare.sync.SyncMain");

local Page;

function SyncMain:ctor()
end

function SyncMain:init()
	LOG.std(nil, "debug", "SyncMain", "init");
	
	SyncMain.worldName = nil;

	-- 没有登陆则直接使用离线模式
	if(login.token) then
		SyncMain:compareRevision();
		SyncMain:StartSyncPage();
	end
end

function SyncMain.setPage()
	Page = document:GetPageCtrl();
end

function SyncMain.goBack()
    Page:CloseWindow();

    if(not WorldCommon.GetWorldInfo()) then
        MainLogin.state.IsLoadMainWorldRequested = nil;
        MainLogin:next_step();
    end
end

function SyncMain:StartSyncPage()
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/WorldShare/sync/StartSync.html", 
		name = "SyncWorldShare",
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ct",
			x = -500/2,
			y = -270/2,
			width = 500,
			height = 270,
		cancelShowAnimation = true,
	});
end

function SyncMain:compareRevision(_worldDir)
	if(login.token) then
		if(WorldCommon:GetWorldInfo())then
			SyncMain.selectedWorldInfor = WorldCommon:GetWorldInfo();
		end
		LOG.std(nil,"debug","worldinfo",SyncMain.selectedWorldInfor);

		if(_worldDir) then
			SyncMain.worldDir = _worldDir;
		else
			SyncMain.worldDir = GameLogic.GetWorldDirectory();
		end

		LOG.std(nil,"debug","self.worldDir",SyncMain.worldDir);

		WorldRevisionCheckOut   = WorldRevision:new():init(SyncMain.worldDir);
		SyncMain.currentRevison = WorldRevisionCheckOut:Checkout();

		SyncMain.foldername = SyncMain.worldDir:match("worlds/DesignHouse/([^/]*)/");
		SyncMain.foldername = Encoding.DefaultToUtf8(SyncMain.foldername);
		SyncMain.localFiles = LocalService:LoadFiles(SyncMain.worldDir,"",nil,1000,nil);

		--LOG.std(nil,"debug","self.foldername",self.foldername);
		--LOG.std(nil,"debug","self.localFiles",self.localFiles);

		local hasRevision = false;
		for key,value in ipairs(SyncMain.localFiles) do
			--LOG.std(nil,"debug","filename",value.filename);
			if(value.filename == "revision.xml") then
				hasRevision = true;
				break;
			end
		end

		if(hasRevision) then
			local contentUrl;
			if(login.dataSourceType == 'github') then
				contentUrl = login.rawBaseUrl .. "/" .. login.dataSourceUsername .. "/" .. GitEncoding.base64(SyncMain.foldername) .. "/master/revision.xml";
			elseif(login.dataSourceType == 'gitlab') then
				contentUrl = login.rawBaseUrl .. "/" .. login.dataSourceUsername .. "/" .. GitEncoding.base64(SyncMain.foldername) .. "/raw/master/revision.xml";
			end

			SyncMain.remoteRevison = 0;

			--LOG.std(nil,"debug","contentUrl",contentUrl);

			HttpRequest:GetUrl(contentUrl, function(data,err)
				--LOG.std(nil,"debug","contentUrl",contentUrl);
				--LOG.std(nil,"debug","data",data);
				LOG.std(nil,"debug","err",err);

				if(err == 0) then
					Page:CloseWindow();
					_guihelper.MessageBox(L"网络错误");
					return
				end

				if(err == 404 or err == 401) then
					Page:CloseWindow();
					SyncMain.firstCreate = true;
					--_guihelper.MessageBox(L"数据源暂无数据，请先分享世界");

					ShareWorldPage.ShowPage();
					return
				end
				
				if(type(tonumber(data)) == "number") then
					SyncMain.remoteRevison = tonumber(data);
				else
					Page:CloseWindow();
					SyncMain.firstCreate = true;
					--_guihelper.MessageBox(L"数据源暂无数据，请先分享世界");

					ShareWorldPage.ShowPage();
					return
				end

				-- LOG.std(nil,"debug","self.githubRevison",self.githubRevison);

				if(tonumber(SyncMain.currentRevison) ~= tonumber(SyncMain.remoteRevison)) then
					Page:Refresh();
				else
					_guihelper.MessageBox(L"数据源已存在此作品，且版本相等");
					Page:CloseWindow();
				end
			end);
		else
			commonlib.TimerManager.SetTimeout(function() 
				Page:CloseWindow();

				CommandManager:RunCommand("/save");
				SyncMain:compareRevision();
				SyncMain:StartSyncPage();
			end, 500)
		end
	end
end

function SyncMain.shareNow()
    Page:CloseWindow();

	ShareWorldPage.TakeSharePageImage();
    if(not SyncMain.firstCreate and tonumber(SyncMain.currentRevison) < tonumber(SyncMain.remoteRevison)) then
        _guihelper.MessageBox("当前本地版本小于远程版本，是否继续上传？", function(res)
            if(res and res == 6) then
                SyncMain:syncToDataSource();
            end
        end);
    elseif(tonumber(SyncMain.currentRevison) > tonumber(SyncMain.remoteRevison)) then
        SyncMain:syncToDataSource();
    end
end

function SyncMain.useLocal()
    Page:CloseWindow();

    if(tonumber(SyncMain.currentRevison) < tonumber(SyncMain.remoteRevison)) then
        SyncMain:useLocalGUI();
    elseif(tonumber(SyncMain.currentRevison) > tonumber(SyncMain.remoteRevison)) then
        -- _guihelper.MessageBox("开始同步--将本地大小有变化的文件上传到github"); -- 上传或更新
        SyncMain:syncToDataSource();
    end
end

function SyncMain.useRemote()
    Page:CloseWindow();

    if(tonumber(SyncMain.remoteRevison) < tonumber(SyncMain.currentRevison)) then
        SyncMain:useDataSourceGUI();
    elseif(tonumber(SyncMain.remoteRevison) > tonumber(SyncMain.currentRevison)) then
        -- _guihelper.MessageBox("开始同步--将github大小有变化的文件下载到本地");-- 下载或覆盖
        SyncMain:syncToLocal();
    end
end

function SyncMain.useOffline()
    Page:CloseWindow();
end

function SyncMain:useLocalGUI()
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/WorldShare/sync/StartSyncUseLocal.html", 
		name = "SyncWorldShare", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ct",
			x = -500/2,
			y = -270/2,
			width = 500,
			height = 270,
		cancelShowAnimation = true,
	});
end

function SyncMain:useDataSourceGUI()
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/WorldShare/sync/StartSyncUseDataSource.html", 
		name = "SyncWorldShare", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ct",
			x = -500/2,
			y = -270/2,
			width = 500,
			height = 270,
		cancelShowAnimation = true,
	});
end

function SyncMain:syncToLocal(_worldDir, _foldername, _callback)
	--LOG.std(nil,"debug","worldDir",_worldDir);

	-- 加载进度UI界面
	local syncToLocalGUI = SyncGUI:new();

	if(_worldDir) then
		SyncMain.worldDir   = _worldDir;
		SyncMain.foldername = _foldername;
	end

	if(not GitlabService.projectId) then
		if(SyncMain.worldName) then
			GitlabService.projectId = WorldShare:GetWorldData("gitLabProjectId", SyncMain.worldName);
		else
			GitlabService.projectId = WorldShare:GetWorldData("gitLabProjectId");
		end
	end

	SyncMain.localFiles = LocalService:LoadFiles(SyncMain.worldDir,"",nil,1000,nil);

	if (SyncMain.worldDir == "") then
		_guihelper.MessageBox(L"下载失败，原因：下载目录为空");
		return;
	else
		local curUpdateIndex        = 1;
		local curDownloadIndex      = 1;
		local totalLocalIndex       = nil;
		local totalDataSourceIndex  = nil;
		local dataSourceIndex       = 0;
		local dataSourceFiles       = {};
		local syncGUItotal          = 0;
		local syncGUIIndex          = 0;
		local syncGUIFiles          = "";

		-- LOG.std(nil,"debug","SyncMainGUI",curDownloadIndex);
		-- LOG.std(nil,"debug","SyncMainGUI",totalDataSourceIndex);

		syncToLocalGUI:updateDataBar(syncGUIIndex, syncGUItotal, L'获取文件sha列表');

		local function finish()
			--成功是返回信息给login
			if(_callback) then
				_callback(true,SyncMain.remoteRevison);
			end
		end

		-- 下载新文件
		local function downloadOne()
			if (curDownloadIndex <= totalDataSourceIndex) then
				-- LOG.std(nil,"debug","githubFiles.tree[curDownloadIndex]",githubFiles.tree[curDownloadIndex]);
				-- LOG.std(nil,"debug","curDownloadIndex",curDownloadIndex);

				if (dataSourceFiles[curDownloadIndex].needChange) then
					if(dataSourceFiles[curDownloadIndex].type == "blob") then
						-- LOG.std(nil,"debug","githubFiles.tree[curDownloadIndex].type",githubFiles.tree[curDownloadIndex].type);
						LocalService:download(SyncMain.foldername, dataSourceFiles[curDownloadIndex].path, function (bIsDownload, response)
							if (bIsDownload) then
								syncGUIIndex = syncGUIIndex + 1;
								syncGUIFiles = response.filename;

								if(response.filename == "revision.xml") then
									SyncMain.remoteRevison = response.content;
								end

								if(syncGUIIndex == syncGUItotal) then
									finish();
								end

								syncToLocalGUI:updateDataBar(syncGUIIndex, syncGUItotal, response.filename);
							else
								_guihelper.MessageBox(L'下载失败，请稍后再试');
								syncToLocalGUI.finish();
								
							end
						end);
					end

					curDownloadIndex = curDownloadIndex + 1;
				else
					curDownloadIndex = curDownloadIndex + 1;
				end

				if (curDownloadIndex > totalDataSourceIndex) then
					-- 同步完成
					if(syncGUIIndex == syncGUItotal) then
						finish();
					end
				else
					downloadOne(); --继续递归上传
				end
			end
		end

		-- 更新本地文件
		local function updateOne()
			if (curUpdateIndex <= totalLocalIndex) then
				LOG.std(nil,"debug","curUpdateIndex",curUpdateIndex);
				local bIsExisted  = false;
				local githubIndex = nil;

				-- 用Gihub的文件和本地的文件对比
				for key,value in ipairs(dataSourceFiles) do
					if(value.path == SyncMain.localFiles[curUpdateIndex].filename) then
						LOG.std(nil,"debug","value.path",value.path);
						bIsExisted      = true;
						dataSourceIndex = key; 
						break;
					end
				end

				-- 本地是否存在Github上的文件
				if (bIsExisted) then
					dataSourceFiles[dataSourceIndex].needChange = false;
					-- LOG.std(nil,"debug","self.localFiles[curUpdateIndex].filename",self.localFiles[curUpdateIndex].filename);
					-- LOG.std(nil,"debug","self.localFiles[curUpdateIndex].sha1",self.localFiles[curUpdateIndex].sha1);
					-- LOG.std(nil,"debug","githubFiles.tree[dataSourceIndex].sha",githubFiles.tree[dataSourceIndex].sha);

					if (SyncMain.localFiles[curUpdateIndex].sha1 ~= dataSourceFiles[dataSourceIndex].sha) then
						-- 更新已存在的文件
						LocalService:update(SyncMain.foldername, dataSourceFiles[dataSourceIndex].path, function (bIsUpdate, response)
							if (bIsUpdate) then
								curUpdateIndex = curUpdateIndex + 1;
								syncGUIIndex   = syncGUIIndex   + 1;

								-- syncGUIFiles   = githubFiles.tree[dataSourceIndex].path;
								-- LOG.std(nil,"debug","syncGUIIndex",syncGUIIndex);

								if(response.filename == "revision.xml") then
									SyncMain.remoteRevison = response.content;
								end

								syncToLocalGUI:updateDataBar(syncGUIIndex, syncGUItotal, response.filename);

								-- 如果当前计数大于最大计数则更新
								if (curUpdateIndex > totalLocalIndex) then      -- check whether all files have updated or not. if false, update the next one, if true, upload files.  
									-- _guihelper.MessageBox(L'同步完成-A');
									downloadOne();
								else
									updateOne();
								end
							else
								_guihelper.MessageBox(L'更新失败,请稍后再试');
								syncToLocalGUI.finish();
							end
						end);
					else
						-- if file exised, and has same sha value, then contain it
						curUpdateIndex = curUpdateIndex + 1;
						syncGUIIndex   = syncGUIIndex   + 1;

						-- syncGUIFiles   = githubFiles.tree[dataSourceIndex].path;

						LOG.std(nil,"debug","syncGUIIndex",syncGUIIndex);
						-- LOG.std(nil,"debug","githubFiles.tree[dataSourceIndex].path",githubFiles.tree[dataSourceIndex].path);

						syncToLocalGUI:updateDataBar(syncGUIIndex, syncGUItotal, syncGUIFiles);

						if (curUpdateIndex > totalLocalIndex) then     -- check whether all files have updated or not. if false, update the next one, if true, upload files.
							-- _guihelper.MessageBox(L'同步完成-B');
							downloadOne();
						else
							updateOne();
						end
					end
				else
					LOG.std(nil,"debug","delete-filename",self.localFiles[curUpdateIndex].filename);
					LOG.std(nil,"debug","delete-sha1",self.localFiles[curUpdateIndex].sha1);

					-- 如果过github不删除存在，则删除本地的文件
					deleteOne();
				end
			end
		end

		-- 删除文件
		local function deleteOne()
			LocalService:delete(SyncMain.foldername, SyncMain.localFiles[curUpdateIndex].filename, function ()
				curUpdateIndex = curUpdateIndex + 1;

				if (curUpdateIndex > totalLocalIndex) then
					downloadOne();
				else
					updateOne();
				end
			end);
		end

		-- 获取数据源仓文件
		SyncMain:getFileShaListService(SyncMain.foldername, function(data, err)
			if(err ~= 404) then
				if(err == 409) then
					_guihelper.MessageBox(L"数据源上暂无数据");
					syncToLocalGUI.finish();
					return;
				end

				LOG.std(nil,"debug","syncToLocal",data);

				dataSourceFiles = data;

				totalLocalIndex      = #SyncMain.localFiles;
				totalDataSourceIndex = #dataSourceFiles;

				for i=1,#dataSourceFiles do
					dataSourceFiles[i].needChange = true;

					if(dataSourceFiles[i].type == "blob") then
						syncGUItotal = syncGUItotal + 1;
					end

					i = i + 1;
				end

				syncToLocalGUI:updateDataBar(syncGUIIndex , syncGUItotal, L"开始同步");

				LOG.std(nil,"debug","totalLocalIndex",totalLocalIndex);
				LOG.std(nil,"debug","totalDataSourceIndex",totalDataSourceIndex);

				if (totalLocalIndex ~= 0) then
					updateOne();
				else
					downloadOne(); --如果文档文件夹为空，则直接开始下载
				end
			else
				_guihelper.MessageBox(L"获取G数据源文件失败，请稍后再试！");
				syncToLocalGUI.finish();
			end
		end);
	end
end

function SyncMain:syncToDataSource()
	-- 加载进度UI界面
	local syncToDataSourceGUI = SyncGUI:new();
	local test = false;
	local function syncToDataSourceGo()
		SyncMain.localFiles = LocalService:LoadFiles(SyncMain.worldDir,"",nil,1000,nil);
		
		if (SyncMain.worldDir == "") then
			_guihelper.MessageBox(L"上传失败，将使用离线模式，原因：上传目录为空");
			return;
		else
			local curUpdateIndex        = 1;
			local curUploadIndex        = 1;
			local totalLocalIndex       = nil;
			local totalDataSourceIndex  = nil;
			local dataSourceFiles       = {};
			local syncGUItotal          = 0;
			local syncGUIIndex          = 0;
			local syncGUIFiles          = "";

			syncToDataSourceGUI:updateDataBar(syncGUIIndex, syncGUItotal, L'获取文件sha列表');

			LOG.std(nil,"debug","SyncMain",curUploadIndex);
			LOG.std(nil,"debug","SyncMain",totalDataSourceIndex);

			local function finish()
				if(syncGUItotal == syncGUIIndex) then
					LOG.std(nil,"debug","SyncMain.selectedWorldInfor",SyncMain.selectedWorldInfor);
					LOG.std(nil,"debug","send",SyncMain.selectedWorldInfor.tooltip)

					local modDateTable = {};
					local readme;

					if(SyncMain.selectedWorldInfor.tooltip)then
						for modDateEle in string.gmatch(SyncMain.selectedWorldInfor.tooltip,"[^:]+") do
							modDateTable[#modDateTable+1] = modDateEle;
						end

						modDateTable = modDateTable[1];
					else
						modDateTable = os.date("%Y-%m-%d-%H-%M-%S");
					end
					
					local hasPreview = false;

					for key,value in ipairs(SyncMain.localFiles) do
						if(value.filename == "preview.jpg") then
							hasPreview = true;
						end
					end

					for key,value in ipairs(SyncMain.localFiles) do
						if(value.filename == "README.md") then
							readme = LocalService:getFileContent(SyncMain.worldDir .. "README.md");
							LOG.std(nil,"debug","SyncMain.worldDir",SyncMain.worldDir);
							LOG.std(nil,"debug","readme",readme);
						end
					end

					local preview = {};
					preview[0] = {};
					preview[0].previewUrl = login.rawBaseUrl .. "/" .. login.dataSourceUsername .. "/" .. GitEncoding.base64(SyncMain.foldername) .. "/raw/master/preview.jpg";
					preview = NPL.ToJson(preview,true);

					local params = {};
					params.modDate		   = modDateTable;
					params.worldsName      = SyncMain.foldername;
					params.revision        = SyncMain.currentRevison;
					params.hasPreview      = hasPreview;
					params.dataSourceType  = login.dataSourceType;
					params.gitlabProjectId = GitlabService.projectId;
					params.readme          = readme;
					params.preview         = preview;

					LOG.std(nil,"debug","params",params)

--					SyncMain:genWorldMD(params);

					HttpRequest:GetUrl({
						url     = login.site .. "/api/mod/worldshare/models/worlds/refresh",
						json    = true,
						form    = params,
						headers = {
							Authorization    = "Bearer " .. login.token,
							["content-type"] = "application/json",
						},
					},function(data,err)
						LOG.std(nil,"debug","finish",data);
						LOG.std(nil,"debug","finish",err);

						LOG.std(nil,"debug","SyncMain.worldName",SyncMain.worldName);
						if(err == 204) then
							LOG.std(nil,"debug","SyncMain.worldName",SyncMain.worldName);
							SyncMain:genWorldMD(params);
							login.syncWorldsList();
						end
					end);

					if(SyncMain.firstCreate) then
						SyncMain.firstCreate = false;
					end
				end
			end

			if(test)then
				finish();
				return;
			end

			-- 上传新文件
			local function uploadOne()
				if (curUploadIndex <= totalLocalIndex) then
					-- LOG.std(nil,"debug","self.localFiles",self.localFiles[curUploadIndex].needChange);
					-- LOG.std(nil,"debug","self.localFiles",self.localFiles[curUploadIndex]);

					if (SyncMain.localFiles[curUploadIndex].needChange) then
						SyncMain.localFiles[curUploadIndex].needChange = false;
						SyncMain:uploadService(SyncMain.foldername, SyncMain.localFiles[curUploadIndex].filename, SyncMain.localFiles[curUploadIndex].file_content_t,function (bIsUpload, filename)
							if (bIsUpload) then
								syncGUIIndex = syncGUIIndex + 1;

								syncToDataSourceGUI:updateDataBar(syncGUIIndex, syncGUItotal, filename);

								curUploadIndex = curUploadIndex + 1;

								if(syncGUItotal == syncGUIIndex) then
									finish();
								end
							else
								_guihelper.MessageBox(L"更新失败");
								syncToDataSourceGUI.finish();
								--_guihelper.MessageBox(SyncMain.localFiles[curUploadIndex].filename .. ' 上传失败，请稍后再试');
							end
						end);
					else
						curUploadIndex = curUploadIndex + 1;
					end

					if (curUploadIndex > totalLocalIndex) then
						if(syncGUItotal == syncGUIIndex) then
							finish();
						end
						-- _guihelper.MessageBox('同步完成-D');
					else
						uploadOne(); --继续递归上传
					end
				end
			end

			-- 更新数据源文件
			local function updateOne()
				if (curUpdateIndex <= totalDataSourceIndex) then
					--LOG.std(nil,"debug","curUpdateIndex",curUpdateIndex);
					--LOG.std(nil,"debug","totalDataSourceIndex",totalDataSourceIndex);
					local bIsExisted  = false;
					local LocalIndex  = nil;

					-- 用数据源的文件和本地的文件对比
					for key,value in ipairs(SyncMain.localFiles) do
						if(value.filename == dataSourceFiles[curUpdateIndex].path) then
							bIsExisted  = true;
							LocalIndex  = key; 
							break;
						end
					end

					if (bIsExisted) then
						SyncMain.localFiles[LocalIndex].needChange = false;
						--LOG.std(nil,"debug","dataSourceFiles.tree[curUpdateIndex].path",dataSourceFiles.tree[curUpdateIndex].path);
						--LOG.std(nil,"debug","dataSourceFiles[curUpdateIndex].sha",dataSourceFiles[curUpdateIndex].sha);
						--LOG.std(nil,"debug","self.localFiles.sha1",self.localFiles[LocalIndex].sha1);

						if (dataSourceFiles[curUpdateIndex].sha ~= SyncMain.localFiles[LocalIndex].sha1) then
							-- 更新已存在的文件
							SyncMain:updateService(SyncMain.foldername, SyncMain.localFiles[LocalIndex].filename, SyncMain.localFiles[LocalIndex].file_content_t, dataSourceFiles[curUpdateIndex].sha, function (bIsUpdate,content)
								if (bIsUpdate) then
									syncGUIIndex = syncGUIIndex + 1;
									syncGUIFiles = SyncMain.localFiles[LocalIndex].filename;

									syncToDataSourceGUI:updateDataBar(syncGUIIndex, syncGUItotal, syncGUIFiles);

									curUpdateIndex = curUpdateIndex + 1;

									-- 如果当前计数大于最大计数则更新
									if (curUpdateIndex > totalDataSourceIndex) then
										-- _guihelper.MessageBox(L'同步完成-A');
										finish();
										uploadOne();
									else
										updateOne();
									end
								else
									_guihelper.MessageBox(L"更新失败");
									syncToDataSourceGUI.finish();
									-- _guihelper.MessageBox(dataSourceFiles.tree[curUpdateIndex].path .. ' 更新失败,请稍后再试');
								end
							end);
						else
							-- if file exised, and has same sha value, then contain it
							syncGUIIndex   = syncGUIIndex + 1;
							syncGUIFiles   = SyncMain.localFiles[LocalIndex].filename;

							syncToDataSourceGUI:updateDataBar(syncGUIIndex, syncGUItotal, syncGUIFiles);

							curUpdateIndex = curUpdateIndex + 1;

							if (curUpdateIndex > totalDataSourceIndex) then     -- check whether all files have updated or not. if false, update the next one, if true, upload files.
								-- _guihelper.MessageBox(L'同步完成-B');
								uploadOne();
							else
								updateOne();
							end
						end
					else
						-- LOG.std(nil,"debug","delete-filename",self.localFiles[LocalIndex].filename);
						-- LOG.std(nil,"debug","delete-sha1",self.localFiles[LocalIndex].filename);

						-- 如果过数据源不删除存在，则删除本地的文件
						deleteOne();
					end
				end
			end

			-- 删除数据源文件
			function deleteOne()
				if(dataSourceFiles[curUpdateIndex].type == "blob") then
					SyncMain:deleteFileService(SyncMain.foldername, dataSourceFiles[curUpdateIndex].path, dataSourceFiles[curUpdateIndex].sha, function (bIsDelete)
						if (bIsDelete) then
							curUpdateIndex = curUpdateIndex + 1;

							if (curUpdateIndex > totalDataSourceIndex) then  --check whether all files have updated or not. if false, update the next one, if true, upload files.
								-- _guihelper.MessageBox(L'同步完成-C');
								uploadOne();
							else
								updateOne();
							end
						else
							_guihelper.MessageBox(L"更新失败");
							syncToDataSourceGUI.finish();
							--_guihelper.MessageBox('删除 ' .. SyncMain.localFiles[curUpdateIndex].filename .. ' 失败, 请稍后再试');
						end
					end);
				else
					curUpdateIndex = curUpdateIndex + 1;

					if (curUpdateIndex > totalDataSourceIndex) then  --check whether all files have updated or not. if false, update the next one, if true, upload files.
						uploadOne();
					else
						updateOne();
					end
				end
			end

			-- 获取数据源仓文件
			SyncMain:getFileShaListService(SyncMain.foldername, function(data, err)
				local hasReadme = false;

				for key,value in ipairs(SyncMain.localFiles) do
					if(value.filename == "README.md") then
						hasReadme = true;
						break;
					end
				end

				if(not hasReadme) then
					local filePath = SyncMain.worldDir .. "README.md";
					local file = ParaIO.open(filePath, "w");
					local content = "made by http://www.paracraft.cn/";

					file:write(content,#content);
					file:close();

					--LOG.std(nil,"debug","filePath",filePath);

					local readMeFiles = {
						filename       = "README.md",
						file_path      = Encoding.DefaultToUtf8(SyncMain.worldDir) .. "README.md",
						file_content_t = content
					};

					--LOG.std(nil,"debug","localFiles",readMeFiles);

					SyncMain.localFiles[#SyncMain.localFiles + 1] = readMeFiles;
				end

				totalLocalIndex  = #SyncMain.localFiles;
				syncGUItotal     = #SyncMain.localFiles;

				for i=1,#SyncMain.localFiles do
					-- LOG.std(nil,"debug","localFiles",self.localFiles[i]);
					SyncMain.localFiles[i].needChange = true;
					i = i + 1;
				end

				if (err ~= 409 and err ~= 404) then --409代表已经创建过此仓
					dataSourceFiles = data;

					LOG.std(nil,"debug","syncGUItotal",syncGUItotal);

					totalDataSourceIndex = #dataSourceFiles;

					LOG.std(nil,"debug","dataSourceFilesERR",err .. " success!");
					updateOne();
				else
					--if the repos is empty, then upload files 
					uploadOne();
				end
			end);
		end
	end

	if(test)then
		syncToDataSourceGo();
		return;
	end

	------------------------------------------------------------------------

	if(SyncMain.firstCreate) then
		SyncMain:create(SyncMain.foldername,function(data, err)
			--LOG.std(nil,"debug","SyncMain:create",data);
			--LOG.std(nil,"debug","SyncMain:create",err);

			if(data == true or err == 422 or err == 201) then
				syncToDataSourceGo();
			else
				--if(data.name ~= self.foldername) then
				_guihelper.MessageBox(L"数据源创建失败");
				syncToDataSourceGUI.finish();
				return;
				--end
			end
		end);
	else
		LOG.std(nil,"debug","SyncMain:syncToGithub","非首次同步");

		if(login.dataSourceType == "gitlab") then
			if(SyncMain.worldName) then
				GitlabService.projectId = WorldShare:GetWorldData("gitLabProjectId", SyncMain.worldName);
			else
				GitlabService.projectId = WorldShare:GetWorldData("gitLabProjectId");
			end
			
		end

		syncToDataSourceGo();
	end
end

function SyncMain:genWorldMD(worldInfor)
	local function gen(keepworkId)
		SyncMain:getFileShaListService(worldInfor.worldName, function(data, err)
			--LOG.std(nil,"debug","genWorldMD",data);
			local hasIndex      = false;
			local hasWorldFile  = false;
			local indexPath     = "";
			local worldFilePath = "";
			local worldUrl      = "";
			local username      = "";
			SyncMain.indexFile  = "";
			SyncMain.worldFile  = "";

			if(login.dataSourceType == "gitlab") then
				username = login.dataSourceUsername:gsub("gitlab_" , "");
				worldUrl = "http://git.keepwork.com/" .. login.dataSourceUsername .. "/keepworkdatasource/repository/archive.zip?ref=master";
			else

			end

			local indexPath     =  username .. "/paracraft/index";
			local worldFilePath =  username .. "/paracraft/world_" .. worldInfor.worldsName;

			for key,value in ipairs(data) do
				if(value.path == indexPath) then
					hasIndex = true;
				end

				if(value.path == worldFilePath) then
					hasWorldFile = true;
				end
			end
			
			local function updateTree()
				SyncMain:refreshWikiPages(indexPath, SyncMain.indexFile, function(data, err) 
					SyncMain:refreshWikiPages(worldFilePath, SyncMain.worldFile, function(data, err) end)
				end)
			end

			local function updateIndexFile(_next)
				LOG.std(nil,"debug","hasIndexO",hasIndex);
				if(hasIndex) then
					LOG.std(nil,"debug","hasIndex",hasIndex);
					SyncMain:getDataSourceContent(worldInfor.worldsName, indexPath, function(data, err)
						--LOG.std(nil,"debug","getDataSourceContent",data);
						--LOG.std(nil,"debug","getDataSourceContent",err);

						--local content = Encoding.unbase64(data);
						--local paramsText = KeepworkGen:GetContent(content);
						--local params = KeepworkGen:getCommand("worldList", paramsText);

						local worldList = SyncMain.remoteWorldsList;

						worldList = KeepworkGen:setCommand("worldList",worldList);
						SyncMain.indexFile = KeepworkGen:SetAutoGenContent("", worldList)

						LOG.std(nil,"debug","SyncMain.indexFile",SyncMain.indexFile);

						SyncMain:updateService(
							worldInfor.worldsName,
							indexPath,
							SyncMain.indexFile,
							"",
							function(isSuccess, path)
								LOG.std(nil,"debug","updateService-indexFile",isSuccess)
								LOG.std(nil,"debug","updateService-indexFile",path)
								_next(updateTree);
							end,
							keepworkId
						);
					end, keepworkId)
				else
					local worldList = SyncMain.remoteWorldsList;

					worldList = KeepworkGen:setCommand("worldList",worldList);
					SyncMain.indexFile = KeepworkGen:SetAutoGenContent("", worldList);

					LOG.std(nil,"debug","SyncMain.indexFile",SyncMain.indexFile);

					SyncMain:uploadService(
						worldInfor.worldsName,
						indexPath,
						SyncMain.indexFile,
						function(data, err) 
							_next(updateTree);
						end,
						keepworkId
					);
				end
			end
			
			local function updateWorldFile(_next)
				if(hasWorldFile) then
					LOG.std(nil,"debug","hasWorldFile",hasWorldFile);
					SyncMain:getDataSourceContent(worldInfor.worldsName, worldFilePath, function(data, err)
						local content    = Encoding.unbase64(data);
						local paramsText = KeepworkGen:GetContent(content);
						local params     = KeepworkGen:getCommand("world3D", paramsText);

						--if(params.version ~= worldInfor.revision) then
						local world3D = {
							worldName	  = worldInfor.worldsName,
							worldUrl	  = worldUrl,
							logoUrl		  = worldInfor.preview,
							desc		  = "",
							username	  = username,
							visitCount    = 1,
							favoriteCount = 1,
							updateDate	  = worldInfor.modDate,
							version		  = worldInfor.revision
						}

						world3D = KeepworkGen:setCommand("world3D",world3D);
						SyncMain.worldFile = KeepworkGen:SetAutoGenContent(content, world3D);

						LOG.std(nil,"debug","worldFile",SyncMain.worldFile);

						SyncMain:updateService(
							worldInfor.worldsName,
							worldFilePath,
							SyncMain.worldFile,
							"",
							function(isSuccess, path)
								LOG.std(nil,"debug","updateService-worldFile",isSuccess)
								LOG.std(nil,"debug","updateService-worldFile",path)
								_next();
							end,
							keepworkId
						);
						--end
					end, keepworkId)
				else
					LOG.std(nil,"debug","hasWorldFile",hasWorldFile);
					local world3D = {
						worldName	  = worldInfor.worldsName,
						worldUrl	  = worldUrl,
						logoUrl		  = worldInfor.preview,
						desc		  = "",
						username	  = username,
						visitCount    = 1,
						favoriteCount = 1,
						updateDate	  = worldInfor.modDate,
						version		  = worldInfor.revision
					}

					world3D = KeepworkGen:setCommand("world3D",world3D);

					SyncMain.worldFile = KeepworkGen:SetAutoGenContent("", world3D)
					SyncMain.worldFile = SyncMain.worldFile .. "\n\r" .. worldInfor.readme;
					SyncMain.worldFile = SyncMain.worldFile .. "\n\r" .. KeepworkGen:setCommand("comment");

					LOG.std(nil,"debug","worldFile",SyncMain.worldFile);
				
					SyncMain:uploadService(
						worldInfor.worldsName,
						worldFilePath,
						SyncMain.worldFile,
						function(data, err) 
							_next();
						end,
						keepworkId
					);
				end
			end

			updateIndexFile(updateWorldFile);
		end, keepworkId);
	end

	if(login.dataSourceType == "github") then
		gen();
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:getProjectIdByName("keepworkDataSource",function(keepworkId)
			gen(keepworkId);
		end);
	end
end

function SyncMain:refreshWikiPages(_path, _content, _callback)
	LOG.std(nil,"debug","_content",_content);
	HttpRequest:GetUrl({
		url  = login.site.."/api/wiki/models/website_pageinfo/getByUsername",
		json = true,
		headers = {Authorization = "Bearer "..login.token},
		form = {username = login.username},
	},function(data, err)
		LOG.std(nil,"debug","getUserPages",data);
		local pageinfoList = data.data.pageinfoList[1];

		local params = {};
		NPL.FromJson(pageinfoList, params);

		pageinfoList    = params;
		newPageinfoList = {};

		local hasFile = false;
		local hasFileContent = {};

		for key,value in ipairs(pageinfoList) do
			if(value.url == "/" .. _path) then
				hasFile     = true;	
				hasFileInfo = value;
			else
				newPageinfoList[#newPageinfoList + 1] = value;
			end
		end

		LOG.std(nil,"debug","_path",_path);
		LOG.std(nil,"debug","_content",_content);
		LOG.std(nil,"debug","hasFile",hasFile);
		LOG.std(nil,"debug","hasFileContent",hasFileContent);
		LOG.std(nil,"debug","pageinfoList",pageinfoList);

		if(hasFile) then
			hasFileInfo.timestamp = os.time() .. "000";
			hasFileInfo.content   = _content;
			hasFileInfo.isModify  = true;

			newPageinfoList[#newPageinfoList + 1] = hasFileInfo;
		else
			LOG.std(nil,"debug","os", os.time() .. "000");

			local thisInfor = {};

			thisInfor.timestamp    = os.time() .. "000";
			thisInfor.websiteName  = "paracraft";
			thisInfor.userId	   = login.userId;
			thisInfor.dataSourceId = login.dataSourceId;
			thisInfor.isModify	   = false;
			thisInfor.username	   = login.username;
			thisInfor.name	       = _path;
			thisInfor.url		   = "/" .. _path;
			thisInfor.content      = _content;

			newPageinfoList[#newPageinfoList + 1] = thisInfor;
		end

		LOG.std(nil,"debug","newPageinfoList",newPageinfoList);

		newPageinfoList = NPL.ToJson(newPageinfoList,true);

		local params = {};
		params.dataSourceId = login.dataSourceId;
		params.isExistSite  = 1;
		params.pageinfo     = newPageinfoList;
		params.username     = login.username;
		params.websiteName  = "paracraft";

		HttpRequest:GetUrl({
			url  = login.site.."/api/wiki/models/website_pageinfo/upsert",
			json = true,
			headers = {Authorization = "Bearer "..login.token},
			form = params,
		},_callback)
	end);
end

function SyncMain.deleteWorld()
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/WorldShare/sync/DeleteWorld.html",
		name = "DeleteWorld", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ct",
			x = -500/2,
			y = -270/2,
			width = 500,
			height = 270,
		cancelShowAnimation = true,
	});
end

function SyncMain.deleteWorldLocal(_callback)
	local world = InternetLoadWorld:GetCurrentWorld();
	
	if(not world) then
		_guihelper.MessageBox(L"请先选择世界");
		return;
	end

	_guihelper.MessageBox(format(L"确定删除本地世界:%s?", world.text or ""), function(res)
		if(res and res == _guihelper.DialogResult.Yes) then
			if(world.RemoveLocalFile and world:RemoveLocalFile()) then
				InternetLoadWorld.RefreshAll();
			elseif(world.remotefile) then
				local targetDir = world.remotefile:gsub("^local://", ""); -- local world, delete all files in folder and the folder itself.

				if(GameLogic.RemoveWorldFileWatcher) then
					GameLogic.RemoveWorldFileWatcher(); -- file watcher may make folder deletion of current world directory not working.
				end

				if(commonlib.Files.DeleteFolder(targetDir)) then  
					local foldername = SyncMain.selectedWorldInfor.foldername;
					SyncMain.handleCur_ds = {};

					local hasRemote = false;
					for key,value in ipairs(InternetLoadWorld.cur_ds) do
						if(value.foldername == foldername and value.status == 3 or value.status == 4 or value.status == 5) then
							value.status = 2;
							hasRemote = true;
							break;
						end

						if(value.foldername ~= foldername) then
							SyncMain.handleCur_ds[#SyncMain.handleCur_ds + 1] = value;
						end
					end

					if (not hasRemote) then
						InternetLoadWorld.cur_ds = login.handleCur_ds;
					end

					if(type(_callback) == 'function') then
						_callback(foldername);
					else
						Page:CloseWindow();

	                    if(not WorldCommon.GetWorldInfo()) then
	                        MainLogin.state.IsLoadMainWorldRequested = nil;
	                        MainLogin:next_step();
	                    end
					end
				else
					_guihelper.MessageBox(L"无法删除可能您没有足够的权限"); 
				end
			end
		end
	end, _guihelper.MessageBoxButtons.YesNo);
end

function SyncMain.deleteWorldRemote()
	if(login.dataSourceType == "github") then
		SyncMain.deleteWorldGithubLogin();
	elseif(login.dataSourceType == "gitlab") then
		SyncMain.deleteWorldGitlab();
	end
end

function SyncMain.deleteWorldGithubLogin()
	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/WorldShare/sync/DeleteWorldGithub.html", 
		name = "DeleteWorldLogin", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ct",
			x = -500/2,
			y = -270/2,
			width = 500,
			height = 270,
		cancelShowAnimation = true,
	});
end

function SyncMain.deleteWorldGithub(_password)
	local foldername = SyncMain.selectedWorldInfor.foldername;
	foldername = Encoding.Utf8ToDefault(foldername);

	local AuthUrl    = "https://api.github.com/authorizations";
	local AuthParams = {
		scopes = {
			"delete_repo",
		},
		note   = ParaGlobal.timeGetTime(),
	};
	local basicAuth  = login.dataSourceUsername .. ":" .. _password;
	local AuthToken  = "";

	basicAuth = Encoding.base64(basicAuth);

	HttpRequest:GetUrl({
		url     = AuthUrl,
		json    = true,
		headers = {
			Authorization    = "Basic " .. basicAuth,
			["User-Agent"]   = "npl",
			["content-type"] = "application/json"
		},
		form    = AuthParams
    },function(data,err)
    	local basicAuthData = data;
    	AuthToken = basicAuthData.token;

	    _guihelper.MessageBox(format(L"确定删除Gihub远程世界:%s?", foldername or ""), function(res)
	    	Page:CloseWindow();

	    	if(res and res == 6) then
	    		GithubService:deleteResp(foldername, AuthToken, function(data,err)
	    			--LOG.std(nil,"debug","GithubService:deleteResp",err);
	    			if(err == 204) then
	    				SyncMain.deleteKeepworkWorldsRecord();
	    			else
						_guihelper.MessageBox(L"远程仓库不存在，请联系管理员");
						if(not WorldCommon.GetWorldInfo()) then
							MainLogin.state.IsLoadMainWorldRequested = nil;
							MainLogin:next_step();
						end
					end
	    		end)
	    	end
	    end);
	end)
end

function SyncMain.deleteWorldGitlab()
	local foldername = SyncMain.selectedWorldInfor.foldername;
	
	for key,value in ipairs(SyncMain.remoteWorldsList) do
		if(value.worldsName == foldername) then
			GitlabService.projectId = value.gitlabProjectId;
		end
	end

	_guihelper.MessageBox(format(L"确定删除Gitlab远程世界:%s?", foldername or ""), function(res)
	    Page:CloseWindow();

	    if(res and res == 6) then
	    	GitlabService:deleteResp(foldername, function(data, err)
				if(err == 202) then
					SyncMain.deleteKeepworkWorldsRecord();
				else
					_guihelper.MessageBox(L"远程仓库不存在，请联系管理员");
					if(not WorldCommon.GetWorldInfo()) then
						MainLogin.state.IsLoadMainWorldRequested = nil;
						MainLogin:next_step();
					end
				end
			end);
	    end
	end);
end

function SyncMain.deleteKeepworkWorldsRecord()
	local foldername = SyncMain.selectedWorldInfor.foldername;
	local url = login.site .. "/api/mod/worldshare/models/worlds";

	LOG.std(nil,"debug","deleteKeepworkWorldsRecord",url);
	LOG.std(nil,"debug","deleteKeepworkWorldsRecord",foldername);
	LOG.std(nil,"debug","deleteKeepworkWorldsRecord",login.toke);

	HttpRequest:GetUrl({
		method  = "DELETE",
		url     = url,
		form    = {
			worldsName = foldername,
		},
		json    = true,
		headers = {
			Authorization = "Bearer " .. login.token,
		},
	},function(data, err)
		LOG.std(nil,"debug","deleteKeepworkWorldsRecord",data)
		LOG.std(nil,"debug","deleteKeepworkWorldsRecord",err)

		if(err == 204) then
			SyncMain.handleCur_ds = {};

			local hasLocal = false;
			for key,value in ipairs(InternetLoadWorld.cur_ds) do
				if(value.foldername == foldername and value.status == 3 or value.status == 4 or value.status == 5) then
					value.status = 1;
					hasLocal = true;
					break;
				end

				if(value.foldername ~= foldername) then
					SyncMain.handleCur_ds[#SyncMain.handleCur_ds + 1] = value;
				end
			end

			if(not hasLocal)then
				InternetLoadWorld.cur_ds = SyncMain.handleCur_ds;
			end

			LOG.std(nil,"debug","InternetLoadWorld.cur_ds",InternetLoadWorld.cur_ds);

			Page:CloseWindow();

			if(not WorldCommon.GetWorldInfo()) then
				MainLogin.state.IsLoadMainWorldRequested = nil;
				MainLogin:next_step();
			end
		end
	end);
end

function SyncMain.deleteWorldAll()
	SyncMain.deleteWorldLocal(function()
		SyncMain.deleteWorldRemote();
	end);
end

function SyncMain:create(_foldername,_callback)
	if(login.dataSourceType == "github") then
		GithubService:create(_foldername,_callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:init(_foldername,_callback);
	end
end

function SyncMain:getDataSourceContent(_foldername, _path, _callback, _projectId)
	if(login.dataSourceType == "github") then
		GithubService:getContent(_foldername, _path, _callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:getContent(_path, _callback,_projectId);
	end
end

function SyncMain:uploadService(_foldername,_filename,_file_content_t,_callback, _projectId)
	if(login.dataSourceType == "github") then
		GithubService:upload(_foldername,_filename,_file_content_t,_callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:writeFile(_filename,_file_content_t,_callback, _projectId);
	end
end

function SyncMain:updateService(_foldername, _filename, _file_content_t, _sha, _callback, _projectId)
	if(login.dataSourceType == "github") then
		GithubService:update(_foldername, _filename, _file_content_t, _sha, _callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:update(_filename, _file_content_t, _sha, _callback, _projectId);
	end
end

function SyncMain:deleteFileService(_foldername, _path, _sha, _callback)
	if(login.dataSourceType == "github") then
		GithubService:deleteFile(_foldername, _path, _sha, _callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:deleteFile(_path, _sha, _callback);
	end
end

function SyncMain:getFileShaListService(_foldername, _callback, _projectId)
	if(login.dataSourceType == "github") then
		GithubService:getFileShaList(_foldername, _callback);
	elseif(login.dataSourceType == "gitlab") then
		GitlabService:getTree(_callback, _projectId);
	end
end