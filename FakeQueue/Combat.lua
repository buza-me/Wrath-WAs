local LIB_NAME = "SoltiFakeQueueContext"
LibStub:NewLibrary(LIB_NAME, 1)
local Context = LibStub(LIB_NAME)
local GetTime = GetTimePreciseSec or GetTime
local gameVersionMajorMinor = string.sub(GetBuildInfo(), 1, 3)

Context.Timer = LibStub("AceTimer-3.0")
Context.isOldClient = gameVersionMajorMinor == "2.4" or gameVersionMajorMinor == "3.3"

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

  if not guid then
    return 0
  end

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

  local _, _, _, _, _, _, castTime, minSpellRange, maxSpellRange = GetSpellInfo(spellRecord.spellID)
  castTime = castTime or 0

  local nextTick = spellAura.expirationTime

  local ticks = spellAura.ticks

  if not ticks or ticks < 1 then
    return 0
  end

  local travelTime = 0

  if castTime < 0 and minSpellRange and maxSpellRange then
    travelTime = (math.abs(travelTime) / 1000) / maxSpellRange
    castTime = 0
  end

  if travelTime == 0 and spellRecord.oneYardTravelTime and spellRecord.oneYardTravelTime > 0 then
    local minRange, maxRange = WeakAuras.GetRange(unitID)
    local range = maxRange or minRange

    if range and range > 0 then
      travelTime = range * spellRecord.oneYardTravelTime
    end
  end

  local relevantTime = now + castTime + travelTime

  for tickNumber = 1, ticks do
    local tickTime = spellAura.tickTimes[tickNumber]
        or spellAura.startTime + (spellAura.tickFrequency * tickNumber)

    if tickTime > relevantTime then
      nextTick = tickTime
      break
    end
  end

  nextTick = nextTick - castTime - travelTime
  return nextTick
end

function Context:GetTarget(guid)
  local target = self.targets[guid] or {
    spellAuras = {},
    pendingSpellMods = {},
    finisherComboPoints = {},
  }
  self.targets[guid] = target

  return target
end

function Context:RemoveTarget(guid)
  self.targets[guid] = nil
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

function Context:HandleSpellCastEvents(
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
  if subEvent ~= "SPELL_CAST_SUCCESS" then
    return
  end

  local spellRecord = self:GetSpellRecord(nil, nil, spellID)

  if not spellRecord or spellRecord.type ~= self.spellTypes.finisherDebuff then
    return
  end

  local target = Context:GetTarget(destGUID)

  local unitIDs = Context:GetTargetUnitIDs()

  for _, unitID in ipairs(unitIDs) do
    if UnitGUID(unitID) == destGUID then
      target.finisherComboPoints[spellRecord.spellID] = GetComboPoints("player", unitID)

      return
    end
  end
end

function Context:HandleSpellAuraEvents(
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
  local spellRecord = self:GetSpellRecord(nil, nil, spellID)
  local target = self:GetTarget(destGUID)

  local shouldExecute =
      spellRecord
      and target
      and (
        subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_AURA_REFRESH"
        or subEvent == "SPELL_AURA_REMOVED"
      )

  if not shouldExecute then
    return
  end

  if subEvent == "SPELL_AURA_REMOVED" then
    target.spellAuras[spellID] = nil

    return
  end

  local destUnitID = nil
  local unitIDs = Context:GetTargetUnitIDs()

  for _, unitID in ipairs(unitIDs) do
    if UnitGUID(unitID) == destGUID then
      destUnitID = unitID

      break
    end
  end

  if not destUnitID then
    return
  end

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
    ticks = spellRecord.ticks[target.finisherComboPoints[spellRecord.spellID] or 0]
    target.finisherComboPoints[spellRecord.spellID] = 0
  end

  if not ticks or ticks < 1 or not duration or duration == 0 then
    return
  end

  local spellMods = target.pendingSpellMods[spellID]

  duration = duration * 1000
  expirationTime = expirationTime * 1000
  local startTime = expirationTime - duration
  local tickFrequency = math.floor((duration / ticks) * 10000) / 10000

  if subEvent == "SPELL_AURA_APPLIED" or not spellMods or #spellMods < 1 then
    local tickTimes = {}

    for i = 1, ticks do
      table.insert(tickTimes, startTime + (i * tickFrequency))
    end

    target.spellAuras[spellID] = {
      duration = duration,
      expirationTime = expirationTime,
      ticks = ticks,
      tickFrequency = tickFrequency,
      tickTimes = tickTimes,
      modifications = {}
    }

    return
  end

  for _, spellMod in pairs(spellMods) do
    if spellMod.type == self.modTypes.auraFull then
      local firstTickTime = self:GetNextDebuffTickTime(spellRecord, destUnitID)
      local tickTimes = { firstTickTime }

      for i = 1, ticks - 1 do
        table.insert(tickTimes, firstTickTime + (i * tickFrequency))
      end

      target.spellAuras[spellID] = {
        duration = duration,
        expirationTime = expirationTime,
        startTime = startTime,
        ticks = ticks,
        tickFrequency = tickFrequency,
        tickTimes = tickTimes,
        modifications = {}
      }
    elseif spellMod.type == self.modTypes.aura then
      local spellAura = target.spellAuras[spellID]

      if not spellMod.limit or not spellAura.modifications[spellMod] or spellAura.modifications[spellMod] < spellMod.limit then
        local modifiedTicks = spellAura.ticks + spellMod.ticks
        local modifiedTickFrequency = math.floor((duration / modifiedTicks) * 1000) / 1000
        local tickTimes = {}

        for i = 1, modifiedTicks do
          table.insert(tickTimes, startTime + (i * tickFrequency))
        end

        spellAura.duration = duration
        spellAura.expirationTime = expirationTime
        spellAura.startTime = startTime
        spellAura.ticks = modifiedTicks
        spellAura.tickFrequency = modifiedTickFrequency
        spellAura.tickTimes = tickTimes
        spellAura.modifications[spellMod] = (spellAura.modifications[spellMod] or 0) + spellMod.ticks
      end
    end
  end
end

function Context:HandleModEventTriggers(
    event,
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
  local target = self:GetTarget(destGUID)
  local triggers = self.spellModifications.active.triggers or {}
  local cleuTriggers = triggers[event] or {}
  local spellMods = cleuTriggers[subEvent or ""] or {}

  if not spellMods or #spellMods < 1 then
    return
  end

  local filteredSpellMods = {}

  for _, spellMod in pairs(spellMods) do
    local isMatch = true

    if spellMod.trigger.spellIDs then
      isMatch = spellMod.trigger.spellIDs[spellID]
    end

    if isMatch and subEvent == "SPELL_MISSED" and spellMod.trigger.missType then
      isMatch = spellMod.trigger.missType == amount
    end

    if isMatch then
      table.insert(filteredSpellMods, spellMod)
    end
  end

  self:HandlePendingSpellMods(target, filteredSpellMods)
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

eventListeners.COMBAT_LOG_EVENT_UNFILTERED = function(...)
  local timeStamp, subEvent, hideCaster, sourceGUID,
  sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
  destFlags, destRaidFlags, spellID, spellName, spellSchool, amount

  if Context.isOldClient then
    timeStamp, subEvent, sourceGUID,
    sourceName, sourceFlags, destGUID, destName,
    destFlags, spellID, spellName, spellSchool, amount = unpack({ ... })
  else
    timeStamp, subEvent, hideCaster, sourceGUID,
    sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
    destFlags, destRaidFlags, spellID, spellName, spellSchool, amount = unpack({ ... })
  end

  if subEvent == "UNIT_DIED" then
    Context:RemoveTarget(destGUID)

    return
  end

  if sourceName ~= myName or destName == myName then
    return
  end

  Context:HandleSpellCastEvents(
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

  Context:HandleSpellAuraEvents(
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

  Context:HandleModEventTriggers(
    "COMBAT_LOG_EVENT_UNFILTERED",
    subEvent or "",
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
end
