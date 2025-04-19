function Init()
  local pairs, select = pairs, select
  local UnitExists, UnitClass, UnitName = UnitExists, UnitClass, UnitName

  local UPDATE_EVENT = "DIVINE_AURA_MASTERY_TRACKER_AURA_UPDATE_EVENT"
  local AM_SPELL_ID = 31821
  local AM_DURATION = 6
  local PROBLEM_TYPES = {
    AURA_TAKEN = "AURA_TAKEN",
    NO_AURA = "NO_AURA",
    RANGE = "RANGE",
    NONE = "NONE",
  }
  local auraMasteries = {}
  local paladins = {}

  local auras = {
    [48942] = {},
    [54043] = {},
    [19746] = {},
    [48943] = {},
    [48945] = {},
    [48947] = {},
    [32223] = {},
  }

  local localizedNames = {}

  local textures = {
    [AM_SPELL_ID] = select(3, AM_SPELL_ID),
  }

  for spellID in pairs(auras) do
    local localizedName, _, texture = GetSpellInfo(spellID)

    localizedNames[spellID] = localizedName
    textures[spellID] = texture
  end

  local function getAuraSrcUnitID(unitID, auraID)
    local auraName = localizedNames[auraID]
    local srcID = select(8, WA_GetUnitBuff(unitID, auraName))

    return srcID
  end

  local function getPaladinAura(unitID)
    for spellID, _ in pairs(auras) do
      local srcUnitID = getAuraSrcUnitID(unitID, spellID)

      if UnitExists(srcUnitID) and UnitName(srcUnitID) == UnitName(unitID) then
        return spellID
      end
    end

    return "NONE"
  end

  local function wipeAllFields()
    paladins = {}

    for spellID, _ in pairs(auras) do
      auras[spellID] = {}
    end
  end

  local function removePaladinLeaver(unitName)
    local auraSpellID = paladins[unitName]

    if auraSpellID and auras[auraSpellID] then
      auras[auraSpellID][unitName] = nil
    end

    paladins[unitName] = nil
  end

  local function removePaladinLeavers()
    for unitName in pairs(paladins) do
      local shouldRemove =
          unitName ~= UnitName("player")
          and not UnitInRaid(unitName)
          and not UnitInParty(unitName)

      if shouldRemove then
        removePaladinLeaver(unitName)
      end
    end
  end

  local function addPaladin(unitID)
    local unitName = UnitName(unitID)

    if unitName == UNKNOWNOBJECT or paladins[unitName] then
      return
    end

    local auraID = getPaladinAura(unitID)

    paladins[unitName] = auraID

    if auraID ~= "NONE" then
      auras[auraID][unitName] = true
    end
  end

  local function addPaladins()
    for unitID in WA_IterateGroupMembers() do
      local _, class = UnitClass(unitID)

      if class == "PALADIN" then
        addPaladin(unitID)
      end
    end
  end

  local function updateIconStates()
    WeakAuras.ScanEvents(UPDATE_EVENT)
  end

  local function onRosterUpdate()
    removePaladinLeavers()
    addPaladins()
  end

  local function onInit()
    wipeAllFields()
    addPaladins()
  end

  local function onUnitAura(unitID)
    local unitName = UnitExists(unitID) and UnitName(unitID)

    if unitName and paladins[unitName] then
      local newAura = getPaladinAura(unitID)
      local oldAura = paladins[unitName]

      if oldAura == newAura then
        return
      end

      if oldAura ~= "NONE" then
        auras[oldAura][unitName] = nil
      end

      paladins[unitName] = newAura

      if newAura ~= "NONE" then
        auras[newAura][unitName] = true
      end

      updateIconStates()
    end
  end

  local function buildDummyStates(allStates)
    local states = {
      {
        caster = "Divine",
        icon = textures[19746],
        auraName = localizedNames[19746],
        problemType = PROBLEM_TYPES.NONE
      },
      {
        caster = "Solti",
        icon = textures[AM_SPELL_ID],
        auraName = "",
        problemType = PROBLEM_TYPES.NO_AURA
      },
      {
        caster = "Scrublama",
        icon = textures[32223],
        auraName = localizedNames[32223],
        problemType = PROBLEM_TYPES.RANGE
      },
      {
        caster = "Johndoe",
        icon = textures[54043],
        auraName = localizedNames[54043],
        problemType = PROBLEM_TYPES.AURA_TAKEN,
        problem = "Scrublama"
      },
    }

    for i, state in pairs(states) do
      allStates["DUMMY_STATE_" .. i] = {
        progressType = "timed",
        show = true,
        changed = true,
        autoHide = true,
        duration = AM_DURATION,
        expirationTime = AM_DURATION + GetTime(),
        auraMasterySource = state.caster,
        icon = state.icon,
        auraName = state.auraName,
        problem = state.problem,
        problemType = state.problemType,
        index = i,
      }
    end
  end

  -- RAID_ROSTER_UPDATE, PARTY_MEMBERS_CHANGED, UNIT_AURA
  function aura_env:Trigger1(event, ...)
    if event == "UNIT_AURA" then
      onUnitAura(...)
    end

    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
      onRosterUpdate()
    end

    return false
  end

  -- CLEU:SPELL_AURA_APPLIED:SPELL_AURA_REMOVED,DIVINE_AURA_MASTERY_TRACKER_AURA_UPDATE_EVENT
  function aura_env:Trigger2(
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
    local shouldAbort =
        event == "OPTIONS" or (
          event == "COMBAT_LOG_EVENT_UNFILTERED" and (
            not paladins[sourceName] or (
              spellID ~= AM_SPELL_ID
              and not auras[spellID]
            )
          )
        )

    if event == "OPTIONS" and WeakAuras.IsOptionsOpen() then
      return buildDummyStates(allStates)
    end

    if shouldAbort then
      return allStates
    end

    if subEvent == "SPELL_AURA_APPLIED" and spellID == AM_SPELL_ID then
      auraMasteries[sourceName] = GetTime()
    end

    if subEvent == "SPELL_AURA_REMOVED" and spellID == AM_SPELL_ID then
      auraMasteries[sourceName] = nil
    end

    for name, state in pairs(allStates) do
      state.show = false
      state.changed = true
    end

    for name, appliedAt in pairs(auraMasteries) do
      local state = {
        progressType = "timed",
        show = true,
        changed = true,
        autoHide = true,
        duration = AM_DURATION,
        expirationTime = AM_DURATION + appliedAt,
        auraMasterySource = name,
        icon = textures[AM_SPELL_ID],
        auraName = "",
        problem = "",
        problemType = PROBLEM_TYPES.NO_AURA,
      }
      allStates[name] = state

      local modifiedAuraSpellID = nil

      for auraSpellID, auraCasters in pairs(auras) do
        if auraCasters[name] then
          modifiedAuraSpellID = auraSpellID

          break;
        end
      end

      if modifiedAuraSpellID then
        local auraOnPlayerSourceUnitID = getAuraSrcUnitID("player", modifiedAuraSpellID)
        local auraOnPlayerSourceName = UnitExists(auraOnPlayerSourceUnitID) and UnitName(auraOnPlayerSourceUnitID)

        state.icon = textures[modifiedAuraSpellID]
        state.auraName = localizedNames[modifiedAuraSpellID]

        if not auraOnPlayerSourceName or (auraOnPlayerSourceName ~= name and aura_env.config.doesAuraMasteryOverrideOwner) then
          state.problemType = PROBLEM_TYPES.RANGE
        elseif auraOnPlayerSourceName ~= name and not aura_env.config.doesAuraMasteryOverrideOwner then
          state.problemType = PROBLEM_TYPES.AURA_TAKEN
          state.problem = auraOnPlayerSourceName
        else
          state.problemType = PROBLEM_TYPES.NONE
        end
      end
    end

    return allStates
  end

  onInit()



  local trigger2CustomVariables = {
    auraName = "string",
    auraMasterySource = "string",
    problem = "string",
    problemType = "string"
  }
end

local function TriggerFN(t)
  return t[2]
end
