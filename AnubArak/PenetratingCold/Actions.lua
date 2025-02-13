local function Init()
  aura_env.spellIDs                    = {
    66013, -- 10n
    68509, -- 10hc
    67700, -- 25n
    68510, -- 25hc
    --48068, -- Renew
    --48125, -- Shadow Word: Pain
  }
  aura_env.indicators                  = {}
  aura_env.roster                      = {} -- name -> group number
  aura_env.outputChannels              = {
    [1] = "RAID",
    [2] = "PARTY",
    [3] = "RAID_WARNING",
    [4] = "GUILD",
    [5] = "OFFICER",
    [6] = "SAY",
    [7] = "YELL",
    [8] = "WHISPER"
  }
  aura_env.hideActionTrigger           = "SOLTI_PENETRATING_COLD_HIDE"
  aura_env.showActionTrigger           = "SOLTI_PENETRATING_COLD_SHOW"
  local indicatorsTrigger              = "SOLTI_PENETRATING_COLD_INDICATORS_TRIGGER"
  local AceTimer                       = LibStub("AceTimer-3.0")
  local indicatorsTriggerDispatchDelay = 0.03
  local debuffReportDispatchDelay      = 0.03
  local showActionTriggerDispatchDelay = 1.1
  aura_env.indicatorDispatchTimerID    = nil
  aura_env.debuffReportTimerID         = nil

  function aura_env.CompareUnitObjects(a, b)
    if a.group ~= b.group then
      return a.group < b.group
    end
    return a.unit < b.unit
  end

  function aura_env.FilterInPlace(tbl, predicate)
    local writeIndex = 1
    for readIndex = 1, #tbl do
      if predicate(tbl[readIndex]) then
        tbl[writeIndex] = tbl[readIndex]
        writeIndex = writeIndex + 1
      end
    end
    -- Remove trailing elements
    for i = writeIndex, #tbl do
      tbl[i] = nil
    end
  end

  function aura_env:UpdateRoster()
    self.roster = {}

    for i = 1, GetNumGroupMembers() do
      local name, _, subgroup = GetRaidRosterInfo(i);

      if name and subgroup then
        self.roster[name] = subgroup
      end
    end
  end

  function aura_env:ToggleIndicators()
    local env = aura_env

    WeakAuras.ScanEvents(env.hideActionTrigger)

    AceTimer:ScheduleTimer(
      function()
        WeakAuras.ScanEvents(env.showActionTrigger)
      end,
      showActionTriggerDispatchDelay
    )
  end

  function aura_env:DispatchIndicators(isNew)
    local env = self

    if env.indicatorDispatchTimerID then
      AceTimer:CancelTimer(env.indicatorDispatchTimerID)
    end

    env.indicatorDispatchTimerID = AceTimer:ScheduleTimer(
      function()
        env.indicatorDispatchTimerID = nil
        WeakAuras.ScanEvents(indicatorsTrigger, env.indicators, not not isNew)
      end,
      indicatorsTriggerDispatchDelay
    )
  end

  function aura_env:SendChatMessage(message, channel)
    if channel == "WHISPER" then
      SendChatMessage(message, "WHISPER", nil, UnitName("player"))
    else
      SendChatMessage(message, channel)
    end
  end

  function aura_env:ReportNewDebuffs()
    local env = self

    if env.debuffReportTimerID then
      AceTimer:CancelTimer(env.debuffReportTimerID)
    end

    env.debuffReportTimerID = AceTimer:ScheduleTimer(
      function()
        env.debuffReportTimerID = nil

        local messageParts = {}

        for index, indicator in pairs(env.indicators) do
          messageParts[index] = format("%s: %s", index, indicator.unit)
        end

        local chatChannel = env.outputChannels[env.config.debuffMessageChannel]
        local message = table.concat(messageParts, ", ")

        env:SendChatMessage(message, chatChannel)
      end,
      debuffReportDispatchDelay
    )
  end

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

aura_env:UpdateRoster()

-- CLEU:UNIT_DIED,CLEU:SPELL_AURA_REMOVED,CLEU:SPELL_AURA_APPLIED,SOLTI_PENETRATING_COLD_HIDE,SOLTI_PENETRATING_COLD_SHOW
function Trigger1(
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
  local shouldAbort = not aura_env:IsCorrectSpell(spellName, spellID)
      and subEvent ~= "UNIT_DIED"
      and event ~= aura_env.hideActionTrigger
      and event ~= aura_env.showActionTrigger

  if shouldAbort then
    return false
  end

  if subEvent == "SPELL_AURA_REMOVED" or subEvent == "UNIT_DIED" then
    for index, indicator in pairs(aura_env.indicators) do
      if indicator.unit == destName then
        indicator.show = false

        if aura_env.config.shouldReportDeath and subEvent == "UNIT_DIED" then
          local chatChannel = aura_env.outputChannels[aura_env.config.deathMessageChannel]
          local message = format("%s died, PC Number: %d", destName, index)

          aura_env:SendChatMessage(message, chatChannel)
        end

        break
      end
    end

    aura_env:DispatchIndicators(false)
  end

  if subEvent == "SPELL_AURA_APPLIED" then
    aura_env.FilterInPlace(
      aura_env.indicators,
      function(indicator)
        return indicator.show
      end
    )

    table.insert(
      aura_env.indicators,
      {
        show = true,
        unit = destName,
        group = aura_env.roster[destName] or 0,
        shouldDisplayGlow = false,
        shouldDisplayNumber = false,
        shouldDisplayIcon = false
      }
    )

    table.sort(
      aura_env.indicators,
      aura_env.CompareUnitObjects
    )

    for index, indicator in pairs(aura_env.indicators) do
      indicator.shouldDisplayGlow = aura_env.config.displayedGlows[index]
      indicator.shouldDisplayNumber = aura_env.config.displayedNumbers[index]
      indicator.shouldDisplayIcon = aura_env.config.displayedIcons[index]
    end

    aura_env:DispatchIndicators(true)

    if aura_env.config.shouldReportDebuffApplication then
      aura_env:ReportNewDebuffs()
    end
  end

  for key, state in pairs(allStates) do
    state.show = false
    state.changed = true
  end

  if event == "SOLTI_PENETRATING_COLD_HIDE" then
    return true
  end

  for index, indicator in pairs(aura_env.indicators) do
    local isActive = indicator.shouldDisplayGlow or indicator.shouldDisplayNumber

    allStates[indicator.unit] = {
      index = GetTime(),
      progressType = "static",
      changed = true,
      show = indicator.show and isActive,
      unit = indicator.unit,
      stacks = index,
      shouldDisplayGlow = indicator.shouldDisplayGlow,
      shouldDisplayNumber = indicator.shouldDisplayNumber,
    }
  end

  return true
end

local trigger1CustomVariables = { shouldDisplayGlow = "bool", shouldDisplayNumber = "bool" }

-- RAID_ROSTER_UPDATE
function Trigger2()
  aura_env:UpdateRoster()
  aura_env:ToggleIndicators()
  return false
end
