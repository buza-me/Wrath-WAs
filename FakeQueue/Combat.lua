local LIB_NAME = "SoltiShadowPriestFakeQueueContext"
LibStub:NewLibrary(LIB_NAME, 1)
local Context = LibStub(LIB_NAME)

local myName = UnitName("player")
local targets = Context.targets or {}
Context.targets = targets

Context.channelingSpellDetails = {
  startTime = 0,
  endTime = 0,
  tickFrequency = 0,
  spellRecord = nil,
}

function Context:ResetChannelingSpellDetails()
  self.channelingSpellDetails.startTime = 0
  self.channelingSpellDetails.endTime = 0
  self.channelingSpellDetails.tickFrequency = 0
  self.channelingSpellDetails.spellRecord = nil
end

function Context:GetNextChannelingTickTime(spellRecord)
  if not spellRecord then
    return 0
  end

  local now = GetTime() * 1000

  if spellRecord == self.channelingSpellDetails.spellRecord then
    local nextTick = self.channelingSpellDetails.endTime

    for tickNumber = 1, spellRecord.ticks do
      local tickTime = self.channelingSpellDetails.startTime + (self.channelingSpellDetails.tickFrequency * tickNumber)

      if tickTime > now then
        nextTick = tickTime
        break
      end
    end

    return nextTick
  end

  return 0
end

function Context:GetNextDebuffTickTime(spellRecord)
  if not spellRecord then
    return 0
  end

  local spellName,
  rankText,
  icon,
  count,
  dispelType,
  duration,
  expirationTime,
  source = WA_GetUnitDebuff("target", spellRecord.spellID)

  local _, _, _, _, _, _, castTime = GetSpellInfo(spellRecord.spellID)
  castTime = castTime or 0

  local now = GetTime() * 1000

  if expirationTime ~= nil and source == "player" then
    local startTime = (expirationTime - duration) * 1000
    local tickDuration = (duration / spellRecord.ticks) * 1000
    local nextTick = expirationTime

    for tickNumber = 1, spellRecord.ticks do
      local tickTime = startTime + (tickDuration * tickNumber)

      if tickTime > now then
        nextTick = tickTime
        break
      end
    end

    nextTick = nextTick - castTime

    return nextTick
  end

  return 0
end

function Context:GetTarget(guid)
  local target = Context.targets[guid] or {
    auras = {},
    pendingAuraMods = {},
    comboPoints = 0,
  }
  Context.targets[guid] = target

  return target
end

function Context:SetComboPoints(unitID, comboPoints)
  local guid = UnitGUID(unitID)
  local target = self:GetTarget(guid)

  target.comboPoints = comboPoints
end

function Context:ResetComboPoints()
  for guid, target in pairs(self.targets) do
    target.comboPoints = 0
  end
end

local eventListeners = Context.eventListeners or {}
Context.eventListeners = eventListeners

eventListeners.UNIT_SPELLCAST_CHANNEL_START = function()
  local spellName, rankText, _, _, startTime, endTime = UnitChannelInfo("player")
  local spellRecord = Context:GetSpellRecord(spellName, rankText)
  local channelingSpellDetails = Context.channelingSpellDetails

  if spellRecord then
    channelingSpellDetails.startTime = startTime
    channelingSpellDetails.endTime = endTime
    channelingSpellDetails.spellRecord = spellRecord
    channelingSpellDetails.tickFrequency = (endTime - startTime) / spellRecord.ticks
  else
    Context:ResetChannelingSpellDetails()
  end
end

eventListeners.UNIT_SPELLCAST_CHANNEL_UPDATE = function()
  local spellName, rankText, _, _, startTime, endTime = UnitChannelInfo("player")
  local spellRecord = Context:GetSpellRecord(spellName, rankText)
  local channelingSpellDetails = Context.channelingSpellDetails

  if spellRecord then
    channelingSpellDetails.endTime = endTime
  else
    Context:ResetChannelingSpellDetails()
  end
end

eventListeners.UNIT_SPELLCAST_CHANNEL_STOP = function()
  Context:ResetChannelingSpellDetails()
end

local comboPointCheckUnitIDs = {
  "mouseover", "target", "focus", "mouseovertarget", "targettarget",
  "focustarget", "mouseovertargettarget", "targettargettarget",
  "focustargettarget",
}

eventListeners.UNIT_COMBO_POINTS = function(eventUnitID)
  if eventUnitID ~= "player" then
    return false
  end

  Context:ResetComboPoints()

  for _, unitID in ipairs(comboPointCheckUnitIDs) do
    local comboPoints = GetComboPoints("player", unitID) or 0

    if comboPoints > 0 then
      Context:SetComboPoints(unitID, comboPoints)

      return false
    end
  end

  for groupUnitID in WA_IterateGroupMembers() do
    local unitIDs = {
      groupUnitID,
      groupUnitID .. "target",
      groupUnitID .. "targettarget",
      groupUnitID .. "targettargettarget"
    }

    for _, unitID in ipairs(unitIDs) do
      local comboPoints = GetComboPoints("player", unitID) or 0

      if comboPoints > 0 then
        Context:SetComboPoints(unitID, comboPoints)

        return false
      end
    end
  end
end

eventListeners.COMBAT_LOG_EVENT_UNFILTERED = function(
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
  if sourceName ~= myName or destName == myName then
    return false
  end

  local target = Context:GetTarget(destGUID)
  local spellRecord = Context:GetSpellRecord(nil, nil, spellID)

  if subEvent == "SPELL_AURA_APPLIED" and spellRecord then
    local spellName,
    rankText,
    icon,
    count,
    dispelType,
    duration,
    expirationTime,
    source = WA_GetUnitDebuff("target", spellID)

    local ticks = spellRecord.ticks

    if spellRecord.type == Context.spellTypes.finisherDebuff then
      ticks = spellRecord.ticks[target.comboPoints]
    end

    if ticks then
      target.auras[spellID] = {
        duration = duration,
        expirationTime = expirationTime,
        ticks = ticks,
        tickFrequency = duration / ticks,
      }
    end
  end

  if subEvent == "SPELL_AURA_REFRESH" and spellRecord then
    local spellName,
    rankText,
    icon,
    count,
    dispelType,
    duration,
    expirationTime,
    source = WA_GetUnitDebuff("target", spellID)

    local ticks = spellRecord.ticks

    if spellRecord.type == Context.spellTypes.finisherDebuff then
      ticks = spellRecord.ticks[target.comboPoints]
    end

    if ticks then
      target.auras[spellID] = {
        duration = duration,
        expirationTime = expirationTime,
        ticks = ticks,
        tickFrequency = duration / ticks,
      }
    end
  end

  if subEvent == "SPELL_AURA_REMOVED" and spellRecord then
    target.auras[spellID] = nil
  end

  local triggers = Context.spellModifications.active.triggers or {}
  local cleuTriggers = triggers["COMBAT_LOG_EVENT_UNFILTERED"] or {}
  local spellMods = cleuTriggers[subEvent] or {}

  if #spellMods < 1 then
    return false
  end
end
