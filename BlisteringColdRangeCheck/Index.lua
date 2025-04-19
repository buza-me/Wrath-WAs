function Init()
  local LibRangeCheck = LibStub("LibRangeCheck-2.0")
  local scanDuration = 6
  local scanEndTime = GetTime()
  local lastScanTime = GetTime()
  local casterGUID = nil
  local casterUnitID = nil
  local spellIDs = { [70117] = true }

  local function addDerivedUnitIDs(targetTable, baseString, templateTable)
    for _, template in ipairs(templateTable) do
      table.insert(targetTable, baseString .. template)
    end
  end

  local unitIDsBaseTemplate = {
    "target", "targettarget",
  }

  local unitIDsDetailedTemplate = {
    "targettargettarget", "mouseover",
    "mouseovertarget", "mouseovertargettarget",
  }

  local unitIDs = { "focus", "focustarget", "focustargettarget" }

  for _, unitID in ipairs(unitIDsBaseTemplate) do
    table.insert(unitIDs, unitID)
  end

  for _, unitID in ipairs(unitIDsDetailedTemplate) do
    table.insert(unitIDs, unitID)
  end

  for i = 1, 25 do
    local raidUnitID = "raid" .. i

    table.insert(unitIDs, raidUnitID)
    addDerivedUnitIDs(unitIDs, raidUnitID, unitIDsBaseTemplate)
  end

  for i = 1, 25 do
    addDerivedUnitIDs(unitIDs, "raid" .. i, unitIDsDetailedTemplate)
  end

  local function getUnitIDfromGUID(guid)
    if C_NamePlate then
      local nameplateFrames = C_NamePlate.GetNamePlates()

      for i = 1, #nameplateFrames do
        local unitID = "nameplate" .. i

        if UnitExists(unitID) and UnitGUID(unitID) == guid then
          return unitID
        end
      end
    end

    for _, unitID in ipairs(unitIDs) do
      if unitID and UnitExists(unitID) and UnitGUID(unitID) == guid then
        return unitID
      end
    end

    return nil
  end

  local function getCasterUnitID()
    if not casterGUID then
      return nil
    end

    if casterUnitID and UnitExists(casterUnitID) and UnitGUID(casterUnitID) == casterGUID then
      return casterUnitID
    end

    casterUnitID = getUnitIDfromGUID(casterGUID)

    return casterUnitID
  end

  -- CLEU:SPELL_CAST_SUCCESS
  function aura_env:GripTrigger(
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
    if not spellIDs[spellID] then
      return
    end

    casterGUID = sourceGUID
    scanEndTime = GetTime() + scanDuration
  end

  -- every frame
  function aura_env:RangeTrigger(allStates)
    local now = GetTime()

    local state = allStates["range"] or {
      progressType = "timed",
      autoHide = true,
      changed = true,
      show = false,
      distance = 0,
      duration = scanDuration,
      expirationTime = now,
    }
    allStates["range"] = state

    if now >= scanEndTime then
      state.changed = true
      state.show = false

      return allStates
    end

    if now - lastScanTime < aura_env.config.scanFrequency then
      return allStates
    end

    state.changed = true
    state.show = true
    state.expirationTime = scanEndTime

    local unitID = getCasterUnitID()

    if not unitID then
      state.show = false

      return allStates
    end

    if LibRangeCheck then
      local minRange, maxRange = LibRangeCheck:GetRange(unitID)

      state.distance = maxRange
    end

    return allStates
  end
end

-- CLEU:SPELL_CAST_SUCCESS
function Trigger1(...)
  if aura_env.GripTrigger then
    return aura_env:GripTrigger(...)
  end
end

function Trigger2(allStates)
  if aura_env.RangeTrigger then
    return aura_env:RangeTrigger(allStates)
  end

  return allStates
end
