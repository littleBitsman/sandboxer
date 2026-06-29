---
sidebar_position: 1
---

# Introduction

A Luau sandboxer that can *help* protect your game when running user-provided code.

## Features

* Sandboxes scripts or individual functions
* Wraps `Instance`s and `RBXScriptSignal`s automatically
* Restricts access to configurable Roblox classes and instances
* Configurable sandbox globals
* Optional tracking of created `Instance`s and `RBXScriptConnection`s for cleanup
* Support for sandboxing dynamically loaded code through `SandboxString`
* Low-level APIs for extending or customizing sandbox behavior

::::tip
Let me know if there is a specific feature you are looking for that the module does not currently offer! Any and all feedback is greatly appreciated.
:::note[Side Note]
If you're looking to load a chunk without using the native `loadstring` function and sandbox it, use something like vLua or [vLuau](https://github.com/littleBitsman/vLuau) instead. This involves compiling the chunk to bytecode and executing it in a VM, **which is explicitly not supported by this module**.
:::
::::

:::warning
Due to the way this module works (internally, it uses `getfenv` and `setfenv`), Luau optimizations for related scripts will be disabled at runtime. **This behavior is built into the C backend of Luau and cannot be modified, even via** `--!optimize` **directives**. Keep this in mind if you are doing something that absolutely cannot compromise on performance.
:::

:::danger[Important!]
If you find a security vulnerability or sandbox escape with the unmodified version of the module, please do not hesitate to DM me on DevForum or on Discord (littlebitsman)!
:::

## API Tags

Throughout the documentation, members may be marked with one or more tags.

| Tag | Meaning | 
| --- | ------- |
| **Basic** | Commonly used APIs intended for most users. |
| **Customization** | APIs useful for modifying Sandboxer's behavior. |
| **Advanced** | Lower-level APIs intended for advanced use cases. |
| **Internal** | APIs primarily intended for Sandboxer's implementation. These should generally not be called directly unless you understand their behavior. |