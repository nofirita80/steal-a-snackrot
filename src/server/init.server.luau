-- Steal a Snackrot: server entry point. Builds the kitchen, then starts the game.
-- CharacterAutoLoads is off in default.project.json, so GameServer loads each
-- player's character itself once their base plot is assigned.

local GameServer = require(script.Parent.GameServer)

GameServer.start()
print("Steal a Snackrot is running: grab snacks off the conveyor, fill your base, beware the Midnight Hunger Wave.")
