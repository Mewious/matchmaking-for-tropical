local module = {}

module.TeleportTo = 10351563081

module.ServerControlingID = "ServerControlingID_V41"
module.QueueKey = "MATCH_QUEUE_TEST_V34"

module.GameModeQueues = {
	["Solos"]="S_"..module.QueueKey,
	["Duos"]="D_"..module.QueueKey,
}


module.MaxPlayers = {
	Solos = 40,
	Duos = 2,
	
	
}




module.MinPlayers = {
	Solos = 15,
	Duos = 1,


}

module.AddedTimeForOS = 150000

module.AddedTimeForOS2 = 300000


module.Version = "4.2"

module.UpdateTime = 8

module.HoldTime = 4000

module.QueueWaitTime = 65

return module
