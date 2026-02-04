if CLIENT and Game.IsMultiplayer then return end
LuaUserData.RegisterType("Barotrauma.Items.Components.Terminal")
LuaUserData.RegisterType("Barotrauma.Items.Components.TerminalMessage")
LuaUserData.RegisterType('System.Collections.Generic.List`1[[Barotrauma.Items.Components.TerminalMessage]]')
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Terminal"], "messageHistory")

Neurologics = {}



Neurologics.VERSION = "2.5.6"

print(">> Neurlogics running Traitor Mod v" .. Neurologics.VERSION)

local path = table.pack(...)[1]

Neurologics.Path = path

dofile(Neurologics.Path .. "/Lua/Neurologics.lua")

dofile(Neurologics.Path .. "/Lua/Scriptloader.lua")