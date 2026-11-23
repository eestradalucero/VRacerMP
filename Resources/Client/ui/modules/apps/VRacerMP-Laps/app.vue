<!--
  VRacerMP laps (B-2): "Laps: 2/3" and the Retire button (FIN-8), top right. Retire swaps the
  row for a confirmation in place; it grows to the left, since the panel is anchored to the
  top right of the app's box. An unanswered confirmation goes away after 5 s.
  Lua sends { lapsText, canRetire } in the "VRacerMPLaps" event.
-->
<template>
  <div v-if="view.visible" class="vracermp-laps">
    <template v-if="!isConfirmingRetire">
      <span class="laps">{{ view.lapsText }}</span>
      <BngButton v-if="view.canRetire" accent="attentionoutlined" class="retire-button" @click="askToRetire">
        Retire
      </BngButton>
    </template>
    <template v-else>
      <span class="retire-question">Retire from the race? You'll be DNF.</span>
      <BngButton accent="attention" @click="confirmRetire">Yes, retire</BngButton>
      <BngButton accent="secondary" @click="cancelRetire">Cancel</BngButton>
    </template>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"
import { BngButton } from "@/common/components/base"

// An unanswered confirmation goes away by itself, so a stray click never retires anyone.
const CONFIRM_SECONDS = 5

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })
const isConfirmingRetire = ref(false)
let confirmTimer = null

function sendAction(action) {
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${api.serializeToLua({ action })}) end`)
}

function cancelRetire() {
  isConfirmingRetire.value = false
  clearTimeout(confirmTimer)
}

function askToRetire() {
  isConfirmingRetire.value = true
  clearTimeout(confirmTimer)
  confirmTimer = setTimeout(cancelRetire, CONFIRM_SECONDS * 1000)
}

function confirmRetire() {
  cancelRetire()
  sendAction("retire")
}

events.on("VRacerMPLaps", (data) => {
  view.value = data || { visible: false }
  if (!view.value.canRetire) cancelRetire()
})

onMounted(() => sendAction("refresh"))
onUnmounted(() => clearTimeout(confirmTimer))
</script>

<style scoped lang="scss">
.vracermp-laps {
  position: absolute;
  top: 0;
  right: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  gap: 0.6em;
  padding: 5px;
  box-sizing: border-box;
  border-left: 0.2rem solid var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.78);
  color: var(--bng-off-white);
  text-shadow: 0 1px 2px rgba(var(--bng-off-black-rgb), 0.9);
  white-space: nowrap;
}

.laps {
  text-align: left;
  font-variant-numeric: tabular-nums;
}

.retire-button {
  font-size: 0.85em;
}

.retire-question {
  font-weight: 700;
}
</style>
