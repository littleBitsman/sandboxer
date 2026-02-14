local Sandboxer = require(game:GetService("ServerScriptService").Init)

local exampleFunction = function()
    print("Hello, world!")
    print(getfenv) -- nil
    print(debug) -- nil

    local num = Instance.new("NumberValue")
    game:GetService("TweenService"):Create(num, TweenInfo.new(1), { Value = 2 }):Play()

    task.wait(2)
    -- sorry i just wanted the back to the future reference
    assert(num.Value == 2, "Great Scott! Tweens have broken!")
    num:Destroy()
end

Sandboxer:Sandbox(exampleFunction) -- doesn't return the function!
exampleFunction()

print(getfenv, debug) -- NOT nil!

-- sandbox the whole script (imagine this is at the top)
Sandboxer:Init()
print(getfenv, debug) -- nil!
-- similar to inside exampleFunction
