-- Steal a Snackrot: server entry point.
-- Rojo turns this folder into the Script itself, so GameServer is a
-- child of this script -- require it as script.GameServer, never as a
-- child of the script's parent (that looks in ServerScriptService and
-- the whole game never starts).
local GameServer = require(script.GameServer)
GameServer.start()
