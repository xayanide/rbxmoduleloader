--!strict
--[[
It is recommended to only place this script in ReplicatedStorage.
Only choose between this or placing a LocalScript inside StarterPlayerScripts with the same content as this script.
This script has RunContext set as Client, so this'll run under it.
Update require path if needed.
]]
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
require(ReplicatedStorageService.MainModule)()
