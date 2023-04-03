local TeleportService = game:GetService("TeleportService")

local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 4
local FLOOD_DELAY = 15

local function SafeTeleport(placeId, players, options)
	local attemptIndex = 0
	local success, result

	repeat
		success, result = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, options)
		end)
		attemptIndex += 1
		if not success then
			task.wait(RETRY_DELAY)
		end
	until success or attemptIndex == ATTEMPT_LIMIT

	if not success then
		warn(result)
	end

	return success, result
end

local function handleFailedTeleport(player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
	if teleportResult == Enum.TeleportResult.Flooded then
		task.wait(FLOOD_DELAY)
	elseif teleportResult == Enum.TeleportResult.Failure then
		task.wait(RETRY_DELAY)
	else
		--error(("Invalid teleport [%s]: %s"):format(teleportResult.Name, errorMessage))
	end

	SafeTeleport(targetPlaceId, {player}, teleportOptions)
end

TeleportService.TeleportInitFailed:Connect(handleFailedTeleport)

return SafeTeleport
