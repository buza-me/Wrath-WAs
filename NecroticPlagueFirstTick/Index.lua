function Init()
  local trackedSpellID = 70338
  local trackedSpellName, _, trackedSpellTexture = GetSpellInfo(trackedSpellID)
  local duration = 4.9

  -- CLEU:SPELL_AURA_APPLIED:SPELL_AURA_APPLIED_DOSE:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED:UNIT_DIED
  function aura_env:Trigger(
      allStates,
      event,
      timeStamp,
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
      amount
  )
    local shouldStop =
        spellName ~= trackedSpellName
        or not UnitExists(destName)
        or not UnitIsFriend("player", destName)

    if shouldStop then
      return allStates
    end

    local now = GetTime()

    local shouldReset =
        allStates[destName]
        and (
          subEvent == "SPELL_AURA_REMOVED"
          or subEvent == "UNIT_DIED"
        )

    if shouldReset then
      allStates[destName].changed = true
      allStates[destName].show = false

      return allStates
    end

    allStates[destName] = {
      progressType = "timed",
      expirationTime = now + duration,
      duration = duration,
      icon = trackedSpellTexture,
      unit = destName,
      autoHide = true,
      changed = true,
      show = true,
      index = now,
    }

    return allStates
  end
end

function Trigger1(...)
  if aura_env.Trigger then
    return aura_env:Trigger(...)
  end
end
