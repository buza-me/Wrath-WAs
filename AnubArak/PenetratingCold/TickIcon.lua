function Init()
  aura_env.spellIDs      = {
    66013, -- 10n
    68509, -- 10hc
    67700, -- 25n
    68510, -- 25hc
    --48068, -- Renew
    --48125, -- Shadow Word: Pain
  }
  aura_env.tickDuration  = 3.05
  aura_env.isPaused      = false
  aura_env.indicators    = {}
  aura_env.pendingEvents = {}

  function aura_env:IsCorrectSpell(spellName, spellID)
    for i = 1, #self.spellIDs do
      if spellID == self.spellIDs[i] then
        return true
      end
    end
    return false
  end
end

Init()

-- SOLTI_PENETRATING_COLD_INDICATORS_TRIGGER,CLEU:SPELL_PERIODIC_HEAL,CLEU:SPELL_PERIODIC_DAMAGE,CLEU:SPELL_PERIODIC_MISSED,SOLTI_PENETRATING_COLD_HIDE,SOLTI_PENETRATING_COLD_SHOW
function Trigger1(allStates, event, ...)
  if event == "SOLTI_PENETRATING_COLD_INDICATORS_TRIGGER" then
    local indicators, isNew = unpack({ ... })

    if not indicators or type(indicators) ~= "table" then
      return false
    end

    for key, state in pairs(allStates) do
      state.show = false
      state.changed = true
    end

    aura_env.indicators = {}

    for index, indicator in pairs(indicators) do
      aura_env.indicators[indicator.unit] = indicator

      local state = allStates[indicator.unit] or {
        progressType = "timed",
        unit = indicator.unit,
        autoHide = true
      }
      local expirationTime = state.expirationTime

      if isNew then
        expirationTime = GetTime() + aura_env.tickDuration
      end

      state.show = indicator.show and indicator.shouldDisplayIcon
      state.changed = true
      state.duration = aura_env.tickDuration - 0.05
      state.expirationTime = expirationTime

      allStates[indicator.unit] = state
    end

    return true
  end

  if event == "SOLTI_PENETRATING_COLD_HIDE" then
    aura_env.isPaused = true

    for key, state in pairs(allStates) do
      state.show = false
      state.changed = true
      aura_env.pendingEvents[key] = state.expirationTime - aura_env.tickDuration
    end

    return true
  end

  if event == "SOLTI_PENETRATING_COLD_SHOW" then
    aura_env.isPaused = false

    for destName, timeStamp in pairs(aura_env.pendingEvents) do
      local expirationTime = timeStamp + aura_env.tickDuration
      local indicator = aura_env.indicators[destName]

      if indicator and expirationTime > GetTime() then
        allStates[destName] = {
          progressType = "timed",
          unit = destName,
          autoHide = true,
          changed = true,
          show = indicator.show and indicator.shouldDisplayIcon,
          duration = aura_env.tickDuration,
          expirationTime = expirationTime,
        }
      end
    end

    aura_env.pendingEvents = {}

    return true
  end

  local timeStamp,
  subEvent,
  sourceGUID,
  sourceName,
  sourceFlags,
  destGUID,
  destName,
  destFlags,
  spellID,
  spellName,
  spellSchool,
  amount = unpack({ ... })

  if not aura_env:IsCorrectSpell(spellName, spellID) then
    return false
  end

  if aura_env.isPaused then
    aura_env.pendingEvents[destName] = GetTime()
    return false
  end

  local indicator = aura_env.indicators[destName]

  if not indicator then
    return false
  end

  allStates[destName] = {
    progressType = "timed",
    unit = destName,
    autoHide = true,
    changed = true,
    show = indicator.show and indicator.shouldDisplayIcon,
    duration = aura_env.tickDuration,
    expirationTime = GetTime() + aura_env.tickDuration,
  }

  return true
end
