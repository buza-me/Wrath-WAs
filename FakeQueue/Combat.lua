local LIB_NAME = "SoltiShadowPriestFakeQueueContext"
LibStub:NewLibrary(LIB_NAME, 1)
local Context = LibStub(LIB_NAME)

Context.Timer = LibStub("AceTimer-3.0")

local myName = UnitName("player")
local targets = Context.targets or {}
Context.targets = targets
Context.pendingSpellModLifeDuration = 0.9
Context.pendingSpellModTimers = {}

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

  if spellRecord == self.channelingSpellDetails.spellRecord then
    local now = GetTime() * 1000
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

function Context:GetNextDebuffTickTime(spellRecord, unitID)
  if not spellRecord then
    return 0
  end

  if not unitID then
    unitID = "target"
  end

  local guid = UnitGUID(unitID)
  local target = self:GetTarget(guid)
  local spellAura = target.spellAuras[spellRecord.spellID]

  if not spellAura then
    return 0
  end

  local now = GetTime() * 1000

  if spellAura.expirationTime <= now then
    target.spellAuras[spellRecord.spellID] = nil

    return 0
  end

  local _, _, _, _, _, _, castTime = GetSpellInfo(spellRecord.spellID)
  castTime = castTime or 0

  local nextTick = spellAura.expirationTime

  for tickNumber = 1, spellRecord.ticks do
    local tickTime = spellAura.startTime + (spellAura.tickFrequency * tickNumber)

    if tickTime > now then
      nextTick = tickTime
      break
    end
  end

  nextTick = nextTick - castTime

  return nextTick
end

function Context:GetTarget(guid)
  local target = self.targets[guid] or {
    spellAuras = {},
    pendingSpellMods = {},
    comboPoints = 0,
  }
  self.targets[guid] = target

  return target
end

function Context:RemoveTarget(guid)
  self.targets[guid] = nil
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

function Context:AddPendingSpellMod(target, spellMod)
  for _, spellID in pairs(spellMod.spellIDs) do
    local spellModTable = target.pendingSpellMods[spellID] or {}
    target.pendingSpellMods[spellID] = spellModTable

    spellModTable[spellMod] = spellMod
  end
end

function Context:RemovePendingSpellMod(target, spellMod)
  for _, spellID in pairs(spellMod.spellIDs) do
    local spellModTable = target.pendingSpellMods[spellID]

    if spellModTable then
      spellModTable[spellMod] = nil
    end
  end
end

function Context:HandlePendingSpellMods(target, spellMods)
  local Timer = self.Timer

  for _, spellMod in pairs(spellMods) do
    local timerID = self.pendingSpellModTimers[spellMod]

    if timerID then
      Timer:CancelTimer(timerID)
    end

    self:AddPendingSpellMod(target, spellMod)

    timerID = Timer:ScheduleTimer(function()
      self.pendingSpellModTimers[spellMod] = nil

      self:RemovePendingSpellMod(target, spellMod)
    end, self.pendingSpellModLifeDuration)

    self.pendingSpellModTimers[spellMod] = timerID
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

function Context:GetTargetUnitIDs()
  local unitIDs = {
    "mouseover", "target", "focus", "mouseovertarget", "targettarget",
    "focustarget", "mouseovertargettarget", "targettargettarget",
    "focustargettarget",
  }

  for groupUnitID in WA_IterateGroupMembers() do
    table.insert(unitIDs, groupUnitID .. "target")
    table.insert(unitIDs, groupUnitID .. "targettarget")
    table.insert(unitIDs, groupUnitID .. "targettargettarget")
  end

  return unitIDs
end

eventListeners.UNIT_COMBO_POINTS = function(eventUnitID)
  if eventUnitID ~= "player" then
    return
  end

  Context:ResetComboPoints()
  local unitIDs = Context:GetTargetUnitIDs()

  for _, unitID in ipairs(unitIDs) do
    local comboPoints = GetComboPoints("player", unitID) or 0

    if comboPoints > 0 then
      Context:SetComboPoints(unitID, comboPoints)

      return
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
  if subEvent == "UNIT_DIED" then
    Context:RemoveTarget(destGUID)

    return
  end

  if sourceName ~= myName or destName == myName then
    return
  end

  local target = Context:GetTarget(destGUID)
  local spellRecord = Context:GetSpellRecord(nil, nil, spellID)

  if (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH") and spellRecord then
    local destUnitID = nil
    local unitIDs = Context:GetTargetUnitIDs()

    for _, unitID in ipairs(unitIDs) do
      if UnitGUID(unitID) == destGUID then
        destUnitID = unitID

        break
      end
    end

    if destUnitID then
      local spellName,
      rankText,
      icon,
      count,
      dispelType,
      duration,
      expirationTime,
      source = WA_GetUnitDebuff(destUnitID, spellID)

      local ticks = spellRecord.ticks

      if spellRecord.type == Context.spellTypes.finisherDebuff then
        ticks = spellRecord.ticks[target.comboPoints]
      end

      if ticks and duration then
        duration = duration * 1000
        expirationTime = expirationTime * 1000

        target.spellAuras[spellID] = {
          duration = duration,
          expirationTime = expirationTime,
          startTime = expirationTime - duration,
          ticks = ticks,
          tickFrequency = duration / ticks,
        }
      end
    end
  end

  if subEvent == "SPELL_AURA_REMOVED" and spellRecord then
    target.spellAuras[spellID] = nil
  end

  local triggers = Context.spellModifications.active.triggers or {}
  local cleuTriggers = triggers["COMBAT_LOG_EVENT_UNFILTERED"] or {}
  local spellMods = cleuTriggers[subEvent] or {}

  if #spellMods < 1 then
    return
  end

  local filteredSpellMods = {}

  for _, spellMod in pairs(spellMods) do
    local isMatch = true

    if subEvent == "SPELL_MISSED" and spellMod.missType then
      isMatch = spellMod.missType == amount
    end

    if isMatch then
      table.insert(filteredSpellMods, spellMod)
    end
  end

  Context:HandlePendingSpellMods(target, filteredSpellMods)
end
