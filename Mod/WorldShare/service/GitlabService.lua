--[[
Title: GitlabService
Author(s):  big
Date:  2017.4.15
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/WorldShare/service/GitlabService.lua");
local GitlabService = commonlib.gettable("Mod.WorldShare.service.GitlabService");
------------------------------------------------------------
]]

NPL.load("(gl)Mod/WorldShare/service/HttpRequest.lua");
NPL.load("(gl)Mod/WorldShare/login/LoginMain.lua");
NPL.load("(gl)Mod/WorldShare/main.lua");
NPL.load("(gl)script/ide/Encoding.lua");
NPL.load("(gl)Mod/WorldShare/sync/SyncMain.lua");

local HttpRequest   = commonlib.gettable("Mod.WorldShare.service.HttpRequest");
local loginMain     = commonlib.gettable("Mod.WorldShare.login.loginMain");
local GitEncoding   = commonlib.gettable("Mod.WorldShare.helper.GitEncoding");
local WorldShare    = commonlib.gettable("Mod.WorldShare");
local Encoding      = commonlib.gettable("commonlib.Encoding");
local SyncMain      = commonlib.gettable("Mod.WorldShare.sync.SyncMain");

local GitlabService = commonlib.gettable("Mod.WorldShare.service.GitlabService");

GitlabService.inited  = false;
GitlabService.tree    = {};
GitlabService.newTree = {};
GitlabService.blob    = {};
GitlabService.getTreePage     = 1;
GitlabService.getTreePer_page = 100;

function GitlabService:checkSpecialCharacter(_filename)
	local specialCharacter = {"【" , "】" , "《" , "》" , "·" , " ", "，", "●"};

	for key, item in pairs(specialCharacter) do
		if(string.find(_filename,item)) then
			commonlib.TimerManager.SetTimeout(function()
				_guihelper.MessageBox(_filename .. "文件包含了特殊字符或空格，请重命名文件，否则无法上传。");
			end,500);
			
			return true;
		end
	end

	return false;
end

function GitlabService:checkProjectId(_projectId, _foldername, _callback)
	if(not _projectId) then
		_projectId = GitlabService.projectId;
	end

	if(not _projectId) then
		if(_foldername) then
			GitlabService:getProjectIdByName(_foldername,function(projectId)
				if(projectId) then
					GitlabService.projectId = projectId;
					
					if(_callback)then
						_callback(projectId);
					end
				else
					LOG.std("GitlabService","debug","GetProjecIdFail","Reson: %s, ProjectName: %s","没有匹配到仓名",_foldername);
					_guihelper.MessageBox(L"获取projectId失败");
				end
			end);
		else
			LOG.std("GitlabService","debug","GetProjecIdFail","Reson: %s","没有仓名传入");
			_guihelper.MessageBox(L"获取projectId失败");
		end
	else
		if(_callback)then
			_callback(_projectId);
		end
	end
end

function GitlabService:apiGet(_url, _callback)
	_url = loginMain.apiBaseUrl .. "/" .._url

	--LOG.std(nil,"debug","apiGet-url",_url);
	HttpRequest:GetUrl({
		url     = _url,
		json    = true,
		headers = {
			["PRIVATE-TOKEN"] = loginMain.dataSourceToken,
			["User-Agent"]    = "npl",
		},
	},function(data ,err) 
		--LOG.std(nil,"debug","GitlabService:apiGet-data",data);
		--LOG.std(nil,"debug","GitlabService:apiGet-err",err);
		if(_callback) then
			_callback(data, err);
		end
	end);
end

function GitlabService:apiPost(_url, _params, _callback)
	_url = loginMain.apiBaseUrl .. "/" .._url

	HttpRequest:GetUrl({
		method    = "POST",
		url       = _url,
		json      = true,
		headers   = {
			["PRIVATE-TOKEN"] = loginMain.dataSourceToken,
			["User-Agent"]    = "npl",
			["content-type"]  = "application/json"
		},
		form = _params,
	},function(data ,err)
		--LOG.std(nil,"debug","GitlabService:apiPost-data",data);
		--LOG.std(nil,"debug","GitlabService:apiPost-err",err);
		_callback(data, err);
	end);
end

function GitlabService:apiPut(_url, _params, _callback)
	_url = loginMain.apiBaseUrl .. "/" .._url

	HttpRequest:GetUrl({
		method     = "PUT",
		url        = _url,
		json       = true,
	  	headers    = {
		  	["PRIVATE-TOKEN"] = loginMain.dataSourceToken,
			["User-Agent"]    = "npl",
			["content-type"]  = "application/json"
		},
		form = _params
	},function(data ,err) 
		--LOG.std(nil,"debug","GitlabService:apiPut-data",data);
		--LOG.std(nil,"debug","GitlabService:apiPut-err",err);
		_callback(data, err);
	end);
end

function GitlabService:apiDelete(_url, _params, _callback)
	_url = loginMain.apiBaseUrl .. "/" .._url

	local github_token = loginMain.dataSourceToken;
	
	--LOG.std(nil,"debug","GitlabService:apiDelete-token",github_token);
	--LOG.std(nil,"debug","GitlabService:apiDelete-_url",_url);

	HttpRequest:GetUrl({
		method     = "DELETE",
		url        = _url,
		json       = true,
	  	headers    = {
	  		["PRIVATE-TOKEN"] = loginMain.dataSourceToken,
			["User-Agent"]    = "npl",
			["content-type"]  = "application/json"
		},
		form = _params,
	},function(data ,err) 
		--LOG.std(nil,"debug","GitlabService:apiDelete-data",data);
		--LOG.std(nil,"debug","GitlabService:apiDelete-err",err);
		_callback(data, err);
	end);
end

function GitlabService:getFileUrlPrefix(_projectId)
    return 'projects/' .. _projectId .. '/repository/files/';
end

function GitlabService:getCommitMessagePrefix()
    return "keepwork commit: ";
end

-- 获得文件列表
function GitlabService:getTree(_callback, _commitId, _projectId, _foldername)
	local function go(_projectId)
		local url = 'projects/' .. _projectId .. '/repository/tree?';
	
		if(_commitId) then
			url = url .. "?ref=" .. _commitId;
		end

		--LOG.std(nil,"debug","GitlabService:getTree-url",url);

		GitlabService.blob = {};
		GitlabService.tree = {};

		GitlabService:getTreeApi(url, function(data, err)
			--LOG.std(nil,"debug","GitlabService:getTree-data",data);
			--LOG.std(nil,"debug","GitlabService:getTree-err",err);

			if(err == 404) then
				if(_callback) then
					_callback(data, err);
				end
			else
				if(type(data) == "table") then
					for key,value in ipairs(data) do
						if(value.type == "tree") then
							GitlabService.tree[#GitlabService.tree + 1] = value;
						end

						if(value.type == "blob") then
							GitlabService.blob[#GitlabService.blob + 1] = value;
						end
					end

					local fetchTimes = 0;
					--LOG.std(nil,"debug","GitlabService.tree",GitlabService.tree);
					--LOG.std(nil,"debug","GitlabService.blob",GitlabService.blob);

					local function getSubTree()
						if(#GitlabService.tree ~= 0) then
							--echo("不等");
							for key, value in ipairs(GitlabService.tree) do
								GitlabService:getSubTree(function(subTree, subFolderName, _commitId, _projectId)
									--echo(subTree);
									--echo(subFolderName);
									--echo(_commitId);
									--echo(_projectId);

									for checkKey, checkValue in ipairs(GitlabService.tree) do
										if(checkValue.path == subFolderName) then
											if(not checkValue.alreadyGet) then
												checkValue.alreadyGet = true;
											else
												return;
											end
										end
									end

									fetchTimes = fetchTimes + 1;

									for subKey, subValue in ipairs(subTree) do
										GitlabService.newTree[#GitlabService.newTree + 1] = subValue;
									end

									if(#GitlabService.tree == fetchTimes)then
										fetchTimes = 0;
										GitlabService.tree = commonlib.copy(GitlabService.newTree);
										GitlabService.newTree = {};

										getSubTree();
									end
								end, value.path, _commitId, _projectId);
							end
						elseif(#GitlabService.tree == 0) then
							--echo("等");
							for cbKey,cbValue in ipairs(GitlabService.blob) do
								cbValue.sha = cbValue.id;
							end

							--echo(GitlabService.blob);

							if(_callback) then
								_callback(GitlabService.blob, 200);
							end
						end
					end

					getSubTree();
				else
					_guihelper.MessageBox(L"获取sha文件失败");
				end
			end
		end);
	end
	
	GitlabService:checkProjectId(_projectId, _foldername, go);
end

function GitlabService:getSubTree(_callback, _path, _commitId, _projectId)
	local url = 'projects/' .. _projectId .. '/repository/tree' .. "?path=" .. _path;
	
	if(_commitId) then
		url = url .. "&ref=" .. _commitId;
	end
	
	local tree = {};
	GitlabService:getTreeApi(url, function(data, err)
		for key,value in ipairs(data) do
			if(value.type == "tree") then
				tree[#tree + 1] = value;
			end

			if(value.type == "blob") then
				GitlabService.blob[#GitlabService.blob + 1] = value;
			end
		end

		if(_callback) then
			_callback(tree, _path, _commitId, _projectId);
		end
	end);
end

function GitlabService:getTreeApi(_url, _callback)
	local url = _url .. "&page=" .. GitlabService.getTreePage .. "&per_page=" .. GitlabService.getTreePer_page;
	--echo(url);

	GitlabService:apiGet(url, function(data, err)
		--echo(data);
		
		if(#data == 0)then
			GitlabService.getTreePage = 1;

			if(GitlabService.tmpTree) then
				if(_callback) then
					_callback(GitlabService.tmpTree, err);
				end
			else
				if(_callback) then
					_callback(data, err);
				end
			end

			GitlabService.tmpTree = nil;
		else
			if(GitlabService.tmpTree) then
				for _, value in ipairs(data) do
					GitlabService.tmpTree[#GitlabService.tmpTree + 1] = value;
				end
			else
				GitlabService.tmpTree = data;
			end

			GitlabService.getTreePage = GitlabService.getTreePage + 1;
			GitlabService:getTreeApi(_url, _callback);
		end
	end)
end

-- commit
function GitlabService:listCommits(_callback, _projectId, _foldername)
	local function go(_projectId)
		local url = 'projects/' .. _projectId .. '/repository/commits';
		GitlabService:apiGet(url, _callback);
	end

	GitlabService:checkProjectId(_projectId, _foldername, go);
end

-- 写文件
function GitlabService:writeFile(filename, content, callback, projectId, foldername) --params, cb, errcb
	local function go(projectId)
		--[[if(GitlabService:checkSpecialCharacter(_filename)) then
			_callback(false, _filename);
			return;
		end]]

		local url = GitlabService:getFileUrlPrefix(projectId) .. Encoding.url_encode(filename);
		--LOG.std(nil,"debug","GitlabService:writeFile",url);

		local params = {
			commit_message = GitlabService:getCommitMessagePrefix() .. filename,
			branch		   = "master",
			content 	   = content,
		}

		LOG.std("GitlabService","debug","GitlabService:writeFile", #content);

		GitlabService:apiPost(url, params, function(data, err)
			LOG.std(nil,"debug","GitlabService:writeFile",data);
			LOG.std(nil,"debug","GitlabService:writeFile",err);

			if(err == 201 and type(callback) == "function") then
				callback(true, filename, data, err);
			else
				GitlabService:update(filename, content, sha, callback, projectId);
			end
		end);
	end

	GitlabService:checkProjectId(projectId, foldername, go);
end

--更新文件
function GitlabService:update(filename, content, sha, callback, projectId, foldername)
	local function go(projectId)
		--[[if(GitlabService:checkSpecialCharacter(_filename)) then
			_callback(false, _filename);
			return;
		end]]

		local url = GitlabService:getFileUrlPrefix(projectId) .. Encoding.url_encode(filename);

		local params = {
			commit_message = GitlabService:getCommitMessagePrefix() .. filename,
			branch		   = "master",
			content 	   = content,
		}

		GitlabService:apiPut(url, params, function(data, err)
			--LOG.std(nil,"debug","GitlabService:update",data);
			--LOG.std(nil,"debug","GitlabService:update",err);

			if(err == 200) then
				if(type(callback) == "function") then
					callback(true, filename, data, err);
				end
			else
				if(type(callback) == "function") then
					callback(false, filename, data, err);
				end
			end
		end);
	end

	GitlabService:checkProjectId(projectId, foldername, go);
end

-- 获取文件
function GitlabService:getContent(_path, _callback, _projectId)
    local url = GitlabService:getFileUrlPrefix(_projectId) .. _path .. '?ref=master';

	--LOG.std(nil,"debug","apiGet-url",url);
	GitlabService:apiGet(url, function(data, err)
		--LOG.std(nil,"debug","apiGet-data",data);
		--LOG.std(nil,"debug","apiGet-err",err);

		_callback(data.content, err);
	end);
end

-- 获取文件
function GitlabService:getContentWithRaw(_foldername, _path, _callback)
	local foldername = GitEncoding.base32(_foldername);

	local url  = loginMain.rawBaseUrl .. "/" .. loginMain.dataSourceUsername .. "/" .. foldername .. "/raw/master/" .. _path;

	HttpRequest:GetUrl({
		url     = url,
		json    = true,
		headers = {
			["PRIVATE-TOKEN"] = loginMain.dataSourceToken,
			["User-Agent"]    = "npl",
		},
	},function(data, err)
		if(err == 200) then
			_callback(data, err);
		end
	end);
end

-- 删除文件
function GitlabService:deleteFile(_path, _sha, _callback, _projectId, _foldername)
	local function go(_projectId)
		local url = GitlabService:getFileUrlPrefix(_projectId) .. _path;

		local params = {
			commit_message = GitlabService:getCommitMessagePrefix() .. _path,
			branch         = 'master',
		}

		--LOG.std(nil,"debug","deleteFile",url);
		GitlabService:apiDelete(url, params, function(data, err)
			--LOG.std(nil,"debug","deleteFile",data);
			--LOG.std(nil,"debug","deleteFilerr",err);

			if(err == 204) then
				if(type(_callback) == "function") then
					_callback(true);
				end
			else
				if(type(_callback) == "function") then
					_callback(false);
				end
			end
		end);
	end
   
	GitlabService:checkProjectId(_projectId, _foldername, go);
end

--删除仓
function GitlabService:deleteResp(_foldername, _callback, _projectId)
	local function go(_projectId)
		local url = "/projects/" .. _projectId;
		GitlabService:apiDelete(url, {}, _callback);
	end

	GitlabService:checkProjectId(_projectId, _foldername, go);
end

--通过仓名获取仓ID
function GitlabService:getProjectIdByName(_name, _callback)
	local url = "projects";
	
	GitlabService:apiGet(url .. "?owned=true&page=1&per_page=100",function(projectList, err)
		--echo(projectList);
		for i=1,#projectList do
            if (string.lower(projectList[i].name) == string.lower(_name)) then
				if(_callback) then
					_callback(projectList[i].id);
				end
				return;
			end
		end

		if(_callback) then
			_callback(false);
		end
	end);
end

-- 初始化
function GitlabService:init(_foldername, _callback)
	local url   = "projects";

	GitlabService:apiGet(url .. "?owned=true&page=1&per_page=100",function(projectList, err)
		if(projectList) then
			for i=1,#projectList do
				if (projectList[i].name == _foldername) then
					GitlabService.projectId = projectList[i].id;

					if(_callback) then
						_callback(true, "exist");
					end

					return;
				end
			end

			local params = {
				name = _foldername,
				request_access_enabled = true,
				visibility = "public",
			};

			GitlabService:apiPost(url, params, function(data,err)
				if(data.id ~= nil) then
					GitlabService.projectId = data.id;
					--LOG.std(nil,"debug","GitlabService.projectId",GitlabService.projectId);
					--LOG.std(nil,"debug","err",err);
					if(_callback) then
						_callback(true, "create");
					end
					
					return;
				end
			end);
		else
			_callback(false,err);
		end
	end);
end
