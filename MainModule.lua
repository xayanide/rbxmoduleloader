--!strict
--[[
VERSION: v1.0.3
rbxmoduleloadermodule by xayanide (862645934) @ April 3, 2025 UTC+8
This module is meant to only have simple features with the least overhead and complexity
]]
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorageService = game:GetService("ReplicatedStorage")

export type LoadModulesOptions = {
    isShared: boolean?,
    targetInstances: { Instance }?,
}?

local DEFAULT_LOAD_MODULES_OPTIONS = {
    isShared = true,
}
local SETUP_LIFECYCLE_METHOD_NAME = "onModuleSetup"
local START_LIFECYCLE_METHOD_NAME = "onModuleStart"

-- This aliasing is for to avoid a type error: Type Error: Unknown require: unsupported path
local _require = require

local isServerRuntimeEnvironment = RunService:IsServer()
local taskDefer = task.defer
local ModuleContainerModuleScript = script.ModuleContainer
local localDictionary = _require(ModuleContainerModuleScript)

local function getDictionaryMemberValue(dictionary: { [string]: any }, memberName: string)
    return dictionary[memberName]
end

local function executeDictionaryMethods(dictionary: { [string]: { [string]: any } | any }, methodName: string, isTaskDeferred: boolean)
    for _, value in pairs(dictionary) do
        if typeof(value) ~= "table" then
            continue
        end
        local success, method = pcall(getDictionaryMemberValue, value, methodName)
        if success == false then
            continue
        end
        if typeof(method) ~= "function" then
            continue
        end
        if isTaskDeferred == true then
            taskDefer(method)
            continue
        end
        method()
    end
end

local function storeModule(descendantName: string, requiredModule: { [string]: any }, isShared: boolean?)
    if isShared then
        shared[descendantName] = requiredModule
        return
    end
    localDictionary[descendantName] = requiredModule
end

local function requireModule(moduleScript: ModuleScript)
    local function onRequireError(err)
        warn("Unable to require " .. moduleScript.Name .. ":", err)
    end
    local success, value = xpcall(_require, onRequireError, moduleScript)
    if success == false then
        return nil
    end
    return value
end

local function requireDescendants(descendants: { Instance }, isShared: boolean?)
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
            local descendantModule = requireModule(descendant)
            if descendantModule == nil then
                continue
            end
            storeModule(descendantName, descendantModule, isShared)
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
        local valueModule = requireModule(value)
        if valueModule == nil then
            continue
        end
        storeModule(descendantName, valueModule, isShared)
    end
    if isShared then
        return shared
    end
    return localDictionary
end

local function getServiceByRuntimeEnvironment(isServer: boolean)
    if isServer then
        return ServerScriptService
    end
    return ReplicatedStorageService
end

local function getTargetInstancesDescendants(targetInstances: { Instance })
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

local function getDescendantsForRequire(targetInstances: { Instance }?)
    if targetInstances == nil then
        local Service = getServiceByRuntimeEnvironment(isServerRuntimeEnvironment)
        return Service:GetDescendants()
    end
    if typeof(targetInstances) ~= "table" then
        error("Invalid value passed for option 'targetInstances'. Must be an array of Instances.")
    end
    return getTargetInstancesDescendants(targetInstances)
end

local function getResolvedOptions(options: LoadModulesOptions)
    if options and typeof(options) ~= "table" then
        error("Invalid value passed for 'options'. Must be an table.")
    end
    if options then
        local isShared = options.isShared
        options.isShared = if isShared == nil then DEFAULT_LOAD_MODULES_OPTIONS.isShared else isShared
        return options
    end
    return DEFAULT_LOAD_MODULES_OPTIONS
end

local function loadModules(options: LoadModulesOptions)
    -- Synchronous and Serial.
    local userOptions = getResolvedOptions(options)
    local descendants = getDescendantsForRequire(userOptions.targetInstances)
    local requiredModules = requireDescendants(descendants, userOptions.isShared)
    -- Synchronous and Serial. Anything that yields in the module scripts will block the main execution flow.
    executeDictionaryMethods(requiredModules, SETUP_LIFECYCLE_METHOD_NAME, false)
    -- Asynchronous and Concurrent. Anything that yields in the module scripts will not block the main execution flow.
    executeDictionaryMethods(requiredModules, START_LIFECYCLE_METHOD_NAME, true)
end

return loadModules
