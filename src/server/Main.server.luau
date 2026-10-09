-- Server entry point: builds the map first, then starts every service in dependency order.

local MapBuilder = require(script.Parent.World.MapBuilder)
local RemoteGuard = require(script.Parent.Services.RemoteGuard)
local DataService = require(script.Parent.Services.DataService)
local PlotService = require(script.Parent.Services.PlotService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local SignalService = require(script.Parent.Services.SignalService)
local BindService = require(script.Parent.Services.BindService)
local DebugCommands = require(script.Parent.DebugCommands)

local map = MapBuilder.Build()

RemoteGuard.Init()
RollService.Init()
DataService.Init()
PlotService.Init(map.Plots)
ScanService.Init()
SignalService.Init(map.HuntArea.SpawnPoints)
BindService.Init()
DebugCommands.Init(map)

print("[Main] Supernatural Relic Collector server ready.")
