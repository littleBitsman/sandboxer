# example-metamethod-hooking

Demonstrates how to hook metamethods in a sandboxed environment. In this example, we hook the `__index` metamethod of the `game` object to return `nil` for the `RunService.Heartbeat` property, effectively hiding it from the sandboxed code.