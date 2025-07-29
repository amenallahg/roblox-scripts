local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local placeId = 132352755769957
local currentJobId = game.JobId

-- Join Patient team
ReplicatedStorage.Remote.TeamChange:InvokeServer(Teams.PATIENT, "Patient")
ReplicatedStorage.Remote.AnalyticsEvent:FireServer("Funnel", "Title Screen", "Selected Team")
ReplicatedStorage.Remote.GetSettings:InvokeServer()
ReplicatedStorage.Remote.GetSettingsDescription:InvokeServer()
ReplicatedStorage.Remote.AccessoryEvent:InvokeServer("Request")
task.wait(0.5)

-- Remove blur effect
for _, v in ipairs(Lighting:GetChildren()) do
    if v:IsA("BlurEffect") then
        v:Destroy()
    end
end

-- Remove team GUI
local playerGui = plr:WaitForChild("PlayerGui")
for _, gui in ipairs(playerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name:lower():find("team") then
        gui:Destroy()
    end
end

-- Teleport to position
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local tpPos = Vector3.new(-1.0, 517.5, 408.0)
hrp.CFrame = CFrame.new(tpPos)

-- Server hop
local function tryServerHop()
    local triedServers = {}

    local function getServers(cursor)
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(placeId)
        if cursor then url = url .. "&cursor=" .. cursor end
        local success, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if success and res then return res end
        return nil
    end

    while true do
        local cursor = nil
        local serverFound = false

        repeat
            local data = getServers(cursor)
            if not data then
                warn("Failed to get server list")
                task.wait(2)
                break
            end

            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= currentJobId and not triedServers[server.id] then
                    triedServers[server.id] = true
                    local success, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, server.id)
                    end)
                    if success then
                        serverFound = true
                        break
                    else
                        warn("Teleport failed:", err)
                    end
                end
            end

            cursor = data.nextPageCursor
            if serverFound then break end
        until not cursor or serverFound

        if serverFound then
            break -- teleport succeeded, exit loop
        else
            warn("No available servers found, rejoining current server in 5 seconds...")
            task.wait(5)
            local rejoinSuccess, rejoinErr = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, currentJobId)
            end)
            if not rejoinSuccess then
                warn("Rejoin failed:", rejoinErr)
            end
            break
        end
    end
end

tryServerHop()
