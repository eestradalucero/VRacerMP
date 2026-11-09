<!--
  VRacerMP race panel (UI-1 .. UI-9): position, lap, race time, best lap, pathnodes, gaps.
  Lua sends display-ready text in the "VRacerMPRace" event; this app only renders it.
-->
<template>
  <div v-if="view.visible" class="vracermp-race-panel">
    <div class="top-row">
      <div class="position">
        <span class="position-value">{{ view.position }}</span>
        <span class="position-count">{{ view.racerCount }}</span>
      </div>
      <BngSimpleDataDisplay class="lap" label="Lap" :value="view.lap" />
    </div>

    <div class="stats">
      <BngSimpleDataDisplay label="Time" :value="view.raceTime" numeric />
      <BngSimpleDataDisplay label="Best lap" :value="view.bestLap" numeric />
      <BngSimpleDataDisplay label="Pathnodes" :value="view.pathnodes" />
    </div>

    <div v-if="view.aheadGap || view.behindGap" class="gaps">
      <span v-if="view.aheadGap" class="gap gap-ahead">{{ view.aheadGap }}</span>
      <span v-if="view.behindGap" class="gap gap-behind">{{ view.behindGap }}</span>
    </div>

    <div v-if="view.finishText" class="finish">{{ view.finishText }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"
import { BngSimpleDataDisplay } from "@/common/components/appsUtilities"

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })

events.on("VRacerMPRace", (data) => {
  view.value = data || { visible: false }
})

onMounted(() => {
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${api.serializeToLua({ action: "refresh" })}) end`)
})
</script>

<style scoped lang="scss">
.vracermp-race-panel {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.4em;
  padding: 0.6em 0.75em;
  box-sizing: border-box;
  border-left: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.78);
  color: var(--bng-off-white);
  text-shadow: 0 1px 2px rgba(var(--bng-off-black-rgb), 0.9);
}

.top-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.position-value {
  font-size: 2.4em;
  font-weight: 700;
  color: var(--bng-orange-400);
}

.position-count {
  margin-left: 0.3em;
  font-size: 1.1em;
  color: var(--bng-cool-gray-300);
}

.stats {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 0.4em;
}

.gaps {
  display: flex;
  gap: 0.75em;
  font-size: 1.25em;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.gap-ahead {
  color: var(--bng-add-red-400, #ff5c5c);
}

.gap-behind {
  color: var(--bng-add-green-400, #5cd65c);
}

.finish {
  padding-top: 0.3em;
  border-top: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.25);
  font-size: 1.15em;
  font-weight: 700;
  color: var(--bng-orange-400);
}
</style>
