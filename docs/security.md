---
sidebar_position: 3
---

# Security
Sandboxer is designed to restrict untrusted code from accessing sensitive APIs and data.
It is not a general-purpose sandbox for CPU, memory, or yield limits, and it cannot stop all denial-of-service behavior.

Sandboxer can block patterns like:
```lua
game:GetService("DataStoreService"):GetDataStore("MyDataStore"):SetAsync("MyKey", "funny")
```

It cannot stop code like:
```lua
while true do
    print("Hello!")
end
```

The `print` call may be blocked, but the infinite loop itself will still run until the process is terminated or times out.
Similarly, code can allocate memory aggressively:
```lua
local buffers = {}
for _ = 1, 100000 do
    table.insert(buffers, buffer.create(100000))
end
```

This is a denial-of-service issue, and Sandboxer does not attempt to limit CPU, memory, or yield behavior. It is up to the developer to add their own resource constraints for untrusted code.

:::danger[Important!]
If you find a security vulnerability or sandbox escape in the unmodified version of the module, please do not hesitate to DM me on DevForum or Discord at littlebitsman. **Please do not post vulnerabilities publicly.**
:::

## Trust boundary

Sandboxer assumes a clear distinction between trusted code and sandboxed code.

:::tip
**Trusted code** means any code executed outside the sandbox, including modules that construct or configure it.
:::

Sandboxer only guarantees safety while raw trusted data is not intentionally exposed to sandboxed code.
Once trusted code passes through data such as `game`, a raw `Instance`, a raw RBXScriptSignal, or a callback that returns raw privileged values, the sandbox is effectively bypassed.

This is not a vulnerability in Sandboxer. It is a trust-boundary violation caused by how the sandbox is used.

Example:
```lua
Sandboxer.EditDefaultSandbox({
    game = function() return game end
})
```

This leaks the actual Instance tree and there is no way for Sandboxer to protect it afterward.

Modules required by sandboxed code are also part of the trust boundary. If a module that is loaded into the sandbox exposes raw `Instance`s, raw signals, or functions that return raw privileged values, it must be treated as trusted code and kept secure or sandboxed itself. If a module is used both inside and outside the sandbox, it should expose a sandbox-safe interface or separate trusted and untrusted paths.

## Guarantees
Sandboxer is designed so that, in its intended configuration, no known bypasses exist that allow access to restricted APIs without explicit leakage from trusted code.

The security guarantees are as follows, assuming no leakage of data from trusted code to sandboxed code and all sandboxed code runs in a single Luau VM (that is, no cross-VM communication using Actors):

- Wrapped Instances never expose the underlying Instance or its metatable. Any `Instance` or `RBXScriptSignal` delivered to sandboxed code through a wrapped Instance is automatically wrapped before exposure.
- Wrapped methods never expose raw Instances, raw RBXScriptSignals, or the underlying metatable. Any returned `Instance` or `RBXScriptSignal` is automatically wrapped before being returned.
- Wrapped signals never expose the underlying `RBXScriptSignal`, its metatable, any Instances returned by that signal, or any other `RBXScriptSignal` returned by it.
  - Arguments delivered to a signal are wrapped before being delivered to sandboxed code.
- Only Instances explicitly allowed in the `InstanceList` are accessible to sandboxed code.
  - A blacklist (`ExplicitDisallow`) exists for more granular control.
- The following globals are forbidden in sandboxed code: `getfenv`, `setfenv`, `loadstring`, `debug.info`, `debug.traceback`, and `debug`.
  - The only exception is if a user bypasses the checks that prevent this; see [the API docs](/api/Sandboxer#EditDefaultSandbox).
- Metatables on wrapped Instances and RBXScriptSignals are locked and non-referencable. They cannot be accessed, replaced, or modified by sandboxed code.
- Wrapper identity is preserved. Each underlying `Instance` or `RBXScriptSignal` has exactly one corresponding wrapper within a Luau VM.
  - Wrapping the same object multiple times always returns the same wrapper.
  - Two wrapped objects compare equal if and only if they wrap the same underlying `Instance` or `RBXScriptSignal`.
  - Wrapped objects are stable and may be used as table keys.
- An `Instance` is not garbage collected while a wrapper still exists within any code outside Sandboxer and is still reachable.
- All callbacks crossing the sandbox boundary are wrapped:
  - Arguments passed to sandboxed code are wrapped before delivery.
  - Wrapped arguments returned from sandboxed code are unwrapped before delivery to trusted code.
  - The following exceptions apply:
    - Custom wrappers created by trusted code using `InstanceSandboxer.wrapFn` with passthroughs configured.
    - All functions in the following globals: `bit32`, `buffer`, `coroutine`, `math`, `os`, `string`, `table`, `task`, `utf8`, `vector`, `Axes`, `BrickColor`, `CatalogSearchParams`, `Color3`, `ColorSequence`, `ColorSequenceKeypoint`, `Content`, `DateTime`, `DockWidgetPluginGuiInfo`, `Faces`, `FloatCurveKey`, `Font`, `NumberSequence`, `NumberSequenceKeypoint`, `OverlapParams`, `Path2DControlPoint`, `PathWaypoint`, `PhysicalProperties`, `Random`, `Ray`, `RaycastParams`, `Rect`, `Region3`, `Region3int16`, `RotationCurveKey`, `TweenInfo`, `UDim`, `UDim2`, `Vector2`, `Vector2int16`, `Vector3`, `Vector3int16`.
- Every sandbox receives a fresh copy of `_G` / `shared`, created as `{}`. `_G` / `shared` is not shared between sandboxes or between sandboxed and trusted code.
- `typeof` on wrapped Instances and RBXScriptSignals inside the sandbox returns the same result as `typeof` on the underlying object in trusted code, unless `typeof` itself has been modified or overridden.
- `require` only permits Instances allowed by the `InstanceList`, even when using string paths. Only the resolved target in the string path is checked against the `InstanceList`; the rest of the path is ignored.
  - For example, if `require("@game/ReplicatedStorage/MyModule")` is called, only `MyModule` is checked against `InstanceList`.
- `InstanceList` is the sole source of truth for which Instances are allowed in the sandbox. If an Instance is not explicitly allowed, it will not be accessible to sandboxed code. Even if the Instance is reachable through references, method returns, or properties, it is checked against `InstanceList` before being delivered to sandboxed code. If it is not allowed, it is replaced with `nil`.

## Not guaranteed
- Sandboxer does not attempt to limit CPU, memory, or yield behavior. You must implement your own resource limits for untrusted code.
- Sandboxer does not protect against raw trusted values being exposed to sandboxed code. If trusted code returns `game`, a raw Instance, or any other privileged object, the sandbox guarantees no longer hold.
- If a module required by sandboxed code exposes privileged values, that module must itself be secured or sandboxed.