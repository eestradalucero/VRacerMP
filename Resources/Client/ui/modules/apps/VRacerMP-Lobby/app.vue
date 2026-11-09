<!--
  VRacerMP lobby (REG-1 .. REG-6): shown at a track's start area or while registered.
  Lua sends what to show and what the player may do in the "VRacerMPLobby" event;
  buttons are sent back as actions to vracerMP_main.handleUiAction.
-->
<template>
  <div v-if="view.visible" class="vracermp-lobby">
    <div class="track-name">{{ view.trackName }}</div>
    <div class="status">{{ view.statusText }}</div>

    <div v-if="view.hasRace" class="settings">
      <div class="setting">
        <span class="setting-label">Laps</span>
        <template v-if="view.canEditSettings && view.isClosedTrack">
          <BngButton accent="outlined" class="step" @click="sendAction('changeLaps', { delta: -1 })">-</BngButton>
          <span class="setting-value">{{ view.laps }}</span>
          <BngButton accent="outlined" class="step" @click="sendAction('changeLaps', { delta: 1 })">+</BngButton>
        </template>
        <span v-else class="setting-value">{{ view.laps }}</span>
      </div>
      <div class="setting">
        <span class="setting-label">DNF after winner</span>
        <template v-if="view.canEditSettings">
          <BngButton accent="outlined" class="step" @click="sendAction('changeDnfTimeout', { delta: -30 })">-</BngButton>
          <span class="setting-value">{{ view.dnfTimeoutSeconds }} s</span>
          <BngButton accent="outlined" class="step" @click="sendAction('changeDnfTimeout', { delta: 30 })">+</BngButton>
        </template>
        <span v-else class="setting-value">{{ view.dnfTimeoutSeconds }} s</span>
      </div>
    </div>

    <div v-if="view.racers && view.racers.length" class="racers">
      <div v-for="racer in view.racers" :key="racer.position" class="racer" :class="{ me: racer.isMe }">
        <span class="racer-position">{{ racer.position }}</span>
        <span class="racer-name">{{ racer.name }}</span>
        <span v-if="racer.isOwner" class="racer-owner">owner</span>
      </div>
    </div>

    <div v-if="view.isRegistrationOpen" class="buttons">
      <BngButton v-if="view.canRegister" accent="main" @click="sendAction('register')">Register</BngButton>
      <BngButton v-if="view.isRegistered" accent="secondary" @click="sendAction('unregister')">Unregister</BngButton>
      <BngButton v-if="view.isOwner" accent="main" @click="sendAction('startRace')">Start race</BngButton>
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

events.on("VRacerMPLobby", (data) => {
  view.value = data || { visible: false }
})

function sendAction(action, details = {}) {
  const payload = api.serializeToLua({ ...details, action })
  api.engineLua(`if vracerMP_main then vracerMP_main.handleUiAction(${payload}) end`)
}

onMounted(() => sendAction("refresh"))
</script>

<style scoped lang="scss">
.vracermp-lobby {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5em;
  padding: 0.7em 0.8em;
  box-sizing: border-box;
  overflow-y: auto;
  border-left: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.85);
  color: var(--bng-off-white);
}

.track-name {
  font-size: 1.3em;
  font-weight: 700;
  color: var(--bng-orange-400);
}

.status {
  color: var(--bng-cool-gray-300);
}

.settings {
  display: flex;
  flex-direction: column;
  gap: 0.3em;
}

.setting {
  display: flex;
  align-items: center;
  gap: 0.4em;
}

.setting-label {
  flex: 1;
  color: var(--bng-cool-gray-300);
}

.setting-value {
  min-width: 3.5em;
  text-align: center;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.step {
  min-width: 2em;
  margin: 0;
}

.racers {
  display: flex;
  flex-direction: column;
  gap: 0.15em;
  padding-top: 0.4em;
  border-top: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.25);
}

.racer {
  display: flex;
  gap: 0.5em;
  padding: 0.15em 0.3em;
  border-radius: var(--bng-corners-1, 3px);

  &.me {
    background: rgba(var(--bng-orange-500-rgb), 0.2);
  }
}

.racer-position {
  min-width: 1.5em;
  color: var(--bng-cool-gray-300);
}

.racer-name {
  flex: 1;
}

.racer-owner {
  font-size: 0.85em;
  color: var(--bng-orange-300);
}

.buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4em;
  margin-top: auto;
}
</style>
