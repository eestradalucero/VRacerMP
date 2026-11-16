<!--
  VRacerMP results (FIN-5): final standings. Closes with the Close button, the bindable
  "Close VRacerMP results" control, after 30 s, or when a new race starts (B-6).
  Our own row is highlighted (B-7). Lua sends { title, rows, closeText } in "VRacerMPResults".
-->
<template>
  <div v-if="view.visible" class="vracermp-results">
    <div class="title">{{ view.title }}</div>

    <div class="table">
      <div class="row header">
        <span class="col-position">Pos</span>
        <span class="col-name">Name</span>
        <span class="col-time">Time</span>
        <span class="col-penalty">Penalties</span>
        <span class="col-time">Total</span>
        <span class="col-gap">Gap</span>
        <span class="col-time">Best lap</span>
        <span class="col-status">Status</span>
      </div>
      <div
        v-for="row in view.rows"
        :key="row.position + row.name"
        class="row"
        :class="{ dnf: !row.isFinished, winner: row.position === '1', me: row.isMe }"
      >
        <span class="col-position">{{ row.position }}</span>
        <span class="col-name">{{ row.name }}</span>
        <span class="col-time">{{ row.rawTime }}</span>
        <span class="col-penalty">{{ row.penaltyTime }}</span>
        <span class="col-time col-total">{{ row.totalTime }}</span>
        <span class="col-gap">{{ row.gapToWinner }}</span>
        <span class="col-time">{{ row.bestLap }}</span>
        <span class="col-status">{{ row.status }}</span>
      </div>
    </div>

    <div class="buttons">
      <span v-if="view.closeText" class="close-text">{{ view.closeText }}</span>
      <BngButton accent="main" @click="sendAction('closeResults')">Close</BngButton>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { useEvents } from "@/services/events"
import { BngButton } from "@/common/components/base"

const { api } = useBridge()
const events = useEvents()
const view = ref({ visible: false })

events.on("VRacerMPResults", (data) => {
  view.value = data || { visible: false }
})

function sendAction(action, details = {}) {
  const payload = api.serializeToLua({ ...details, action })
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${payload}) end`)
}

onMounted(() => sendAction("refresh"))
</script>

<style scoped lang="scss">
.vracermp-results {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.6em;
  padding: 0.9em 1em;
  box-sizing: border-box;
  border-top: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.92);
  color: var(--bng-off-white);
}

.title {
  font-size: 1.4em;
  font-weight: 700;
  color: var(--bng-orange-400);
}

.table {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.15em;
}

.row {
  display: flex;
  align-items: center;
  gap: 0.6em;
  padding: 0.3em 0.4em;
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-cool-gray-800-rgb), 0.5);
  font-variant-numeric: tabular-nums;

  &.header {
    background: none;
    font-size: 0.85em;
    color: var(--bng-cool-gray-300);
  }

  &.winner .col-position {
    font-weight: 700;
    color: var(--bng-orange-400);
  }

  &.me {
    background: rgba(var(--bng-orange-500-rgb), 0.3);
    box-shadow: inset 0.2em 0 0 var(--bng-orange-400);
    font-weight: 700;
  }

  &.dnf {
    color: var(--bng-cool-gray-300);
  }
}

.col-position { width: 2.5em; }
.col-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-time { width: 6em; text-align: right; }
.col-gap { width: 6em; text-align: right; color: var(--bng-cool-gray-300); }
.col-penalty { width: 6.5em; text-align: right; color: var(--bng-add-red-400, #ff5c5c); }
.col-total { font-weight: 700; }
.col-status { width: 7em; text-align: right; }

.buttons {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75em;
}

.close-text {
  color: var(--bng-cool-gray-300);
  font-variant-numeric: tabular-nums;
}
</style>
