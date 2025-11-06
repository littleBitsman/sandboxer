local input = ({...})[1].BinaryInput :: buffer

local SerializationService = game:GetService("SerializationService")

local test: ModuleScript = SerializationService:DeserializeInstancesAsync(input)[1]
test.Parent = workspace

local results = require(test) :: typeof(require("../test"))

return {
    BinaryOutput = buffer.create(0),
    ReturnValues = {results}
}