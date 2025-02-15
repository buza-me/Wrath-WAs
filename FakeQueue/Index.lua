function Init()
  local LIB_NAME = "SoltiFakeQueueContext"
  LibStub:NewLibrary(LIB_NAME, 1)
  local Context = LibStub(LIB_NAME)
  local GetTime = GetTimePreciseSec or GetTime
  local isTimePrecise = not not GetTimePreciseSec
  local env = aura_env

  env.Context = Context
  Context.Timer = LibStub("AceTimer-3.0")

  if not Context.callbacks then
    -- DBM mod.creatureId; LichKing = 36597; Lanathel = 37955
    Context.callbacks = {}

    Context.callbacks.pull = function(mod, delay, synced, startHp)
      WeakAuras.ScanEvents("ENCOUNTER_START", mod.creatureId)
    end
    Context.callbacks.wipe = function(mod)
      WeakAuras.ScanEvents("ENCOUNTER_END", mod.creatureId)
    end

    DBM:RegisterCallback("DBM_Pull", Context.callbacks.pull)
    DBM:RegisterCallback("DBM_Wipe", Context.callbacks.wipe)
  end

  function Context.log(...)
    if env.config.debug then
      print("FQ - ", ...)
    end
  end

  Context.encounterID = nil

  Context.unsafeEncounters = {
    [37955] = true, -- Blood Queen
    [36597] = true, -- Lich King
  }

  function Context:GetConfig()
    return WeakAurasSaved["displays"][env.id]["config"]
  end

  function Context:IsUnsafeEncounter()
    return (not not self.encounterID)
        or (not not self.unsafeEncounters[self.encounterID])
  end

  function Context:ReportFQDelay(delay)
    WeakAuras.ScanEvents("WA_FAKE_QUEUE_DELAY", delay)
  end

  function Context:GetMaxWait()
    local maxWait

    if self:IsUnsafeEncounter() then
      maxWait = env.config.maxWaitSafer
    else
      maxWait = env.config.maxWait
    end

    return maxWait
  end

  function Context:ReportMaxWait(value)
    local reportedValue = value

    if not reportedValue then
      reportedValue = self:GetMaxWait()
    end

    WeakAuras.ScanEvents("WA_FAKE_QUEUE_MAX_WAIT", reportedValue)
  end

  function Context:GetWaitTimeOffset()
    local offset

    if env.config.useWorldPingOffset then
      offset = select(3, GetNetStats()) + env.config.worldPingOffset
    else
      offset = env.config.absoluteOffset
    end

    return offset
  end

  function Context:FakeQueue(macroSpellIdentifier, unitID)
    local config = self:GetConfig()

    if not config.fqEnabled then
      return
    end

    if not macroSpellIdentifier then
      print(string.format("Spell name is required for a Fake Queue macro."))
      return
    end

    local spellName, rankText = GetSpellInfo(macroSpellIdentifier)

    if not spellName then
      print(string.format("Wrong Fake Queue macro spell name: %s", macroSpellIdentifier))
      return
    end

    if not unitID then
      unitID = "target"
    end

    local waitTimeOffset = self:GetWaitTimeOffset()
    local channeledSpellRecord = self.channelingSpellDetails.spellRecord
    local spellRecord = self:GetSpellRecord(spellName, rankText)
    local nextChanneledTickTime = self:GetNextChannelingTickTime(channeledSpellRecord) - waitTimeOffset
    local nextDebuffTickTime = self:GetNextDebuffTickTime(spellRecord, unitID) - waitTimeOffset
    local maxWaitTime = self:GetMaxWait()
    local now = GetTime() * 1000
    local maxWaitUntil = now + maxWaitTime

    if nextChanneledTickTime > maxWaitUntil then
      self.log(
        string.format(
          "Ignored channeled tick wait time (%s MS), it exceeds max wait time.",
          nextChanneledTickTime - now
        )
      )
      nextChanneledTickTime = 0
    end

    if nextDebuffTickTime > maxWaitUntil then
      self.log(
        string.format(
          "Ignored %s(%s) tick wait time (%s MS), it exceeds max wait time.",
          spellName,
          rankText,
          nextDebuffTickTime - now
        )
      )
      nextDebuffTickTime = 0
    end

    local nextTickTime = math.max(nextChanneledTickTime, nextDebuffTickTime)

    if nextTickTime == 0 or nextTickTime <= now then
      self.log("Possible clipped ticks not found.")
      return
    end

    local waitFor = nextTickTime - now

    -- I don't think this can ever be greater than our wait time,
    -- so I think this block of code will always do nothing.
    local gcdStart, gcdDuration = GetSpellCooldown(61304)

    if gcdStart > 0 then
      local gcdEnd = gcdStart + gcdDuration
      local gcdRemaining = (gcdEnd - GetTime()) * 1000

      if gcdRemaining > waitFor then
        self.log("GCD remaining time exceeds wait time.")
        return
      end
    end

    self:ReportFQDelay(waitFor)

    if isTimePrecise then
      local start = GetTime()

      while ((GetTime() - start) * 1000) < waitFor do
        -- nothing
      end
    else
      local loopLength = (waitFor / 1000) * config.oneSecondLoopLength
      for i = 1, loopLength do
        -- nothing
      end
    end

    self.log(string.format("Waited for %s MS.", waitFor))
  end

  function Context:FakeQueueCalibrate()
    local Timer = self.Timer

    Timer:ScheduleTimer(function()
      local frameTestStartTime = GetTime()

      Timer:ScheduleTimer(function()
        local loopTestStartTime = GetTime()
        local frameTime = loopTestStartTime - frameTestStartTime

        local config = Context:GetConfig()

        for i = 1, config.calibrationLoopLength do
          -- nothing
        end

        Timer:ScheduleTimer(function()
          local loopTime = GetTime() - loopTestStartTime - frameTime
          local oneSecondRatio = 1 / loopTime

          config.oneSecondLoopLength = config.calibrationLoopLength * oneSecondRatio
          config.calibrationLoopLength = config.oneSecondLoopLength * config.calibrationLoopDuration
        end, 0)
      end, 0)
    end, 0)
  end

  function Context:ToggleFQEnabled()
    WeakAuras.ScanEvents("SOLTI_FAKE_QUEUE_TOGGLE")
  end

  local function onInit()
    if not Context.InitSpells or not Context.InitSpellMods or not Context.UpdateSpellMods or not Context.ApplySpellMods then
      return
    end
    Context:InitSpells()
    Context:InitSpellMods()
    Context:UpdateSpellMods()
    Context:ApplySpellMods()
  end

  local eventListeners = Context.eventListeners or {}
  Context.eventListeners = eventListeners

  eventListeners.ENCOUNTER_START = function(dbmEncounterID)
    Context.encounterID = dbmEncounterID
    Context:ReportMaxWait()
    Context.log(string.format("Encounter start. Encounter ID: %s.", dbmEncounterID or ""))
  end

  eventListeners.ENCOUNTER_END = function()
    Context.encounterID = nil
    Context.log("Encounter end.")
  end

  eventListeners.PLAYER_REGEN_DISABLED = function()
    Context:ReportMaxWait()
    Context.log("Player is in combat.")

    local config = Context:GetConfig()

    return config.shouldShowIconOnCombatStart
  end

  eventListeners.SOLTI_FAKE_QUEUE_TOGGLE = function()
    local config = Context:GetConfig()

    if config.fqEnabled then
      config.fqEnabled = false
      Context:ReportMaxWait(0)
      Context.log("Fake Queue disabled.")
    else
      config.fqEnabled = true
      Context:ReportMaxWait()
      Context.log("Fake Queue enabled.")
    end

    return true
  end

  eventListeners.WA_DELAYED_PLAYER_ENTERING_WORLD = onInit

  eventListeners.SOLTI_FAKE_QUEUE_DEBUG_EVENT = function(event)
    Context.log(string.format("Unhandled event in trigger 1: %s", event))
  end

  setglobal("FQGetMaxWait", function()
    return Context:GetMaxWait()
  end)

  setglobal("FQ", function(...)
    return Context:FakeQueue(...)
  end)

  setglobal("FQToggle", function()
    return Context:ToggleFQEnabled()
  end)

  setglobal("FQCalibrate", function()
    return Context:FakeQueueCalibrate()
  end)

  setglobal("FQDumpState", function()
    print("Active spell mods:")
    for _, spellMod in pairs(Context.spellModifications.active.list) do
      print(spellMod.name)
    end
  end)

  onInit()
end

-- UNIT_SPELLCAST_CHANNEL_START:player,UNIT_SPELLCAST_CHANNEL_UPDATE:player,UNIT_SPELLCAST_CHANNEL_STOP:player,UNIT_INVENTORY_CHANGED,PLAYER_EQUIPMENT_CHANGED,PLAYER_REGEN_DISABLED,ENCOUNTER_START,ENCOUNTER_END,WA_DELAYED_PLAYER_ENTERING_WORLD,SOLTI_FAKE_QUEUE_TOGGLE,GLYPH_ADDED,GLYPH_DISABLED,GLYPH_ENABLED,GLYPH_REMOVED,GLYPH_UPDATED,PLAYER_TALENT_UPDATE,ACTIVE_TALENT_GROUP_CHANGED,CHARACTER_POINTS_CHANGED,CONFIRM_TALENT_WIPE,CLEU
function Trigger1(event, ...)
  local eventListeners = aura_env.Context.eventListeners

  if not eventListeners then
    return false
  end

  local eventListener = eventListeners[event]

  if not eventListener then
    return eventListeners.SOLTI_FAKE_QUEUE_DEBUG_EVENT(event)
  end

  return eventListener(...) or false
end
