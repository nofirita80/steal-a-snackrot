-- Steal a Snackrot — server entry point.
-- Rojo turns this folder into the Script itself, so GameServer is a
-- child of this script. Require it as script.GameServer, never as a
-- child of the script's parent (that looks in ServerScriptService
-- and the whole game never starts). start() builds the world, wires
-- the remotes and spawns the game loops.
local GameServer = require(script.GameServer)
GameServer.start()
