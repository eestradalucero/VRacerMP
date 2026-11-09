<!--
  VRacerMP results (FIN-5): final standings, shown until the player closes it or a new race starts.
  Lua sends { title, rows } in "VRacerMPResults"; Close is sent back as an action.
-->
<template>
  <div v-if="view.visible" class="vracermp-results">
    <div class="title">{{ view.title }}</div>

    <div class="table">
      <div class="row header">
        <span class="col-position">Pos</span>
        <span class="col-name">Name</span>
        <span class="col-time">Total</span>
        <span class="col-gap">Gap</span>
        <span class="col-time">Best lap</span>
        <span class="col-status">Status</span>
      </div>
      <div
        v-for="row in view.rows"
        :key="row.position + row.name"
        class="row"
        :class="{ dnf: !row.isFinished, winner: row.position === '1' }"
      >
        <span class="col-position">{{ row.position }}</span>
        <span class="col-name">{{ row.name }}</span>
        <span class="col-time">{{ row.totalTime }}</span>
        <span class="col-gap">{{ row.gapToWinner }}</span>
        <span class="col-time">{{ row.bestLap }}</span>
        <span class="col-status">{{ row.status }}</span>
      </div>
    </div>

    <div class="buttons">
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

  &.winner {
    background: rgba(var(--bng-orange-500-rgb), 0.25);
  }

  &.dnf {
    color: var(--bng-cool-gray-300);
  }
}

.col-position { width: 2.5em; }
.col-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-time { width: 6em; text-align: right; }
.col-gap { width: 6em; text-align: right; color: var(--bng-cool-gray-300); }
.col-status { width: 7em; text-align: right; }

.buttons {
  display: flex;
  justify-content: flex-end;
}
</style>
