function Init()
  local aura_env = aura_env
  local setglobal = setglobal
  local GetSpellBonusDamage = GetSpellBonusDamage
  local GetSpellCooldown = GetSpellCooldown
  local UnitChannelInfo = UnitChannelInfo
  local UnitCastingInfo = UnitCastingInfo
  local GetSpellInfo = GetSpellInfo
  local GetNetStats = GetNetStats
  local GetFramerate = GetFramerate
  local WA_GetUnitBuff = WA_GetUnitBuff
  local WA_GetUnitDebuff = WA_GetUnitDebuff

  local function log(...)
    if aura_env.config.debug then
      print("FQ - ", ...)
    end
  end

  aura_env.fqEnabled = true

  local LIB_NAME = "SoltiFakeQueueContext"
  LibStub:NewLibrary(LIB_NAME, 1)
  local Context = LibStub(LIB_NAME)

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

  local Timer = LibStub("AceTimer-3.0")
  local encounterID = nil
  local channelingSpellDetails = {
    startTime = 0,
    endTime = 0,
    tickFrequency = 0
  }
  local unsafeEncounters = {
    [37955] = true, -- Blood Queen
    [36597] = true, -- Lich King
  }

  local itemSetSlots = {
    (GetInventorySlotInfo("ChestSlot")),
    (GetInventorySlotInfo("HeadSlot")),
    (GetInventorySlotInfo("ShoulderSlot")),
    (GetInventorySlotInfo("LegsSlot")),
    (GetInventorySlotInfo("HandsSlot")),
  }
  local spellTemplates = {
    -- Priest
    {
      spellID = 15407,
      name = "Mind Flay",
      rankText = "Rank 1",
      mode = "default",
      modes = {
        default = {
          ticks = 3,
          processedTicks = { 2, 3 },
        }
      }
    },
    {
      spellID = 48156,
      name = "Mind Flay",
      rankText = "Rank 9",
      mode = "default",
      modes = {
        default = {
          ticks = 3,
          processedTicks = { 2, 3 },
        }
      },
    },
    {
      spellID = 53023,
      name = "Mind Sear",
      rankText = "Rank 2",
      mode = "default",
      modes = {
        default = {
          ticks = 5,
          processedTicks = { 2, 3, 4, 5 },
        }
      },
    },
    {
      spellID = 64901,
      name = "Hymn of Hope",
      rankText = "",
      mode = "default",
      modes = {
        default = {
          ticks = 4,
          processedTicks = { 2, 3, 4 },
        }
      },
    },
    {
      spellID = 64843,
      name = "Divine Hymn",
      rankText = "",
      mode = "default",
      modes = {
        default = {
          ticks = 4,
          processedTicks = { 2, 3, 4 },
        }
      },
    },
    {
      spellID = 48160,
      name = "Vampiric Touch",
      rankText = "Rank 5",
      mode = "default",
      modes = {
        default = {
          ticks = 5,
          processedTicks = { 2, 3, 4, 5 },
        },
        tier9 = {
          ticks = 7,
          processedTicks = { 2, 3, 4, 5, 6, 7 },
        },
      },
    },
    {
      spellID = 48300,
      name = "Devouring Plague",
      rankText = "Rank 9",
      mode = "default",
      modes = {
        default = {
          ticks = 8,
          processedTicks = { 2, 3, 4, 5, 6, 7, 8 },
        }
      },
    },
    -- Lock
    {
      spellID = 47855,
      name = "Drain Soul",
      rankText = "Rank 6",
      mode = "default",
      modes = {
        default = {
          ticks = 5,
          processedTicks = { 2, 3, 4, 5 },
        }
      },
    },
  }
  local spells = {}

  local function buildSpellRecordName(name, rankText)
    if not rankText or #rankText == 0 then
      return name
    end

    return string.format("%s(%s)", name or "", rankText)
  end

  for _, spellRecord in pairs(spellTemplates) do
    local localizedName, localizedRank = GetSpellInfo(spellRecord.spellID)

    spellRecord.name = localizedName
    spellRecord.rankText = localizedRank

    spells[spellRecord.spellID] = spellRecord
    spells[buildSpellRecordName(localizedName, localizedRank)] = spellRecord
  end

  local itemSets = {
    ["Shadow T9"] = {
      items = {
        48088, 48091, 48090, 48087, 48089, -- 258 Horde
        48095, 48092, 48093, 48096, 48094, -- 245 Horde
        48098, 48101, 48100, 48097, 48099, -- 232 Horde
        48085, 48082, 48083, 48086, 48084, -- 258 Alliance
        48078, 48081, 48080, 48077, 48079, -- 245 Alliance
        48073, 48076, 48075, 48072, 48074, -- 232 Alliance
      },
      callbacks = {
        [2] = { -- number of equipped pieces required for activation
          onEnabled = function()
            local localizedVampiricTouchName = GetSpellInfo(48160)

            for key, spellRecord in pairs(spells) do
              if spellRecord.name == localizedVampiricTouchName then
                spellRecord.mode = "tier9"
              end
            end

            log("Two pieces T9 bonus registered.")
          end,
          onDisabled = function()
            local localizedVampiricTouchName = GetSpellInfo(48160)

            for key, spellRecord in pairs(spells) do
              if spellRecord.name == localizedVampiricTouchName then
                spellRecord.mode = "default"
              end
            end

            log("Two pieces T9 bonus unregistered.")
          end,
          isEnabled = false,
        }
      }
    }
  }

  for _, itemSet in pairs(itemSets) do
    local updatedItemTable = {}

    for _, itemID in pairs(itemSet.items) do
      updatedItemTable[itemID] = true
    end

    itemSet.items = updatedItemTable
  end


  local function getEquippedPiecesCount(itemSetName)
    local itemSet = itemSets[itemSetName]
    local setPiecesEquipped = 0

    for _, itemSlot in ipairs(itemSetSlots) do
      local itemID = GetInventoryItemID("player", itemSlot)

      if itemSet.items[itemID] then
        setPiecesEquipped = setPiecesEquipped + 1
      end
    end

    return setPiecesEquipped
  end

  local function checkItemSetBonuses()
    for itemSetName, itemSet in pairs(itemSets) do
      local piecesEquipped = getEquippedPiecesCount(itemSetName)

      for piecesRequired, setBonus in pairs(itemSet.callbacks) do
        if piecesEquipped >= piecesRequired and not setBonus.isEnabled then
          setBonus.isEnabled = true

          if setBonus.onEnabled then
            setBonus.onEnabled()
          end
        elseif piecesEquipped < piecesRequired and setBonus.isEnabled then
          setBonus.isEnabled = false

          if setBonus.onDisabled then
            setBonus.onDisabled()
          end
        end
      end
    end
  end

  function aura_env.isUnsafeEncounter()
    return (not not encounterID)
        or (not not unsafeEncounters[encounterID])
  end

  local function reportFQDelay(delay)
    WeakAuras.ScanEvents("WA_FAKE_QUEUE_DELAY", delay)
  end

  local function getMaxWait()
    local maxWait

    if aura_env.isUnsafeEncounter() then
      maxWait = aura_env.config.maxWaitSafer
    else
      maxWait = aura_env.config.maxWait
    end

    return maxWait
  end

  local function reportMaxWait(value)
    local reportedValue = value

    if not reportedValue then
      reportedValue = getMaxWait()
    end

    WeakAuras.ScanEvents("WA_FAKE_QUEUE_MAX_WAIT", reportedValue)
  end

  local function getWaitTimeOffset()
    local offset

    if aura_env.config.useWorldPingOffset then
      offset = select(3, GetNetStats()) + aura_env.config.worldPingOffset
    else
      offset = aura_env.config.absoluteOffset
    end

    -- local framerate = GetFramerate()

    -- if framerate >= 20 then
    --   local frameTime = 1000 / framerate

    --   offset = offset + frameTime
    -- end

    return offset
  end

  local function getNextChannelingTickTime(spellRecord)
    if not spellRecord then
      return 0
    end

    local now = GetTime() * 1000

    if spellRecord == channelingSpellDetails.spellRecord then
      local nextTick = channelingSpellDetails.endTime

      for _, tickNumber in ipairs(spellRecord.modes[spellRecord.mode].processedTicks) do
        local tickTime = channelingSpellDetails.startTime + (channelingSpellDetails.tickFrequency * tickNumber)

        if tickTime > now then
          nextTick = tickTime
          break
        end
      end

      nextTick = nextTick - getWaitTimeOffset()

      return nextTick
    end

    return 0
  end

  local function getNextDebuffTickTime(spellRecord)
    if not spellRecord then
      return 0
    end

    local spellName,
    spellRank,
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
      local tickDuration = (duration / spellRecord.modes[spellRecord.mode].ticks) * 1000
      local nextTick = expirationTime

      for _, tickNumber in ipairs(spellRecord.modes[spellRecord.mode].processedTicks) do
        local tickTime = startTime + (tickDuration * tickNumber)

        if tickTime > now then
          nextTick = tickTime
          break
        end
      end

      nextTick = nextTick - getWaitTimeOffset() - castTime

      return nextTick
    end

    return 0
  end

  local function fakeQueue(macroSpellIdentifier)
    if not aura_env.fqEnabled then
      return
    end

    if not macroSpellIdentifier then
      print(string.format("Spell name is required for a Fake Queue macro."))
      return
    end

    local spellName, spellRank = GetSpellInfo(macroSpellIdentifier)

    if not spellName then
      print(string.format("Wrong Fake Queue macro spell name: %s", macroSpellIdentifier))
      return
    end

    local channeledSpellRecord = channelingSpellDetails.spellRecord
    local spellRecord = spells[buildSpellRecordName(spellName, spellRank)]
    local nextChanneledTickTime = getNextChannelingTickTime(channeledSpellRecord)
    local nextDebuffTickTime = getNextDebuffTickTime(spellRecord)
    local maxWaitTime = getMaxWait()
    local now = GetTime() * 1000
    local maxWaitUntil = now + maxWaitTime

    if nextChanneledTickTime > maxWaitUntil then
      log(
        string.format(
          "Ignored channeled tick wait time (%s MS), it exceeds max wait time.",
          nextChanneledTickTime - now
        )
      )
      nextChanneledTickTime = 0
    end

    if nextDebuffTickTime > maxWaitUntil then
      log(
        string.format(
          "Ignored %s tick wait time (%s MS), it exceeds max wait time.",
          buildSpellRecordName(spellName, spellRank),
          nextDebuffTickTime - now
        )
      )
      nextDebuffTickTime = 0
    end

    local nextTickTime = max(nextChanneledTickTime, nextDebuffTickTime)

    if nextTickTime == 0 or nextTickTime <= now then
      log("Possible clipped ticks not found.")
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
        log("GCD remaining time exceeds wait time.")
        return
      end
    end

    local loopLength = waitFor / 1000 * aura_env.config.oneSecondLoopLength

    reportFQDelay(waitFor)

    for i = 1, loopLength do
      -- nothing
    end

    log(string.format("Waited for %s MS.", waitFor))
  end

  local function fakeQueueCalibrate()
    local env = aura_env

    Timer:ScheduleTimer(function()
      local frameTestStartTime = GetTime()

      Timer:ScheduleTimer(function()
        local loopTestStartTime = GetTime()
        local frameTime = loopTestStartTime - frameTestStartTime

        Timer:ScheduleTimer(function()
          local config = WeakAurasSaved["displays"][env.id]["config"]

          for i = 1, config.calibrationLoopLength do
            -- nothing
          end

          local loopTime = GetTime() - loopTestStartTime - frameTime
          local oneSecondRatio = 1 / loopTime

          config.oneSecondLoopLength = config.calibrationLoopLength * oneSecondRatio
          config.calibrationLoopLength = config.oneSecondLoopLength * config.calibrationLoopDuration
        end, 0)
      end, 0)
    end, 1)
  end

  local function toggleFQEnabled()
    WeakAuras.ScanEvents("WA_TOGGLE_FQ")
  end

  local function resetChannelingSpellDetails()
    channelingSpellDetails.startTime = 0
    channelingSpellDetails.endTime = 0
    channelingSpellDetails.tickFrequency = 0
    channelingSpellDetails.spellRecord = nil
  end

  aura_env.eventListeners = {
    ["UNIT_SPELLCAST_CHANNEL_START"] = function()
      local spellName, rankText, _, _, startTime, endTime = UnitChannelInfo("player")
      local spellRecord = spells[buildSpellRecordName(spellName, rankText)]

      if spellRecord then
        channelingSpellDetails.startTime = startTime
        channelingSpellDetails.endTime = endTime
        channelingSpellDetails.spellRecord = spellRecord
        channelingSpellDetails.tickFrequency = (endTime - startTime) / spellRecord.modes[spellRecord.mode].ticks
        log(
          string.format(
            "Channeled spell cast registered: %s %s. Start: %s. End: %s.",
            spellName or "",
            rankText or "",
            startTime or 0,
            endTime or 0
          )
        )
      else
        resetChannelingSpellDetails()
        log("Channeled spell cast reset: Unknown spell. Event: UNIT_SPELLCAST_CHANNEL_START.")
      end

      return false
    end,
    ["UNIT_SPELLCAST_CHANNEL_UPDATE"] = function()
      local spellName, rankText, _, _, startTime, endTime = UnitChannelInfo("player")
      local spellRecord = spells[buildSpellRecordName(spellName, rankText)]

      if spellRecord then
        log("Pushback: " .. channelingSpellDetails.endTime - endTime)
        channelingSpellDetails.endTime = endTime
      else
        resetChannelingSpellDetails()
        log("Channeled spell cast reset: Unknown spell. Event: UNIT_SPELLCAST_CHANNEL_UPDATE.")
      end

      return false
    end,
    ["UNIT_SPELLCAST_CHANNEL_STOP"] = function()
      resetChannelingSpellDetails()
      log("Channeled spell cast reset: Channeling ended. Event: UNIT_SPELLCAST_CHANNEL_STOP.")

      return false
    end,
    ["ENCOUNTER_START"] = function(dbmEncounterID)
      encounterID = dbmEncounterID
      reportMaxWait()
      log(string.format("Encounter start. Encounter ID: %s.", encounterID or ""))

      return true
    end,
    ["ENCOUNTER_END"] = function()
      encounterID = nil
      log("Encounter end.")

      return false
    end,
    ["PLAYER_REGEN_DISABLED"] = function()
      reportMaxWait()
      log("Player is in combat.")

      return false
    end,
    ["WA_TOGGLE_FQ"] = function()
      if aura_env.fqEnabled then
        aura_env.fqEnabled = false
        reportMaxWait(0)
        log("Fake Queue disabled.")
      else
        aura_env.fqEnabled = true
        reportMaxWait()
        log("Fake Queue enabled.")
      end

      return true
    end,
    ["UNIT_INVENTORY_CHANGED"] = function()
      checkItemSetBonuses()

      return false
    end,
    ["FAKE_QUEUE_DEBUG_EVENT"] = function(event)
      log(string.format("Unhandled event in trigger 1: %s", event))

      return false
    end
  }

  ------------- For internal use ---------------
  setglobal("FQGetMaxWait", getMaxWait)
  ----------------------------------------------
  setglobal("FQ", fakeQueue)
  setglobal("FQToggle", toggleFQEnabled)
  setglobal("FQCalibrate", fakeQueueCalibrate)

  checkItemSetBonuses()
end

-- UNIT_SPELLCAST_CHANNEL_START:player,UNIT_SPELLCAST_CHANNEL_UPDATE:player,UNIT_SPELLCAST_CHANNEL_STOP:player,UNIT_INVENTORY_CHANGED,PLAYER_REGEN_DISABLED,ENCOUNTER_START,ENCOUNTER_END,WA_TOGGLE_FQ
function Trigger1(event, ...)
  if not aura_env.eventListeners then
    return false
  end

  local eventListener = aura_env.eventListeners[event]

  if not eventListener then
    return aura_env.eventListeners["FAKE_QUEUE_DEBUG_EVENT"](event)
  end

  return eventListener(...) or false
end
