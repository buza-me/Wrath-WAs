function Init()
  local LIB_NAME = "SoltiSpellQueueContext"
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
      print("SQ - ", ...)
    end
  end

  Context.encounterID = nil

  Context.unsafeEncounters = {
    [37955] = true, -- Blood Queen
    [36597] = true, -- Lich King
  }

  function Context:GetInternalConfig()
    return WeakAurasSaved["displays"][env.id]["config"]
  end

  function Context:IsUnsafeEncounter()
    return (not not self.encounterID)
        or (not not self.unsafeEncounters[self.encounterID])
  end

  function Context:ReportSQDelay(delay)
    WeakAuras.ScanEvents("SOLTI_SPELL_QUEUE_DELAY", delay)
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

    WeakAuras.ScanEvents("SOLTI_SPELL_QUEUE_MAX_WAIT", reportedValue)
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

  function Context:SpellQueue(macroSpellIdentifier, unitID)
    local internalConfig = self:GetInternalConfig()

    if not internalConfig.isEnabled then
      return
    end

    if not macroSpellIdentifier then
      print(string.format("Spell name is required for a Spell Queue macro."))
      return
    end

    local spellName, rankText = GetSpellInfo(macroSpellIdentifier)

    if not spellName then
      print(string.format("Wrong Spell Queue macro spell name: %s", macroSpellIdentifier))
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

    self:ReportSQDelay(waitFor)

    if isTimePrecise then
      local start = GetTime()

      while ((GetTime() - start) * 1000) < waitFor do
        -- nothing
      end
    else
      local loopLength = (waitFor / 1000) * internalConfig.oneSecondLoopLength
      for i = 1, loopLength do
        -- nothing
      end
    end

    self.log(string.format("Waited for %s MS.", waitFor))
  end

  function Context:SpellQueueCalibrate()
    local Timer = self.Timer

    Timer:ScheduleTimer(function()
      local frameTestStartTime = GetTime()

      Timer:ScheduleTimer(function()
        local loopTestStartTime = GetTime()
        local frameTime = loopTestStartTime - frameTestStartTime

        local internalConfig = Context:GetInternalConfig()

        for i = 1, internalConfig.calibrationLoopLength do
          -- nothing
        end

        Timer:ScheduleTimer(function()
          local loopTime = GetTime() - loopTestStartTime - frameTime
          local oneSecondRatio = 1 / loopTime

          internalConfig.oneSecondLoopLength =
              internalConfig.calibrationLoopLength * oneSecondRatio
          internalConfig.calibrationLoopLength =
              internalConfig.oneSecondLoopLength * internalConfig.calibrationLoopDuration
        end, 0)
      end, 0)
    end, 0)
  end

  function Context:ToggleSQEnabled()
    WeakAuras.ScanEvents("SOLTI_SPELL_QUEUE_TOGGLE")
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

    local internalConfig = Context:GetInternalConfig()

    return internalConfig.shouldShowIconOnCombatStart
  end

  eventListeners.SOLTI_SPELL_QUEUE_TOGGLE = function()
    local internalConfig = Context:GetInternalConfig()

    if internalConfig.isEnabled then
      internalConfig.isEnabled = false
      Context:ReportMaxWait(0)
      Context.log("Spell Queue disabled.")
    else
      internalConfig.isEnabled = true
      Context:ReportMaxWait()
      Context.log("Spell Queue enabled.")
    end

    return true
  end

  eventListeners.WA_DELAYED_PLAYER_ENTERING_WORLD = onInit

  eventListeners.SOLTI_SPELL_QUEUE_DEBUG_EVENT = function(event)
    Context.log(string.format("Unhandled event in trigger 1: %s", event))
  end

  setglobal("SQ", function(...)
    return Context:SpellQueue(...)
  end)

  setglobal("SQToggle", function()
    return Context:ToggleSQEnabled()
  end)

  setglobal("SQCalibrate", function()
    return Context:SpellQueueCalibrate()
  end)

  ------------------------- For internal use ---------------------------
  setglobal("SQGetMaxWait", function()
    return Context:GetMaxWait()
  end)

  setglobal("SQDumpActiveSpellMods", function()
    print("Active spell mods:")
    for _, spellMod in pairs(Context.spellModifications.active.list) do
      print(spellMod.name)
    end
  end)
  ----------------------------------------------------------------------

  onInit()
end

-- UNIT_SPELLCAST_CHANNEL_START:player,UNIT_SPELLCAST_CHANNEL_UPDATE:player,UNIT_SPELLCAST_CHANNEL_STOP:player,UNIT_INVENTORY_CHANGED,PLAYER_EQUIPMENT_CHANGED,PLAYER_REGEN_DISABLED,ENCOUNTER_START,ENCOUNTER_END,WA_DELAYED_PLAYER_ENTERING_WORLD,SOLTI_SPELL_QUEUE_TOGGLE,GLYPH_ADDED,GLYPH_DISABLED,GLYPH_ENABLED,GLYPH_REMOVED,GLYPH_UPDATED,PLAYER_TALENT_UPDATE,ACTIVE_TALENT_GROUP_CHANGED,CHARACTER_POINTS_CHANGED,CONFIRM_TALENT_WIPE,CLEU:SPELL_CAST_SUCCESS:SPELL_AURA_APPLIED:SPELL_AURA_REFRESH:SPELL_AURA_REMOVED:SPELL_DAMAGE:SPELL_MISSED:UNIT_DIED
function Trigger1(event, ...)
  local eventListeners = aura_env.Context.eventListeners

  if not eventListeners then
    return false
  end

  local eventListener = eventListeners[event]

  if not eventListener then
    return eventListeners.SOLTI_SPELL_QUEUE_DEBUG_EVENT(event)
  end

  return eventListener(...) or false
end
