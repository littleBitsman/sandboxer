-- Make sure TrackInstances and TrackRBXScriptConnections are true
-- before running this example!

local Sandboxer = require(game:GetService("ServerScriptService").Init)
assert(
    Sandboxer.Config.TrackInstances and Sandboxer.Config.TrackRBXScriptConnections,
    "Please enable TrackInstances and TrackRBXScriptConnections in the Config module before running this example!"
)

local exampleFunction = function()
    -- any instances made in this sandboxed function will be tracked,
    -- as well as any connections!

    local t = {}
    for i = 1, 100 do
        local part = Instance.new("Part") -- tracked!
        part.Position = Vector3.new(
            math.random(-100, 100),
            math.random(-100, 100),
            math.random(-100, 100)
        )
        part.Parent = workspace
        table.insert(t, part)

        -- also tracked!
        part.Changed:Connect(function(a) 
            print(a, "changed!")
        end)
    end
end

Sandboxer:Sandbox(exampleFunction) -- doesn't return the function!
exampleFunction()

assert(#Sandboxer.InstanceSandboxer.NewInstances == 100)

for part, _ in Sandboxer.InstanceSandboxer.NewInstances do
    -- Should print some "Name" a total of 100 times
    part.Name = tostring(math.random(1, 1000))
end

for connection, _ in Sandboxer.InstanceSandboxer.RBXScriptConnections do
    -- Disconnect those connections for printing property change
    connection:Disconnect()
end

for part, _ in Sandboxer.InstanceSandboxer.NewInstances do
    -- Should not print anything
    part.Name = tostring(math.random(1, 1000))
end

for part, _ in Sandboxer.InstanceSandboxer.NewInstances do
    -- Cleanup
    part:Destroy() 
end

-- drops the function, allowing GC to cleanup everything
-- (since the table in the function prevents the parts from
--  being collected, until the owning function is collected)
exampleFunction = nil