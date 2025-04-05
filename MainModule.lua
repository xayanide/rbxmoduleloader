--!strict
--[[
VERSION: v1.0.2
rbxmoduleloader by xayanide (862645934) @ April 3, 2025 UTC+8
This module is meant to only have simple features with the least overhead and complexity
]]
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorageService = game:GetService("ReplicatedStorage")

export type ModuleLoaderOptions = {
    isShared: boolean?,
    targetInstances: { Instance }?,
}?

-- This aliasing is for to avoid a type error: Type Error: Unknown require: unsupported path
local REQUIRE = require
local DEFAULT_MODULE_LOADER_OPTIONS = {
    isShared = true,
}
local SETUP_LIFECYCLE_METHOD_NAME = "onModuleSetup"
local START_LIFECYCLE_METHOD_NAME = "onModuleStart"

local isServerRuntimeEnvironment = RunService:IsServer()
local ModuleContainerModuleScript = script.ModuleContainer
local localDictionary = REQUIRE(ModuleContainerModuleScript)

local function GetDictionaryMemberValue(dictionary: { [string]: any }, memberName: string)
    return dictionary[memberName]
end

local function ExecuteDictionaryMethods(dictionary: { [string]: { [string]: any } | any }, methodName: string, isTaskDeferred: boolean)
    for _, value in pairs(dictionary) do
        if typeof(value) ~= "table" then
            continue
        end
        local success, method = pcall(GetDictionaryMemberValue, value, methodName)
        if success == false then
            continue
        end
        if typeof(method) ~= "function" then
            continue
        end
        if isTaskDeferred == true then
            task.defer(method)
            continue
        end
        method()
    end
end

local function StoreModule(descendantName: string, requiredModule: { [string]: any }, isShared: boolean?)
    if isShared == true then
        shared[descendantName] = requiredModule
        return
    end
    localDictionary[descendantName] = requiredModule
end

local function RequireModule(moduleScript: ModuleScript)
    local function onRequireError(err)
        warn("Unable to load " .. moduleScript.Name .. ":", err)
    end
    local success, value = xpcall(require, onRequireError, moduleScript)
    if success == false then
        return nil
    end
    return value
end

local function RequireDescendants(descendants: { Instance }, isShared: boolean?)
    for i = 1, #descendants do
        local descendant = descendants[i]
        -- To prevent this module loader from requiring itself, ignore the descendant
        if descendant == script then
            continue
        end
        -- To prevent this module loader from requiring the module container, ignore the descendant
        if descendant == ModuleContainerModuleScript then
            continue
        end
        local descendantName = descendant.Name
        if descendant:IsA("ModuleScript") then
            local descendantModule = RequireModule(descendant)
            if descendantModule == nil then
                continue
            end
            StoreModule(descendantName, descendantModule, isShared)
            continue
        end
        if not descendant:IsA("ObjectValue") then
            continue
        end
        local value = descendant.Value
        if not value then
            continue
        end
        if not value:IsA("ModuleScript") then
            continue
        end
        local valueModule = RequireModule(value)
        if valueModule == nil then
            continue
        end
        StoreModule(descendantName, valueModule, isShared)
    end
    if isShared == true then
        return shared
    end
    return localDictionary
end

local function GetServiceByRuntimeEnvironment(isServer: boolean)
    if isServer then
        return ServerScriptService
    end
    return ReplicatedStorageService
end

local function GetTargetInstancesDescendants(targetInstances: { Instance })
    local descendants = {}
    local nextIndex = 1
    for targetIndex = 1, #targetInstances do
        local targetInstance = targetInstances[targetIndex]
        if typeof(targetInstance) ~= "Instance" then
            error("Invalid value passed for 'targetInstances'. Must be an Instance.")
        end
        local targetInstanceDescendants = targetInstance:GetDescendants()
        for descendantIndex = 1, #targetInstanceDescendants do
            descendants[nextIndex] = targetInstanceDescendants[descendantIndex]
            nextIndex += 1
        end
    end
    return descendants
end

local function GetDescendantsForRequire(targetInstances: { Instance }?)
    if targetInstances == nil then
        local Service = GetServiceByRuntimeEnvironment(isServerRuntimeEnvironment)
        return Service:GetDescendants()
    end
    if typeof(targetInstances) ~= "table" then
        error("Invalid value passed for option 'targetInstances'. Must be an array of Instances.")
    end
    return GetTargetInstancesDescendants(targetInstances)
end

local function GetResolvedOptions(options: ModuleLoaderOptions)
    local hasOptions = options ~= nil
    if hasOptions and typeof(options) ~= "table" then
        error("Invalid value passed for 'options'. Must be an table.")
    end
    if hasOptions then
        local isShared = options.isShared
        options.isShared = if isShared == nil then DEFAULT_MODULE_LOADER_OPTIONS.isShared else isShared
        return options
    end
    return DEFAULT_MODULE_LOADER_OPTIONS
end

local function LoadModules(options: ModuleLoaderOptions)
    -- Synchronous and Serial.
    local userOptions = GetResolvedOptions(options)
    local descendants = GetDescendantsForRequire(userOptions.targetInstances)
    local requiredModules = RequireDescendants(descendants, userOptions.isShared)
    -- Synchronous and Serial. Anything that yields in the module scripts will block the main execution flow.
    ExecuteDictionaryMethods(requiredModules, SETUP_LIFECYCLE_METHOD_NAME, false)
    -- Asynchronous and Concurrent. Anything that yields in the module scripts will not block the main execution flow.
    ExecuteDictionaryMethods(requiredModules, START_LIFECYCLE_METHOD_NAME, true)
end

return LoadModules
