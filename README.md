# [v1.4.1] Luau Sandboxer
[<img src="https://gist.github.com/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/github_source.svg" alt="Source on GitHub" height="32" />](https://github.com/littleBitsman/sandboxer)
[<img src="https://gist.github.com/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/documentation_learn.svg" alt="Source on GitHub" height="32" />](https://littlebitsman.dev/sandboxer/api/Sandboxer)
[![Tests](https://github.com/littleBitsman/sandboxer/actions/workflows/test.yml/badge.svg)](https://github.com/littleBitsman/sandboxer/actions/workflows/test.yml)

A sandboxer that can *help* protect your game when running user-provided code.

## Features
- Sandbox scripts (provided the first line of code calls the sandbox - read [here](https://littlebitsman.dev/sandboxer/api/Sandboxer))
- Sandbox functions
- Customize allowed Instances in the `InstanceList`
- Customize the sandbox environment (in Studio and at runtime)
- Disallow certain classes of Instances from being instantiated with `Instance.new` and `Instance.fromExisting`
- Hooking functions on Instances
- More planned soon (including sandbox customization at runtime!)

Let me know if there is a specific feature you are looking for that the module does not currently offer! Any and all feedback is greatly appreciated.
*Side note - if you're looking to load a chunk without using the native `loadstring` function and sandbox it, use something like vLua or [vLuau](https://github.com/littleBitsman/vLuau) instead. This involves compiling the chunk to bytecode and executing it in a VM, which is not supported by this module*
