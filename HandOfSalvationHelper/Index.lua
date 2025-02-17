function Init()
  local playerClass = select(2, UnitClass("player"))
  local minThreat = aura_env.config.minThreat
  local maxIcons = aura_env.config.maxIcons
  local shouldIgnoreSelf = aura_env.config.shouldIgnoreSelf
  local shouldCheckFocus = aura_env.config.shouldCheckFocus
  local trackedSpellID = aura_env.config.trackedSpellID
  local blacklistedNames = {}

  for index, data in pairs(aura_env.config.blacklistedNames) do
    if data and data.name then
      aura_env.blacklistedNames[data.name] = true
    end
  end

  local function isTalentLearned(tab, talentId)
    local _, _, _, _, pointsSpent = GetTalentInfo(tab, talentId)

    return pointsSpent > 0
  end

  local function isPlayerTank()
    return (playerClass == "PALADIN" and isTalentLearned(2, 18))
        or (playerClass == "DRUID" and isTalentLearned(2, 16))
        or (playerClass == "WARRIOR" and isTalentLearned(3, 18))
        or (playerClass == "DEATHKNIGHT" and isTalentLearned(1, 24))
  end

  local function compareAggroTableValues(a, b)
    return a.threatPercent > b.threatPercent
  end

  -- UNIT_THREAT_LIST_UPDATE:target:focus,PLAYER_TARGET_CHANGED,PLAYER_FOCUS_CHANGED,PLAYER_REGEN_ENABLED
  function aura_env:Trigger1(allstates, event, ...)
    for _, state in pairs(allstates) do
      state.show = false;
      state.changed = true;
    end

    local cdStart, cdDuration = GetSpellCooldown(1038)

    local shouldAbort =
        (cdDuration and cdDuration > 0)
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_REGEN_ENABLED"
        or (not UnitExists("target") and not UnitExists("focus"))

    if shouldAbort then
      return allstates
    end

    local _, trackedCoolDownDuration = GetSpellCooldown(trackedSpellID)

    if trackedCoolDownDuration > 0 then
      return allstates
    end

    local aggroTable = {}

    for unitID in WA_IterateGroupMembers() do
      local isTanking, status, threatPercent = UnitDetailedThreatSituation(unitID, 'target')

      if not status and shouldCheckFocus then
        isTanking, status, threatPercent = UnitDetailedThreatSituation(unitID, 'focus')
      end

      local unitIsPlayer = UnitIsUnit(unitID, "player")

      local shouldSkip =
          (unitIsPlayer and shouldIgnoreSelf)
          or (unitIsPlayer and isPlayerTank())
          or not threatPercent
          or threatPercent < minThreat

      if not shouldSkip then
        local isTank, isHeal, isDPS = UnitGroupRolesAssigned(unitID);

        if not isTank and not blacklistedNames[UnitName(unitID)] then
          if isTanking then
            threatPercent = 999999
          end

          table.insert(aggroTable, {
            unit          = unitID,
            threatPercent = threatPercent,
            isTanking     = not not isTanking,
          })
        end
      end
    end

    table.sort(aggroTable, compareAggroTableValues)

    for i = 1, maxIcons do
      local data = aggroTable[i]

      if data then
        if data.isTanking then
          data.threatPercent = 100
        end

        allstates[data.unit] = {
          show = true,
          changed = true,
          unit = data.unit,
          progressType = "static",
          index = GetTime(),

          aggroIndex = i,
          isTanking = data.isTanking,
          threatPercent = math.floor(data.threatPercent),
        }
      end
    end

    return allstates
  end
end
