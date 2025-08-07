# example-validate-code

This example shows a possible way you could validate code
before allowing it to be passed to the sandbox and executed.

This assumes an input `rbxm`/`rbxmx` file, and checks all scripts
to have the first line of code be the sandbox initializer
(assumed at `game.ServerScriptService.Init`).

Written in Rust.