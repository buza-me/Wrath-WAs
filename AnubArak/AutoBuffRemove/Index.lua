function Init()
  local playerClass = select(2, UnitClass("player"))
  local playerName = UnitName("player")

  local hots = {
    774,   -- Rejuv
    8936,  -- Regrowth
    33763, -- Lifebloom
    48438, -- Wild Growth
    48068, -- Renew
    61301, -- Riptide
    52000, -- Earthliving
    64891, -- Holy Mending, Holy Paladin T8 set bonus
  }

  local healthBuffs = {
    47440, -- Commanding Shout
    48161, -- Power Word: Fortitude
    48162, -- Prayer of Fortitude
    72590, -- Runescroll of Fortitude
  }

  local dangerousDebuffs = {
    67862,
    67721,
    66012,
  }

  local penetratingColdSpellIDs = {
    66013, -- 10 N
    68509, -- 10 HC / Asc
    67700, -- 25 N
    68510, -- 25 HC / Asc
  }

  local leechingSwarmSpellIDs = {
    66118,
    67630,
    68646,
    68647,
  }

  local function getNames(spellIDs, targetTable)
    if not targetTable then
      targetTable = {}
    end

    for _, spellID in pairs(spellIDs) do
      local name = GetSpellInfo(spellID)

      if name then
        table.insert(targetTable, name)
      end
    end

    return targetTable
  end

  local function getValuesAsFlags(values, targetTable)
    if not targetTable then
      targetTable = {}
    end

    for _, value in pairs(values) do
      targetTable[value] = true
    end

    return targetTable
  end

  local hotNames = getNames(hots)
  local healthBuffNames = getNames(healthBuffs)
  local dangerousDebuffNames = getNames(dangerousDebuffs)
  local leechingSwarmName = GetSpellInfo(leechingSwarmSpellIDs[1])
  local penetratingColdFlags = getValuesAsFlags(penetratingColdSpellIDs)
  local leechingSwarmFlags = getValuesAsFlags(leechingSwarmSpellIDs)

  local function isTalentLearned(tab, talentId)
    local _, _, _, _, pointsSpent = GetTalentInfo(tab, talentId)

    return pointsSpent > 0
  end

  local function isPlayerTank()
    return (playerClass == "DRUID" and isTalentLearned(2, 16))
        or (playerClass == "WARRIOR" and isTalentLearned(3, 18))
        or (playerClass == "PALADIN" and isTalentLearned(2, 18))
        or (playerClass == "DEATHKNIGHT" and isTalentLearned(1, 24))
  end

  local function removeBuffs(buffs)
    for _, name in pairs(buffs) do
      CancelUnitBuff("player", name)
    end
  end

  function aura_env.SPELL_CAST_START(
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
        not aura_env.config.shouldRemoveHealthBuffs
        or not leechingSwarmFlags[spellID]
        or isPlayerTank()

    if shouldAbort then
      return false
    end

    removeBuffs(healthBuffNames)

    return false
  end

  function aura_env.SPELL_AURA_REMOVED(
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
        not aura_env.config.shouldRemoveHOTs
        or not penetratingColdFlags[spellID]
        or destName ~= playerName
        or not UnitDebuff("player", leechingSwarmName)
        or isPlayerTank()

    if shouldAbort then
      return false
    end

    for _, debuffName in pairs(dangerousDebuffNames) do
      if UnitDebuff("player", debuffName) then
        return false
      end
    end

    removeBuffs(hotNames)

    return false
  end
end

function Trigger1(event, timeStamp, subEvent, ...)
  local handler = aura_env[subEvent]

  if handler then
    return handler(...)
  end
end
