--!strict
--[[
It is recommended to either place this script in ReplicatedStorage, ServerScriptService or ServerStorage.
This script has RunContext set as Server, so this'll run under it.
Update require path if needed.
]]
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
require(ReplicatedStorageService.MainModule)()
