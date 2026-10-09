-- Server entry point: builds the map first, then starts every service in dependency order.

local MapBuilder = require(script.Parent.World.MapBuilder)
local RemoteGuard = require(script.Parent.Services.RemoteGuard)
local DataService = require(script.Parent.Services.DataService)
local PlotService = require(script.Parent.Services.PlotService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local DebugCommands = require(script.Parent.DebugCommands)

local map = MapBuilder.Build()

RemoteGuard.Init()
RollService.Init()
DataService.Init()
PlotService.Init(map.Plots)
ScanService.Init()
DebugCommands.Init()

print("[Main] Supernatural Relic Collector server ready.")
