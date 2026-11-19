-- Steal a Snackrot: server entry point. Builds the kitchen, then starts the game.
-- CharacterAutoLoads is off in default.project.json, so GameServer loads each
-- player's character itself once their base plot is assigned.
--
-- NOTE (2026-11-19): Rojo turns this folder into the "Server" Script itself
-- because of this init.server.luau file, so GameServer is a CHILD of this
-- script -- require(script.GameServer), NOT script.Parent.GameServer (that
-- looks in ServerScriptService, errors, and the whole game never starts:
-- no map, no character, no HUD -- just sky).

local GameServer = require(script.GameServer)

GameServer.start()
print("Steal a Snackrot is running: grab snacks off the conveyor, fill your base, beware the Midnight Hunger Wave.")
