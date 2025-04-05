# rbxmoduleloader
A module that loads and executes ModuleScripts from either ServerScriptService or ReplicatedStorage and stores it into global variable "shared" with its contents depend on runtime context (Client or Server).

Features:
- Loads modules dynamically, only when needed.
- Loaded ModuleScripts implement lifecycle methods (hooks): `onModuleSetup` (synchronous) and `onModuleStart` (asynchronous).
- Follows a specific design pattern when making ModuleScripts for the Client or Server but doesn't dictate the way you script.
- Allows for both global (`shared`) and local (`ModuleContainer`) module storage, depending on whether the module should be available globally or locally.
- Allows only loading module scripts from specific Instance's descendants.
- Uses `xpcall` and `pcall` for safe module requiring, prevents the module loader from failing, with error handling that logs any failures to load modules.

## Prerequisites

- Roblox Player
- Roblox Studio

## Usage

To use the `rbxmoduleloader` **stock**, you will need to call it with no options. This module can be loaded either as a server or client-side script, and that'll dictate what module scripts it will load.

**Using the ModuleLoader for the Client**

1. Create a `Script` in `ReplicatedStorage` and set its `RunContext` to `Client` so that it'll run in `ReplicatedStorage`.
Copy and paste, enable this script and update require path if needed.

> [!NOTE]
> You can rewrite this below as a one-liner since the `Script` only exists for one purpose: Loading modules.

```lua
--!strict
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
require(ReplicatedStorageService.MainModule)()
```
Take note of its RunContext: `Client`. This will load the modules found in `ReplicatedStorage` and store them in the `shared` global variable, making them globally accessible on other client scripts.

2. Make a `ModuleScript` inside `ReplicatedStorage` that follows the design pattern:

```lua
return {
    onModuleSetup = function()
        print("onModuleSetup: " .. script.Name)
    end,
    onModuleStart = function()
        print("onModuleStart: " .. script.Name)
    end,
}
```

**Using the ModuleLoader for the Server**

3. Similarly, create a `Script` in `ReplicatedStorage` and set its `RunContext` to `Server` so that it'll run in `ReplicatedStorage`.
Copy and paste, enable this script and update require path if needed.

> [!NOTE]
> You can rewrite this below as a one-liner since the `Script` only exists for one purpose: Loading modules.

```lua
--!strict
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
require(ReplicatedStorageService.MainModule)()
```
Take note of its RunContext: `Server`. This will load the modules found in `ServerScriptService` and store them in the `shared` global variable, making them globally accessible on other server scripts.

4. Make a `ModuleScript` inside `ServerScriptService` that follows the design pattern:

```lua
return {
    onModuleSetup = function()
        print("onModuleSetup: " .. script.Name)
    end,
    onModuleStart = function()
        print("onModuleStart: " .. script.Name)
    end,
}
```

5. Done!

For more information about the design patterns, please see [lifecycle methods](#lifecycle-methods)

## Configuration

The `ModuleLoaderOptions` table allows you to configure the loader's behavior. This is passed as an argument to the `rbxmoduleloader` function when you require it.

`isShared` (optional)
  - `Type`: boolean?
  - `Default`: true
  - `Description`: Determines if the loaded modules should be stored in the `shared` dictionary table (accessible globally) or in an isolated local dictionary table (child of `rbxmoduleloader` which is "`ModuleContainer`"). When `isShared` is true, the modules are stored in the global shared table, meaning they can be accessed anywhere in the game depending on the runtime context.

**Example Usage:**

>[!NOTE]
> For this example, write this as a `LocalScript` inside `StarterPlayer -> StarterPlayerScripts`
> This will load all ModuleScripts inside `ReplicatedStorage`.

```lua
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
local loadModules = require(ReplicatedStorageService.MainModule)
loadModules({ isShared = true })
```

`targetInstances` (optional)
  - `Type`: { Instance }?
  - `Default`: nil
  - `Description`: Specifies the list of instances whose descendants should be processed for module loading. If not provided, the loader will scan all descendants of the appropriate service based on the runtime environment (client or server):
  - Server
    - ServerScriptService
  - Client
    - ReplicatedStorage

**Example Usage:**

> [!NOTE]
> For this example, write this as a `Server Script` in `ServerScriptService`
> This will load all ModuleScripts inside `ServerScriptService` and `ServerStorage`.

```lua
local ReplicatedStorageService = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorageService = game:GetService("ServerStorage")

local loadModules = require(ReplicatedStorageService.MainModule)
loadModules({
    targetInstances = { ServerScriptService, ServerStorageService }
})
```

## Lifecycle Methods

The loader supports two lifecycle methods that will be invoked in this order on the modules after they are loaded (required):
1. `onModuleSetup()`: () -> ()
    - `Description`: This method is called synchronously for each module after it is loaded.
    - `Purpose`: Use this to perform setup tasks on the module, like initializing variables or setting properties.

2. `onModuleStart()`: () -> ()
    - `Description`: This method is called asynchronously for each module after the setup phase.
    - `Purpose`: Use this to trigger the start of the module, such as initiating processes that may involve waiting or other asynchronous tasks.

With that in mind, instead of using `LocalScripts` or `Scripts`, use `ModuleScripts` for both the Client or Server that follows the design pattern:

- The module script returns a table.

- The table contains the keys `onModuleSetup` and `onModuleStart`.

- Each key maps to an anonymous function (closure).

- `onModuleSetup()` and `onModuleStart()` are callable functions exposed by the module.

**ModuleScript Examples**

> [!NOTE]
> These are just shorthand example codes for demonstration.

**1**
Inline Anonymous Functions

```lua
return {
    onModuleSetup = function()
        print("onModuleSetup: " .. script.Name)
    end,
    onModuleStart = function()
        print("onModuleStart: " .. script.Name)
    end,
}
```

Here are other verbose versions of writing but follows the design pattern:

**2**
Assigned Anonymous Functions

```lua
local module = {}

module.onModuleSetup = function()
    print("onModuleSetup: " .. script.Name)
end

module.onModuleStart = function()
    print("onModuleStart: " .. script.Name)
end

return module
```

**3**
Syntactic Sugar: Named Table Functions

```lua
local module = {}

function module.onModuleSetup()
    print("onModuleSetup: " .. script.Name)
end

function module.onModuleStart()
    print("onModuleStart: " .. script.Name)
end

return module
```

**4**
Local Named Functions then Assigned

```lua
local module = {}

local function ModuleOnModuleSetup()
    print("onModuleSetup: " .. script.Name)
end

local function ModuleOnModuleStart()
    print("onModuleStart: " .. script.Name)
end

module.onModuleSetup = ModuleOnModuleSetup
module.onModuleStart = ModuleOnModuleStart
return module
```

**5**
Named Locals, Returned in Table

```lua
local function ModuleOnModuleSetup()
    print("onModuleSetup: " .. script.Name)
end

local function ModuleOnModuleStart()
    print("onModuleStart: " .. script.Name)
end

return {
    onModuleSetup = ModuleOnModuleSetup,
    onModuleStart = ModuleOnModuleStart,
}
```

**6**
Local Variables with Anonymous Functions

```lua
local module = {}

local ModuleOnModuleSetup, ModuleOnModuleStart

ModuleOnModuleSetup = function()
    print("onModuleSetup: " .. script.Name)
end

ModuleOnModuleStart = function()
    print("onModuleStart: " .. script.Name)
end

module.onModuleSetup = ModuleOnModuleSetup
module.onModuleStart = ModuleOnModuleStart
return module
```

**7**
Local Variables with Anonymous Functions but now embedded in a table.

```lua
local ModuleOnModuleSetup, ModuleOnModuleStart

ModuleOnModuleSetup = function()
    print("onModuleSetup: " .. script.Name)
end

ModuleOnModuleStart = function()
    print("onModuleStart: " .. script.Name)
end

return {
    onModuleSetup = ModuleOnModuleSetup,
    onModuleStart = ModuleOnModuleStart,
}
```
