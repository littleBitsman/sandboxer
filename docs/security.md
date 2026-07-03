---
sidebar_position: 3
---

# Security 

Sandboxer is designed to restrict untrusted code from accessing sensitive APIs and data. It is not designed to, for example, prevent crashes from `while true do end`. 

Sandboxer can easily block accesses like:
```lua
game:GetService("DataStoreService"):GetDataStore("MyDataStore"):SetAsync("MyKey", "funny")
```

But it cannot prevent code like:
```lua
while true do
    print("Hello!")
end
```
It can prevent the `print`, but it will not prevent the infinite loop and execution will continue until terminated due to a timeout or crash. 

Code can otherwise cause crashes. For example, one could infinitely allocate buffers:
```lua
local buffers = {}
for _ = 1, 100000 do
    table.insert(buffers, buffer.create(100000))
end
```
This is a denial-of-service attack, and Sandboxer is not designed to prevent this. **Sandboxer does not attempt to limit CPU, memory, or yield behavior.** It is up to the developer to implement their own resource limits for untrusted code.

## Guarantees
Sandboxer makes some guarantees when data is not intentionally leaked from trusted code to sandboxed code. 
:::tip
**Trusted code** refers to any code executed outside the Sandboxer environment, including modules that construct or configure the sandbox.
:::
Sandboxer is designed so that, in its intended configuration, no known bypasses exist that allow access to restricted APIs without explicit leakage from trusted code.
:::note
It is very possible that someone could do this in trusted code:
```lua
Sandboxer.EditDefaultSandbox({
    game = function() return game end
})
```
Now, the actual Instance tree is leaked and nothing can be done to secure it.

**This is not a vulnerability, it is behavior caused by usage.**
:::

:::danger[Important!]
If you find a security vulnerability or sandbox escape with the unmodified version of the module, please do not hesitate to DM me on DevForum or on Discord (littlebitsman)! ***Please do not post vulnerabilities publicly.***
:::

The security guarantees are as follows, assuming no leakage of data from trusted code to sandboxed code and all sandboxed code is executed in a single Luau VM (i.e., no cross-VM communication using Actors):
- Wrapped Instances never expose the underlying Instance or its metatable. Any Instance or RBXScriptSignal delivered to sandboxed code via a wrapped Instance is automatically wrapped before being exposed.
- Wrapped methods never expose raw Instances, raw RBXScriptSignals, or the underlying metatable. Any Instance or RBXScriptSignal returned from a wrapped method is automatically wrapped before being returned.
- Wrapped signals will never expose the underlying RBXScriptSignal, its metatable, any Instances returned by said signal, or any other RBXScriptSignals returned by said signal.
  - All arguments delivered in a signal are wrapped before being delivered to the sandboxed code.
- Only Instances explicitly allowed in the `InstanceList` will be accessible to sandboxed code.
  - A blacklist (`ExplicitDisallow`) exists for more granular control.
- The following globals are forbidden in sandboxed code: `getfenv`, `setfenv`, `loadstring`, `debug.info`, `debug.traceback`, `debug`.
  - The only exception is if a user bypasses the checks that prevent this; [read here for more information](/api/Sandboxer#EditDefaultSandbox).
- Metatables on wrapped Instances and RBXScriptSignals are locked & non-referencable and cannot be accessed, replaced, or modified by sandboxed code
- Wrapper identity is preserved. Each underlying Instance or RBXScriptSignal has exactly one corresponding wrapper within a Luau VM. Wrapping the same object multiple times will always return the same wrapper.
  - Two wrapped objects compare equal if and only if they wrap the same underlying `Instance` or `RBXScriptSignal`.
  - Wrapped objects are stable and may be used as table keys.
- An `Instance` will not be garbage collected while a wrapper still exists within any code (not in Sandboxer) and is still reachable.
- All callbacks crossing the sandbox boundary are wrapped:
  - Arguments passed to sandboxed code are wrapped before being delivered.
  - Wrapped arguments returned from sandboxed code are unwrapped before being delivered to trusted code.
  - The following exceptions apply (i.e., one or both of the guarantees above do not apply):
    - Custom wrappers created by trusted code using `InstanceSandboxer.wrapFn` with passthroughs configured
    - All functions in the following globals: `bit32`, `buffer`, `coroutine`, `math`, `os`, `string`, `table`, `task`, `utf8`, `vector`, `Axes`, `BrickColor`, `CatalogSearchParams`, `Color3`, `ColorSequence`, `ColorSequenceKeypoint`, `Content`, `DateTime`, `DockWidgetPluginGuiInfo`, `Faces`, `FloatCurveKey`, `Font`, `NumberSequence`, `NumberSequenceKeypoint`, `OverlapParams`, `Path2DControlPoint`, `PathWaypoint`, `PhysicalProperties`, `Random`, `Ray`, `RaycastParams`, `Rect`, `Region3`, `Region3int16`, `RotationCurveKey`, `TweenInfo`, `UDim`, `UDim2`, `Vector2`, `Vector2int16`, `Vector3`, `Vector3int16` 
- All sandboxes receive new copies of `_G` / `shared`, instantiated as `{}`. `_G` / `shared` is not shared between sandboxes or other trusted code.
- `typeof` on wrapped Instances/RBXScriptSignals within the sandbox will return the same value as `typeof` on the underlying object in trusted code, unless `typeof` is modified or overriden. Natively, though, this will hold true.
- `require` may only access Instances allowed in `InstanceList`, even when using string paths. Only resolved targets in string paths are checked against the `InstanceList`. For example, if `require("@game/ReplicatedStorage/MyModule")` is called, only `MyModule` is checked against the `InstanceList`. The rest of the path is ignored.
- `InstanceList` is the sole source of truth for which Instances are allowed in the sandbox. If an Instance is not explicitly allowed, it will not be accessible to sandboxed code. Even if Instances are accessible via references/method returns/properties, they will be checked against the `InstanceList` before being delivered to sandboxed code. If an Instance is not allowed, it will be replaced with `nil` in the sandbox.

### What's *not* guaranteed
- Sandboxer does not attempt to limit CPU, memory, or yield behavior. It is up to the developer to implement their own resource limits for untrusted code.
- Security of Instances if they are leaked from trusted code to sandboxed code. For example, if a trusted function returns `game` to sandboxed code, the sandbox is effectively bypassed and the guarantees above no longer hold.