--!strict
--[[
Create a "Script" in ReplicatedStorage and set its RunContext to Client so that it'll run in ReplicatedStorage.
Copy and paste, enable this script and update require path if needed.
]]
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
require(ReplicatedStorageService.MainModule)({ isShared = false })
