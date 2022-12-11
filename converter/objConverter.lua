
-- Made by Xella#8655

local objLoader = require("objLoader")

term.write("> filename: ")
local filename = read()

local model = objLoader.load(filename)

print("Serializing model...")
if #model > 5000 then
	term.setTextColor(colors.orange)
	print("Model has " .. (#model) .. " polygons. This can take a while...")
	term.setTextColor(colors.white)
end
model = textutils.serialise(model)

print("Saving model...")
local file = fs.open("models/" .. filename, "w") -- Make sure you save the model in the models folder with a new name
file.write(model)
file.close()

term.setTextColor(colors.lime)
print("Done!")
term.setTextColor(colors.white)
