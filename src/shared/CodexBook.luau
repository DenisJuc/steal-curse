-- The game's Codex built from the real config, shared by CodexService and the UI.

local Codex = require(script.Parent.Codex)
local CodexConfig = require(script.Parent.CodexConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local RelicConfig = require(script.Parent.RelicConfig)

return Codex.build(CodexConfig, RelicConfig.Relics, RarityConfig.Tiers, RelicConfig.Families)
