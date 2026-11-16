-- VRacerMP server: options set by the build, not by players.
--
-- testingCommands: commands for testing alone (`fake`). Off in the release zip; tools/build.ps1
-- turns it on only in the copy it installs on a local server (-ServerPath).

return {
  testingCommands = false,
}
