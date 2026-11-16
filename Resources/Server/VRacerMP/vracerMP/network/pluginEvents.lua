-- VRacerMP server: events for other server plugins (edge: uses MP.*). B-4.
-- Payloads are sent as JSON text, since BeamMP events between plugins carry strings.
-- The events and their payloads are documented in docs/commands.md.

local jsonEncoder = require("vracerMP/shared/jsonEncoder")

local M = {}

local function publish(eventName, payload)
  MP.TriggerGlobalEvent(eventName, jsonEncoder.encode(payload or {}))
end

M.publish = publish

return M
