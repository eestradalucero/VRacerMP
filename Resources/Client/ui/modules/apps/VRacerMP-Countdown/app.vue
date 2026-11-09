<!--
  VRacerMP countdown (START-4): each number appears large and shrinks while fading out.
  Lua decides the timing and sends { text, animationKey, isGo } in "VRacerMPCountdown";
  a new animationKey restarts the animation.
-->
<template>
  <div class="vracermp-countdown">
    <div
      v-if="view.visible"
      :key="view.animationKey"
      class="countdown-text"
      :class="{ go: view.isGo }"
    >{{ view.text }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })

events.on("VRacerMPCountdown", (data) => {
  view.value = data || { visible: false }
})

onMounted(() => {
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${api.serializeToLua({ action: "refresh" })}) end`)
})
</script>

<style scoped lang="scss">
.vracermp-countdown {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.countdown-text {
  font-size: 9em;
  font-weight: 800;
  line-height: 1;
  color: var(--bng-orange-400);
  text-shadow: 0 0.05em 0.2em rgba(var(--bng-off-black-rgb), 0.8);
  animation: countdown-number 1s ease-out forwards;

  &.go {
    color: var(--bng-add-green-400);
    animation: countdown-go 1.2s ease-out forwards;
  }
}

@keyframes countdown-number {
  0% { transform: scale(1.8); opacity: 0; }
  15% { transform: scale(1); opacity: 1; }
  75% { transform: scale(0.95); opacity: 1; }
  100% { transform: scale(0.8); opacity: 0.15; }
}

@keyframes countdown-go {
  0% { transform: scale(0.6); opacity: 0; }
  15% { transform: scale(1.15); opacity: 1; }
  70% { transform: scale(1); opacity: 1; }
  100% { transform: scale(1.4); opacity: 0; }
}
</style>
