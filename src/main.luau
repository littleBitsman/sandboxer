local input = ({...})[1].BinaryInput :: buffer

local SerializationService = game:GetService("SerializationService")

local test: Model = SerializationService:DeserializeInstancesAsync(input)[1]
test.Parent = game:GetService("ServerScriptService")

local results = require(test:FindFirstChild("RunTests", true)) :: typeof(require("../test"))

return {
    BinaryOutput = buffer.create(0),
    ReturnValues = {results}
}