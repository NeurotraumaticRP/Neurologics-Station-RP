if CLIENT then return end

Neurologics = {}



Neurologics.VERSION = "2.5.6"

print(">> Neurlogics running Traitor Mod v" .. Neurologics.VERSION)

local path = table.pack(...)[1]

Neurologics.Path = path

dofile(Neurologics.Path .. "/Lua/Neurologics.lua")

print("Loading Scriptloader...")
dofile(Neurologics.Path .. "/Lua/Scriptloader.lua")