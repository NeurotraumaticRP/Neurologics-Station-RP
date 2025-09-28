--[[if CLIENT then return end

LuaCsClientSideEnforced = {}
LuaCsClientSideEnforced.KickTimer = 60

LuaUserData.RegisterType("Barotrauma.Networking.FileSender")

local function IsDownloading(client)
    for key, value in pairs(Game.Server.FileSender.ActiveTransfers) do
        if value.Connection == client.Connection then
            return true
        end
    end

    return false
end

local clients = {}

local function GetOrCreateData(client)
    if not clients[client] then
        clients[client] = {}
        clients[client].HasInstalled = false
        clients[client].KickTimer = 0
    end

    return clients[client]
end

-- assume every already connected client has already client-side installed
for _, client in pairs(Client.ClientList) do
    local data = GetOrCreateData(client)
    data.HasInstalled = true
    data.KickTimer = 0
end

Networking.Receive("client_side_enforced", function(message, client)
    local data = GetOrCreateData(client)

    if data.HasInstalled then return end
    data.HasInstalled = true
    data.KickTimer = 0

    Logger.Log("Received Client-side LuaCs heartbeat from " .. client.Name, Color.Green)
end)

Hook.Add("client.connected", "ClientSideEnforced", function (client)
    GetOrCreateData(client)
end)

Hook.Add("think", "ClientSideEnforced", function(client)
    for client, data in pairs(clients) do
        if not data.HasInstalled and not IsDownloading(client) then
            if data.KickTimer > LuaCsClientSideEnforced.KickTimer then
                Neurologics.SendMessage(client, "Client-side LuaCs is required to play on this server! You will be missing out on a lot of features if you don't install it. You can find the instructions on how to install it on the discord server in #cslua-faq")
            else
                data.KickTimer = data.KickTimer + 1/60
            end
        end
    end
end)]]