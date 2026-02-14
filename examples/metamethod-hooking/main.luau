local Sandboxer = require(game:GetService("ServerScriptService").Init)

local exampleFunction = function()
    local sig = game:GetService("RunService").Heartbeat
    assert(sig == nil, "Heartbeat should be nil due to the hook!")
end

Sandboxer:Sandbox(exampleFunction) -- doesn't return the function!

-- as long as the hook is in place BEFORE
-- the sandboxed code uses that metamethod, it will work as expected
Sandboxer.InstanceSandboxer.hookMetamethod(game:GetService("RunService"), "__index", function(oldIndex, inst, key, ...)
    if key == "Heartbeat" then
        print("Hooked Heartbeat!")
        -- you can return anything here, execute side effects, etc.
        return nil
    else
        return oldIndex(game:GetService("RunService"), key, ...)
    end
end)

-- Should print "Hooked Heartbeat!" and not error out, 
-- since Heartbeat is now nil
exampleFunction()
