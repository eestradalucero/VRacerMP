<!--
  VRacerMP race info (B-2): place, total time, current lap, best lap and the track's server
  record, top left. Penalty and finish rows appear only when they apply.
  Lua sends display-ready text in the "VRacerMPRaceInfo" event; this app only renders it.
  The panel hugs its content and stays anchored to the top left of the app's box.
-->
<template>
  <div v-if="view.visible" class="vracermp-race-info">
    <div class="place">{{ view.placeText }}</div>
    <div class="row">{{ view.totalTimeText }}</div>
    <div class="row">{{ view.currentLapText }}</div>
    <div class="row">{{ view.bestLapText }}</div>
    <div v-if="view.serverRecordText" class="row">{{ view.serverRecordText }}</div>
    <div v-if="view.penaltyText" class="row penalty">{{ view.penaltyText }}</div>
    <div v-if="view.finishText" class="row finish">{{ view.finishText }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })

events.on("VRacerMPRaceInfo", (data) => {
  view.value = data || { visible: false }
})

function sendAction(action) {
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${api.serializeToLua({ action })}) end`)
}

onMounted(() => sendAction("refresh"))
</script>

<style scoped lang="scss">
.vracermp-race-info {
  position: absolute;
  top: 0;
  left: 0;
  max-width: 100%;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding: 5px;
  box-sizing: border-box;
  border-left: 0.2rem solid var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.78);
  color: var(--bng-off-white);
  text-align: left;
  text-shadow: 0 1px 2px rgba(var(--bng-off-black-rgb), 0.9);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.place {
  font-size: 2em;
  font-weight: 700;
  line-height: 1.1;
  color: var(--bng-orange-400);
}

.row {
  line-height: 1.5;
}

.penalty {
  color: var(--bng-add-red-400, #ff5c5c);
}

.finish {
  font-weight: 700;
  color: var(--bng-orange-400);
}
</style>
