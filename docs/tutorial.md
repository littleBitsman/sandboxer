---
sidebar_position: 2
---

# Getting Started

This guide demonstrates the typical setup process for Sandboxer.

## 1. Place the module

Place the Sandboxer module somewhere accessible by your server scripts.

A common location is `ServerScriptService`.

```
ServerScriptService
├── Sandboxer
└── MyScript
```

## 2. Initialize the sandbox

The first executable line of any script that should be sandboxed should initialize Sandboxer.

```lua
require(game:GetService("ServerScriptService").Sandboxer):Init()
```

This should appear before any other executable code (excluding Luau directives such as `--!strict` or `--!optimize`) to ensure the script is sandboxed before it begins executing.

## 3. Configure the sandbox (optional)

Sandbox behavior can be customized before additional sandboxes are created.

For example, to remove `game` from future sandboxes:

```lua
local Sandboxer = require(game:GetService("ServerScriptService").Sandboxer)

Sandboxer.EditDefaultSandbox({
    game = false,
})
```

You can also configure which Roblox objects are accessible:

```lua
Sandboxer.InstanceList.ForbiddenClasses["DataStoreService"] = true
table.insert(Sandboxer.InstanceList.DisallowedClasses, "HttpService")
```

Refer to the `Config` and `InstanceList` documentation for the available options.

## 4. Sandbox a function

Individual functions can also be sandboxed.

```lua
local Sandboxer = require(game:GetService("ServerScriptService").Sandboxer)

local fn = Sandboxer:Sandbox(function()
    print("Hello from the sandbox!")
end)

fn()
```

## 5. Clean up tracked resources (optional)

If `Config.TrackInstances` or `Config.TrackRBXScriptConnections` is enabled, Sandboxer records resources created or accessed by sandboxed code.

For example:

```lua
for inst in Sandboxer.InstanceSandboxer.NewInstances do
    inst:Destroy()
end

table.clear(Sandboxer.InstanceSandboxer.NewInstances)
```

Likewise, tracked `RBXScriptConnection`s can be disconnected and cleared after execution.

## Next Steps

* [Read the `Sandboxer` API reference](/api/Sandboxer) to learn how to create and manage sandboxes.
* [See `Config`](/api/Config) for available configuration options.
* [See `InstanceList`](/api/InstanceList) to control which Roblox objects are accessible.
* [See `InstanceSandboxer`](/api/InstanceSandboxer) for advanced customization and extension APIs.
