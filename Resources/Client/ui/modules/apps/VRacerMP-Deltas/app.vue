<!--
  VRacerMP deltas (B-2): the gap to the racer ahead (red) and behind (green), centered, no
  background. Each fades in over 0.2 s when its gap arrives, stays 3 s and fades out over
  0.2 s; Lua decides when each is shown (ui/deltaDisplay.lua) in the "VRacerMPDeltas" event.
-->
<template>
  <div v-if="view.visible" class="vracermp-deltas">
    <div class="delta ahead" :class="{ shown: view.ahead.isShown }">{{ view.ahead.text }}</div>
    <div class="delta behind" :class="{ shown: view.behind.isShown }">{{ view.behind.text }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })

events.on("VRacerMPDeltas", (data) => {
  view.value = data || { visible: false }
})

function sendAction(action) {
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${api.serializeToLua({ action })}) end`)
}

onMounted(() => sendAction("refresh"))
</script>

<style scoped lang="scss">
.vracermp-deltas {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  text-align: center;
  font-size: 2em;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  line-height: 1.25;
  // No background: a shadow keeps the numbers readable over bright scenery.
  text-shadow: 0 0 4px rgba(var(--bng-off-black-rgb), 0.9), 0 1px 2px rgba(var(--bng-off-black-rgb), 0.9);
}

.delta {
  opacity: 0;
  transition: opacity 0.2s linear;

  &.shown {
    opacity: 1;
  }
}

.ahead {
  color: var(--bng-add-red-400, #ff5c5c);
}

.behind {
  color: var(--bng-add-green-400, #4cd964);
}
</style>
