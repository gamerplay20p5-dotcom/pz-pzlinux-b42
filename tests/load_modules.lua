-- Package loading only: no windows are opened, and no native engine runs.
local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/"):match("^(.*)/load_modules.lua$")
local Fixture = dofile(path .. "/fixture.lua")
local world = Fixture.new(arg[1])
world:load("ISPZLinuxVariablesTables")
for index = 2, #arg do world:load(arg[index]) end
print("PASS module initialization: " .. arg[1] .. " (native boundaries simulated)")
