local input = ({...})[1] :: buffer

local SerializationService = game:GetService("SerializationService")

local test: ModuleScript = SerializationService:DeserializeInstancesAsync(input)[1]
test.Parent = workspace

local results = require(test) :: typeof(require("../test"))

return {
    ReturnValues = {results, game:GetService("LogService"):GetLogHistory()}
}