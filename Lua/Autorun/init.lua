if CLIENT then return end

Neurologics = {}



Neurologics.VERSION = "2.5.6"

print(">> Neurlogics running Traitor Mod v" .. Neurologics.VERSION)
print(">> Github Contributors: evilfactory, MassCraxx, Philly-V, Qunk1, mc-oofert.")
print(">> Special thanks to Qunk, Femboy69 and JoneK for helping in the development of this mod.")

local path = table.pack(...)[1]

Neurologics.Path = path

dofile(Neurologics.Path .. "/Lua/Neurologics.lua")

print("Loading Scriptloader...")
dofile(Neurologics.Path .. "/Lua/Scriptloader.lua")