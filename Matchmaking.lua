-- VARS
local d = false

if game.VIPServerId ~= "" then
	warn("HEY GUYS")
	d = true
end

warn(d)

if d then
	return {}
end

local Webhook = require(script.Webhook)

local DataStoreService = game:GetService("DataStoreService")

local MemoryStoreService = game:GetService("MemoryStoreService")

local Settings = require(script.Settings)

local TeleportService = game:GetService("TeleportService")

local MMVD = game.ReplicatedStorage.MatchmakingDown

local framework = require(game.ReplicatedStorage.Modules.M3WS_FRAMEWORK)
local remotehandler = framework.GetService("RemoteHandler")

local PlayersInMatch = MemoryStoreService:GetSortedMap("PlayersInMatch")

local EST_MATCH_QUEUES = MemoryStoreService:GetSortedMap("EST_TIMES2")

local SafeTeleport = require(script.SafeTeleport)

--local MemoryStoreService = game:GetService("MemoryStoreService")  local ServerControlingStore = MemoryStoreService:GetSortedMap("ServerControlingID_V41") CurrentID=ServerControlingStore:GetAsync("ServerControlingID_V41") print(CurrentID[1])
--local m = Instance.new("Message") m.Parent = workspace m.Text = "READY UP" task.wait(60) m:Destroy()


-- INFO

local ServerID = game.JobId

local ControllingID = nil



local ServerControlingStore = MemoryStoreService:GetSortedMap(Settings.ServerControlingID)

local module = {}

module.Loaded = false

module.ShuttingDown = false

module.SquadsBeingTeleported = {}
module.SquadsInQueue = {}

module.QueueInfo = {}


local Queues = {}

local LastingTime = 30

local retryTime = 4


local TIME = 8


local function CreateMatch()
	return TeleportService:ReserveServer(Settings.TeleportTo)
end


local function MatchmakingDown()
	MMVD.Value = true
	warn("[MATCHMAKING]: ".."⛔ IS DOWN⚠️")
end

local function GetCurrentID()
	local Tries = 0
	local CurrentID
	local s,e
	repeat
		Tries += 1
		s,e=pcall(function()
			CurrentID=ServerControlingStore:GetAsync(Settings.ServerControlingID)
		end)
	until s or Tries > 3
	return CurrentID , e
end


local function WaitLoaded()
	repeat
		task.wait()
	until module.Loaded
end


local function SoloTeleport(player)
	local plr = game.Players:GetPlayerByUserId(player.UserId)

	if plr then
		plr:SetAttribute("Teleporting",true)

		remotehandler.FireClient(plr,"StartingMatch","Preparing...")

		game.ServerStorage.ReleaseData:Fire(plr)

		if not plr:GetAttribute("HopReady") then
			plr:GetAttributeChangedSignal("HopReady"):Wait()
		end

		remotehandler.FireClient(plr,"StartingMatch","Initializing teleport...")

		spawn(function()
			local MATCH_ID=CreateMatch()
			local TeleportData = {PartyID = nil,PlayersTeleported=1,MATCH_ID=MATCH_ID,GameMode="Solos"}
			local ReservedID = MATCH_ID

			remotehandler.FireClient(plr,"Teleporting")
			repeat
				task.wait()
			until plr:GetAttribute("ReadyTeleport") == true or not plr:IsDescendantOf(game.Players) 

			if not plr:IsDescendantOf(game.Players) then
				return
			end


			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode=ReservedID


			options:SetTeleportData(TeleportData)

			local s = SafeTeleport(Settings.TeleportTo,{plr},options)

			if plr:IsDescendantOf(game.Players) and s then
				remotehandler.FireClient(plr,"StartingMatch","Waiting for matchmaking to commence...")
			else
				remotehandler.FireClient(plr,"StartingMatch","Something went wrong try again!")
			end


		end)
	end
end


remotehandler.HearEvent("SoloTest",function(plr)
	SoloTeleport(plr)	
end)


local function TeleportMatch(Parties,QueueType,MATCH_ID,PlayersTeleported,Mode)

	
	for Index,Party in Parties do
		
		spawn(function()
			local found = false

			module.SquadsBeingTeleported[Party.ID] = true

			local PlayersAtAll = false


			for _,PlayerID in Party.Players do
				local plr = game.Players:GetPlayerByUserId(PlayerID)
				if plr then
					PlayersAtAll = true
					break
				end
			end

			for _,PlayerID in Party.Players do
				spawn(function()
					local plr = game.Players:GetPlayerByUserId(PlayerID)

					if plr then
						plr:SetAttribute("Teleporting",true)

						remotehandler.FireClient(plr,"StartingMatch","Preparing...")

						game.ServerStorage.ReleaseData:Fire(plr)

						if not plr:GetAttribute("HopReady") then
							plr:GetAttributeChangedSignal("HopReady"):Wait()
						end

						remotehandler.FireClient(plr,"StartingMatch","Initializing teleport...")

						spawn(function()
							local TeleportData = {PartyID = Party.ID,PlayersTeleported=PlayersTeleported,MATCH_ID=MATCH_ID,GameMode=Mode}
							local ReservedID = MATCH_ID

							remotehandler.FireClient(plr,"Teleporting")
							repeat
								task.wait()
							until plr:GetAttribute("ReadyTeleport") == true or not plr:IsDescendantOf(game.Players) 

							if not plr:IsDescendantOf(game.Players) then
								return
							end


							local options = Instance.new("TeleportOptions")
							options.ReservedServerAccessCode=ReservedID


							options:SetTeleportData(TeleportData)

							local s = SafeTeleport(Settings.TeleportTo,{plr},options)

							if plr:IsDescendantOf(game.Players) and s then
								remotehandler.FireClient(plr,"StartingMatch","Waiting for matchmaking to commence...")
							else
								remotehandler.FireClient(plr,"StartingMatch","Something went wrong try again!")
							end


						end)
					end
				end)
			end

			spawn(function()
				if PlayersAtAll then
					repeat
						local s , e = pcall(function()
							QueueType:RemoveAsync(Party.ID)
						end)
						if e then
							task.wait(1)
						end
						if s then
							warn("Removed Party!!")
						end
					until s
				end
			end)
		end)
		
	end
end



local function CheckPlayersToTeleport()
	for Name,Queue in pairs(Queues) do
		local PlayersInQueue = nil
		local s , e = pcall(function()
			PlayersInQueue = Queue:GetRangeAsync(Enum.SortDirection.Ascending,100)
		end)
		
		if e then
			spawn(function()
				Webhook:SendMessage("MATCHMAKING_MAIN","getting range async died when trying to get players to teleport","https://cdn.discordapp.com/attachments/759976538895548426/1091131081606045816/1633636.png",16728128,"Erorr message:"..e)
			end)
		end

		if PlayersInQueue then
			local MainInfo = nil

			local MatchPlayers = {}
			
			local Parties = {}


			for i ,v in pairs(PlayersInQueue) do
				if v.key ~= Name.."INFO_" then
					for _,PlayerID in v.value.Players do
						table.insert(MatchPlayers,PlayerID)
					end
					table.insert(Parties,v.value)
				elseif v.key == Name.."INFO_" then
					MainInfo = v.value
				end
			end
			
			module.QueueInfo[Name]={Amount=#MatchPlayers,Teleport=MainInfo and MainInfo.Teleport or false,Updated=os.time()}
			
			if MainInfo and MainInfo.Teleport then
				spawn(function()
					TeleportMatch(Parties,Queue,MainInfo.MATCH_ID,MainInfo.TeleportedPlayers,Name)
				end)					
			end				

		end
	end
end


local QueuesStartTimes = {}

local QueueTimes = {}


local function CheckQueues()
	for  Name , Queue in pairs(Queues) do
		
		
		local PlayersInQueue = nil
		
		local s , e = pcall(function()
			PlayersInQueue = Queue:GetRangeAsync(Enum.SortDirection.Ascending,100)
		end)
		
		if e then
			if e then
				spawn(function()
					Webhook:SendMessage("MATCHMAKING_MAIN","getting range async died when getting queue","https://cdn.discordapp.com/attachments/759976538895548426/1091131081606045816/1633636.png",16728128,"Erorr message:"..e)
				end)
			end
		end
	
		
		if PlayersInQueue then
			
			local MainInfo = nil
			
			local MatchPlayers = {}
			
			local Parties = {}
			
			for i ,v in pairs(PlayersInQueue) do
				if v.key ~= Name.."INFO_" then
					for _,PlayerID in v.value.Players do
						table.insert(MatchPlayers,PlayerID)
					end
					table.insert(Parties,v.value)
				elseif v.key == Name.."INFO_" then
					MainInfo = v.value
				end
			end
	
			if #MatchPlayers > 0 and not QueuesStartTimes[Name] then
				QueuesStartTimes[Name] = tick()
			end
			
			
			module.QueueInfo[Name]={Amount=#MatchPlayers,Teleport=MainInfo and MainInfo.Teleport or false,Updated=os.time()}
			

			
			
			if #MatchPlayers >= Settings.MinPlayers[Name] and not QueueTimes[Name] then
				QueueTimes[Name] = tick()
			elseif #MatchPlayers < Settings.MinPlayers[Name] and QueueTimes[Name] then
				QueueTimes[Name] = nil
			end
			
			if #MatchPlayers >= Settings.MaxPlayers[Name] or (QueueTimes[Name] and (tick() - QueueTimes[Name]) >= Settings.QueueWaitTime) then
				if not MainInfo then		
					QueueTimes[Name]=nil
					
					local TotalQueueAmount = 4

					local s ,e = pcall(function()
						if QueuesStartTimes[Name] then
							print("Time Start:" , QueuesStartTimes[Name])
							
							local Do = false

							EST_MATCH_QUEUES:UpdateAsync(Name,function(data)
								if data == nil then
									data = {FinishedQueues={},EST=0}
								end

								local queuetimes = data.FinishedQueues

								local Time = tick()-QueuesStartTimes[Name]
								
								QueuesStartTimes[Name] = nil

								if #queuetimes < TotalQueueAmount then
									table.insert(queuetimes,Time)
								else
									Do = true
								end

								if Do then
									table.remove(queuetimes,#queuetimes)
									table.insert(queuetimes,1,Time)
								end

								if #queuetimes == TotalQueueAmount then
									local total = 0
									for i,v in queuetimes do
										total+=v
									end

									local Calc = math.round ((total/TotalQueueAmount))
									
									print("CALCULATED ETA!!" , Calc)

									data.EST = Calc
								end


								return data
							end,60*20)
						end
					end)

					if s then
						warn("Saved ETA!")
					end
					
					
					
					local MATCH_ID = CreateMatch()
					
					repeat
						local s , e = pcall(function()
							Queue:SetAsync(Name.."INFO_",{Teleport = true,MATCH_ID=MATCH_ID,TeleportedPlayers=#MatchPlayers},20)
						end)

						if e then
							task.wait(1)
						end
					until s
					
					spawn(function()
						Webhook:SendMessage("MATCHMAKING_MAIN","Teleporting Match with ".. #MatchPlayers.." players","",1965922,"")
					end)
					
					spawn(function()
						TeleportMatch(Parties,Queue,MATCH_ID,#MatchPlayers,Name)
					end)
					
					
				end
			end
		end		

	end
	
	warn("Updated queues")

end

local function MainControl()
	local lastCheckMain = 0
	
	print("RAN!!")
	
	local mainJobId , e = GetCurrentID()

	
	if e then
		repeat
			mainJobId , e = GetCurrentID()
			if e then
				warn("Failed retrying...")
				task.wait(10)
			end
		until not e
	end
	

	game.ReplicatedStorage.Controling.Value = mainJobId[1] == game.JobId
	
	
	spawn(function()
		while not module.ShuttingDown do
			
			local now = DateTime.now().UnixTimestampMillis
			
			
			if lastCheckMain + Settings.AddedTimeForOS <= now then
				mainJobId , e = GetCurrentID()
				lastCheckMain = now
				if mainJobId ~= nil and mainJobId[1] == game.JobId then
					warn("_updated main")
					repeat
						local s , e = pcall(function()
							ServerControlingStore:UpdateAsync(Settings.ServerControlingID, function(old)
								if (old == nil or old[1] == game.JobId) and not module.ShuttingDown then
									mainJobId = {game.JobId, now}
									return {game.JobId, now}
								end
								return nil
							end, 86400)
						end)
						
						if e then
							warn("Failed retrying...")
							task.wait(5)
						end
						
					until s
				end
				
				if mainJobId ~= nil and mainJobId[1] ~= game.JobId then

					local isMain = mainJobId == nil or mainJobId[2] + Settings.AddedTimeForOS2 <= now
					if isMain and not module.ShuttingDown then
						warn("_____updated load 2")
						repeat
							local s , e = pcall(function()
								ServerControlingStore:UpdateAsync(Settings.ServerControlingID, function(old)
									if old == nil or old[2] + Settings.AddedTimeForOS2 <= now then
										mainJobId = {game.JobId, now}
										return {game.JobId, now}
									end
									return nil
								end, 86400)
							end)
							if e then
								task.wait(2)
							end
						until s
					end
				end
				
			end
			
		
			
			if mainJobId == nil then
				repeat
					local s , e = pcall(function()
						ServerControlingStore:UpdateAsync(Settings.ServerControlingID, function(old)
							if (old == nil or mainJobId == nil or old[1] == mainJobId[1]) and not module.ShuttingDown then
								mainJobId = {game.JobId, now}
								return {game.JobId, now}
							end
							return nil
						end, 86400)
					end)
					if e then
						warn("Failed retrying...")
						task.wait(10)
					end

				until s 
				
				
				spawn(function()
					Webhook:SendMessage("MATCHMAKING_MAIN","New Server controlling matchmaking!","",1965922,"it changed in a new server")
				end)
			end
			
			if mainJobId[1] == game.JobId then
				if game.ReplicatedStorage.Controling.Value == false then
					CheckPlayersToTeleport()
				end
				
				CheckQueues()
			else
				CheckPlayersToTeleport()
				task.wait(6)
			end
			
			game.ReplicatedStorage.Controling.Value = mainJobId[1] == game.JobId
			
			
			task.wait(Settings.UpdateTime)
		end
	end)

	
end

local awaiting = {}

local function SetParty(queue,party,set)
	

	local Tab = {
		ID = party.ID.Value,
		Players = {}

	}
	
	if awaiting[Tab.ID] then
		awaiting[Tab.ID]=nil
	end
	
	awaiting[Tab.ID]=Tab.ID
	
	if not module.QueueInfo[queue]  then
		repeat
			task.wait()
		until module.QueueInfo[queue]
	end

	

	
	
	
	
	for i ,v in pairs(party.Players:GetChildren()) do
		local id = game.Players:FindFirstChild(v.Name).UserId
		table.insert(Tab.Players,id)
	end
	
	

	if set then
		spawn(function()
			repeat
				task.wait(1)
				
				if os.time()-module.QueueInfo[queue].Updated > 1 then
				--	warn("waiting")
				end
				
			until os.time()-module.QueueInfo[queue].Updated <= 1 or awaiting[Tab.ID] == nil
			

			if not awaiting[Tab.ID] then
				return
			end
			
			
			if module.QueueInfo[queue].Amount >= Settings.MaxPlayers[queue] or module.QueueInfo[queue].Teleport  then
				for i ,v in pairs(party.Players:GetChildren()) do
					local plr = game.Players:FindFirstChild(v.Name)
					if plr then
						remotehandler.FireClient(plr,"StartingMatch","Queue is full please wait...",true)
					end
				end
				
			end
			
			repeat
				task.wait()
			until module.QueueInfo[queue].Amount < Settings.MaxPlayers[queue] and module.QueueInfo[queue].Teleport==false or not awaiting[Tab.ID]
			
		

			if not awaiting[Tab.ID] then
				return
			end
			
			if not party:IsDescendantOf(game) then
				warn("no found")
				return false
			end
			
			for i ,v in pairs(party.Players:GetChildren()) do
				local plr = game.Players:FindFirstChild(v.Name)
				if plr then
					remotehandler.FireClient(plr,"ClearBox")
				end
			end

			
			
			
			repeat
				local s , e = pcall(function()
					Queues[queue]:SetAsync(Tab.ID,Tab,Settings.HoldTime)
				end)
				if e then
					warn("FAILED WTH")
					task.wait(3)
				end
				if s then
					--warn("added!!! woo")
				end
			until s or awaiting[Tab.ID]==nil
			
			if awaiting[Tab.ID] then
				party.Start.Value = tick()
			end
			
			awaiting[Tab.ID]=nil
		end)
	else
		awaiting[Tab.ID]=nil
		
		--print("Removing from queue",queue)
		local s,e=pcall(function()
			Queues[queue]:RemoveAsync(Tab.ID)
		end)
		
		if e then
			return false
		end
	end
	return true
end


function module.ADD_SQUAD_TO_QUEUE(QueueType,Squad)
	repeat
		task.wait()
	until module.Loaded==true
	
	awaiting[Squad.ID.Value]=nil
	
	local result = SetParty(QueueType,Squad,true)
	
	if result then
		module.SquadsInQueue[Squad.ID.Value]=true
	end

	return result
end



function module.REMOVE_SQUAD_FROM_QUEUE(QueueType,Squad,force)
	
	if force then
		local ID = Squad.ID.Value
		local s , e = pcall(function()
			Queues[QueueType]:RemoveAsync(ID)
		end)
		if s then
			module.SquadsInQueue[ID]=nil
		end
		return
	end

	
	
	if module.SquadsBeingTeleported[Squad.ID.Value] then
		module.SquadsBeingTeleported[Squad.ID.Value]=nil
		return
	end
	
	
	repeat
		task.wait()
	until module.Loaded ==true

	local result = SetParty(QueueType,Squad,false)
	
	if result then
		module.SquadsInQueue[Squad.ID.Value]=nil
	end
	
	return true
end

local db2 = {}

remotehandler.HearEvent("GiveStats",function(plr,ID)
	return nil
	--if db2[plr] then
	--	return
	--end
	--db2[plr]=true
	--spawn(function()
	--	task.wait(5)
	--	db2[plr]=false
	--end)
	
	--local PlayerStats 
	--local s , e = pcall(function()
	--	PlayerStats=PlayersInMatch:GetAsync(ID)
	--end)
	
	--if e then
	--	return nil
	--end
	
	--return PlayerStats
end)


local ETA_INFO = {}

local db3 = {}

remotehandler.HearEvent("GiveEST",function(plr,Mode)
	local Info = ETA_INFO[Mode]
	
	if Info and Info.EST then
		return Info.EST
	else
		return "NA"
	end
end)

remotehandler.HearEvent("GetTime",function(plr)
	return tick()
end)

remotehandler.HearEvent("ReadyTeleport",function(plr,info)
	plr:SetAttribute("ReadyTeleport",true)
end)

function module:INIT()
	warn("[MATCHMAKING]: LOADING")
	
	if game:GetService("RunService"):IsStudio() and script.RUN_IN_STUDIO.Value == false then
		warn("[MATCHMAKING]: RUN IN STUDIO IS DISABLED")
		return
	end
	
	
	local CurrentID , e = GetCurrentID()

	
	if e then
		repeat
			CurrentID , e = GetCurrentID()
			if e then
				task.wait(10)
			end
		until not e
	end

	local now = DateTime.now().UnixTimestampMillis

	local isMain = CurrentID == nil or CurrentID[2] + Settings.AddedTimeForOS2 <= now
	if isMain and not module.ShuttingDown then
		print("_updated load")
		repeat
			local s , e = pcall(function()
				ServerControlingStore:UpdateAsync(Settings.ServerControlingID, function(old)
					if old == nil or old[2] + Settings.AddedTimeForOS2 <= now then
						CurrentID = game.JobId
						return {game.JobId, now}
					end
					return nil
				end, 86400)
			end)
			if e then
				task.wait(2)
			end
		until s
	end
	
	
	if CurrentID == game.JobId then
		spawn(function()
			Webhook:SendMessage("MATCHMAKING_MAIN","New Server controlling matchmaking!","",1965922,"it started it in a new server")
		end)
	end
	
	
	MainControl()
	
	for Name,Key in pairs(Settings.GameModeQueues) do
		local s , e = pcall(function()
			Queues[Name] = MemoryStoreService:GetSortedMap(Key)
		end)
	end
	
	spawn(function()
		while not module.ShuttingDown do
			for  Name , _ in pairs(Queues) do
				local Info
				local s,e = pcall(function()
					Info=EST_MATCH_QUEUES:GetAsync(Name)
				end)
				if s then
					ETA_INFO[Name]=Info
				end
			end
			
			task.wait(25)
		end
	end)
	
	game:BindToClose(function()
		module.ShuttingDown=true
		

		local success, errorMessage = pcall(function()
			local mainId = GetCurrentID()
			if mainId[1] == game.JobId then
				local s = 0 

				repeat
					s+=1
					local s , e = pcall(function()
						ServerControlingStore:RemoveAsync(Settings.ServerControlingID)
					end)
					task.wait(4)
				until s or s == 10
				

				spawn(function()
					Webhook:SendMessage("MATCHMAKING_MAIN","Removed Control Job ID","",1965922,"Matchmaking Shutting down mostly")
				end)

			end
		end)

		
		print("Shutting Down")
		
	


		spawn(function()
			for i ,v in pairs(game.ReplicatedStorage.Parties:GetChildren()) do
				pcall(function()
					module.REMOVE_SQUAD_FROM_QUEUE(v.Mode.Value,v,true)
					v:Destroy()
				end)
			end

		end)
		
		


		task.wait(20)
	end)
	
	if MMVD.Value == false then
		module.Loaded = true
		warn("[MATCHMAKING LOADED]: "..Settings.Version)
	end
	
	
end


return module
