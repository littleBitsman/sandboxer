const input = ({...})[1].BinaryInput :: buffer

const SerializationService = game:GetService("SerializationService")

const test: Model = SerializationService:DeserializeInstancesAsync(input)[1]
test.Parent = game:GetService("ServerScriptService")

const results = require(test:FindFirstChild("RunTests", true)) :: typeof(require("../test"))

return {
    BinaryOutput = buffer.create(0),
    ReturnValues = {results}
}