local LIB_NAME = "SoltiFakeQueueContext"
LibStub:NewLibrary(LIB_NAME, 1)
local Context = LibStub(LIB_NAME)

local myClass = select(2, UnitClass("player"))

local modTypes = {
  spell = "spell",
  aura = "aura",
  auraFull = "auraFull"
}

Context.modTypes = modTypes

Context.itemSetSlots = {
  (GetInventorySlotInfo("ChestSlot")),
  (GetInventorySlotInfo("HeadSlot")),
  (GetInventorySlotInfo("ShoulderSlot")),
  (GetInventorySlotInfo("LegsSlot")),
  (GetInventorySlotInfo("HandsSlot")),
}

function Context:InitSpellMods()
  local sources = self.spellModifications.classSources[myClass] or {}

  self.spellModifications.sources = {
    itemSets = {},
    glyphs = sources.glyphs or {},
    talents = sources.talents or {}
  }

  for itemSetName, itemSet in pairs(sources.itemSets or {}) do
    local updatedItemSet = {}
    updatedItemSet.setBonuses = itemSet.setBonuses

    local updatedItems = {}
    updatedItemSet.items = updatedItems

    for _, itemID in pairs(itemSet.items) do
      updatedItems[itemID] = true
    end

    self.spellModifications.sources.itemSets[itemSetName] = updatedItemSet
  end
end

function Context:UpdateItemSetSpellMods()
  local spellMods = {}
  self.spellModifications.active.sources.items = spellMods

  for itemSetName, itemSet in pairs(self.spellModifications.sources.itemSets) do
    local setPiecesEquipped = 0
    for _, itemSlot in ipairs(self.itemSetSlots) do
      local itemID = GetInventoryItemID("player", itemSlot)

      if itemSet.items[itemID] then
        setPiecesEquipped = setPiecesEquipped + 1
      end

      local spellModList = itemSet.setBonuses[setPiecesEquipped]

      if spellModList then
        for _, spellModID in pairs(spellModList) do
          table.insert(spellMods, self.spellModifications.list[spellModID])
        end
      end
    end
  end
end

function Context:UpdateGlyphSpellMods()
  local spellMods = {}
  self.spellModifications.active.sources.glyphs = spellMods

  local maxGlyphAmount = 6

  for i = 1, maxGlyphAmount do
    local enabled, glyphType, glyphSpellID = GetGlyphSocketInfo(i)

    local spellModList = self.spellModifications.sources.glyphs[glyphSpellID]

    if spellModList then
      for _, spellModID in pairs(spellModList) do
        table.insert(spellMods, self.spellModifications.list[spellModID])
      end
    end
  end
end

function Context:UpdateTalentSpellMods()
  local spellMods = {}
  self.spellModifications.active.sources.talents = spellMods

  local numTalentTabs = GetNumTalentTabs();
  local talentMods = self.spellModifications.sources.talents

  if not talentMods or not talentMods.tabs then
    return
  end

  for tabIndex = 1, numTalentTabs do
    local tabMods = talentMods.tabs[tabIndex]
    local numTalents = GetNumTalents(tabIndex);

    if tabMods and tabMods.talentIndexes then
      for talentIndex = 1, numTalents do
        local nameTalent, icon, tier, column, currentRank, maxRank = GetTalentInfo(tabIndex, talentIndex);
        local talentMods = tabMods.talentIndexes[talentIndex]

        if talentMods and currentRank > 0 then
          local spellModList = talentMods[currentRank]

          if spellModList then
            for _, spellModID in pairs(spellModList) do
              table.insert(spellMods, self.spellModifications.list[spellModID])
            end
          end
        end
      end
    end
  end
end

function Context:UpdateSpellMods()
  self:UpdateItemSetSpellMods()
  self:UpdateGlyphSpellMods()
  self:UpdateTalentSpellMods()
end

function Context:ApplySpellMods()
  if Context.InitSpells and not self.spellsByID then
    Context:InitSpells()
  end

  if self.spellsByID then
    for spellID, spellRecord in pairs(self.spellsByID) do
      if type(spellRecord.ticks) == "table" then
        for i, value in ipairs(spellRecord.defaultTicks) do
          spellRecord.ticks[i] = value
        end
      else
        spellRecord.ticks = spellRecord.defaultTicks
      end
    end
  end

  self.spellModifications.active.list = {}

  local triggers = {}
  self.spellModifications.active.triggers = triggers

  for _, spellModTable in pairs(self.spellModifications.active.sources) do
    for _, spellMod in pairs(spellModTable) do
      if spellMod.type == modTypes.spell and self.spellsByID then
        for _, spellID in pairs(spellMod.spellIDs) do
          local spellRecord = self.spellsByID[spellID]

          if spellRecord and type(spellRecord.ticks) == "number" then
            spellRecord.ticks = spellRecord.ticks + spellMod.ticks
          elseif spellRecord and type(spellRecord.ticks) == "table" then
            for i, value in ipairs(spellRecord.ticks) do
              spellRecord.ticks[i] = value + spellMod.ticks
            end
          end
        end
      elseif spellMod.type == modTypes.aura or spellMod.type == modTypes.auraFull then
        local event = spellMod.trigger.event
        triggers[event] = triggers[event] or {}

        for _, subEvent in pairs(spellMod.trigger.subEvent or { "" }) do
          triggers[event][subEvent] = triggers[event][subEvent] or {}

          table.insert(triggers[event][subEvent], spellMod)
        end
      end

      table.insert(self.spellModifications.active.list, spellMod)
    end
  end
end

local function onGlyphsUpdate()
  Context.log("Glyph update")
  Context:UpdateGlyphSpellMods()
  Context:ApplySpellMods()
end

local function onTalentsUpdate()
  Context.log("Talents update")
  Context:UpdateTalentSpellMods()
  Context:ApplySpellMods()
end

local function onItemsUpdate()
  Context.log("Items update")
  Context:UpdateItemSetSpellMods()
  Context:ApplySpellMods()
end

local function onInit()
  Context:UpdateSpellMods()
  Context:ApplySpellMods()
end

local eventListeners = Context.eventListeners or {}
Context.eventListeners = eventListeners

eventListeners.UNIT_INVENTORY_CHANGED = onItemsUpdate
eventListeners.PLAYER_EQUIPMENT_CHANGED = onItemsUpdate
eventListeners.GLYPH_ADDED = onGlyphsUpdate
eventListeners.GLYPH_DISABLED = onGlyphsUpdate
eventListeners.GLYPH_ENABLED = onGlyphsUpdate
eventListeners.GLYPH_REMOVED = onGlyphsUpdate
eventListeners.GLYPH_UPDATED = onGlyphsUpdate
eventListeners.PLAYER_TALENT_UPDATE = onTalentsUpdate
eventListeners.ACTIVE_TALENT_GROUP_CHANGED = onTalentsUpdate
eventListeners.CHARACTER_POINTS_CHANGED = onTalentsUpdate
eventListeners.CONFIRM_TALENT_WIPE = onTalentsUpdate

Context.spellModifications = {
  active = {
    list = {},
    triggers = {},
    sources = {
      items = {},
      glyphs = {},
      talents = {},
    }
  },
  classSources = {
    ["PRIEST"] = {
      itemSets = {
        ["Shadow Tier 6"] = {
          items = {
            31061, 31064, 31067, 31070, 31065,
            34434, 34528, 34563,
          },
          setBonuses = {
            [2] = { 1 },
          }
        },
        ["Shadow Tier 9"] = {
          items = {
            48088, 48091, 48090, 48087, 48089, -- 258 Horde
            48095, 48092, 48093, 48096, 48094, -- 245 Horde
            48098, 48101, 48100, 48097, 48099, -- 232 Horde
            48085, 48082, 48083, 48086, 48084, -- 258 Alliance
            48078, 48081, 48080, 48077, 48079, -- 245 Alliance
            48073, 48076, 48075, 48072, 48074, -- 232 Alliance
          },
          setBonuses = {
            [2] = { 2 },
          }
        },
      },
      glyphs = {
        [63246] = { 3 }
      },
      talents = {
        tabs = {
          [3] = {
            talentIndexes = {
              [25] = {
                [1] = { 26 },
                [2] = { 26 },
                [3] = { 26 },
              }
            }
          }
        },
      },
    },
    ["WARLOCK"] = {
      itemSets = {
        ["Tier 4"] = {
          items = {
            28963, 28968, 28966, 28967, 28964,
          },
          setBonuses = {
            [4] = { 4, 5 },
          }
        },
      },
      glyphs = {
        [56241] = { 6 }
      },
      talents = {
        tabs = {
          [1] = {
            talentIndexes = {
              [27] = {
                [1] = { 24, 25 },
                [2] = { 24, 25 },
                [3] = { 24, 25 },
                [4] = { 24, 25 },
                [5] = { 24, 25 },
              }
            }
          },
          [2] = {
            talentIndexes = {
              [17] = {
                [1] = { 7 },
                [2] = { 8 },
                [3] = { 9 },
              },
            }
          }
        },
      },
    },
    ["DRUID"] = {
      itemSets = {
        ["Balance Tier 6"] = {
          items = {
            31043, 31035, 31040, 31046, 31049,
            34572, 34446, 34555
          },
          setBonuses = {
            [2] = { 10 },
          }
        },
        ["Feral Tier 7"] = {
          items = {
            39557, 39553, 39555, 39554, 39556,
            40472, 40473, 40493, 40471, 40494
          },
          setBonuses = {
            [2] = { 14 },
          }
        },
        ["Feral Tier 9"] = {
          items = {
            48213, 48214, 48215, 48216, 48217,
            48212, 48211, 48210, 48209, 48208,
            48203, 48204, 48205, 48206, 48207,
            48202, 48201, 48200, 48199, 48198,
            48193, 48194, 48195, 48196, 48197,
            48192, 48188, 48190, 48189, 48191,
          },
          setBonuses = {
            [2] = { 15 },
          }
        },
      },
      glyphs = {
        [54818] = { 12 },
        [54815] = { 13 },
      },
      talents = {
        tabs = {
          [1] = {
            talentIndexes = {
              [8] = {
                [1] = { 11 }
              }
            }
          }
        },
      },
    },
    ["MAGE"] = {
      itemSets = {
        ["Tier 6"] = {
          items = {
            31056, 31055, 31058, 31059, 31057,
            34574, 34447, 34557,
          },
          setBonuses = {
            [2] = { 16 }
          }
        }
      },
      glyphs = {},
      talents = {},
    },
    ["SHAMAN"] = {
      itemSets = {
        ["Elemental Tier 9"] = {
          items = {
            48312, 48310, 48313, 48314, 48315,
            48317, 48316, 48318, 48319, 48320,
            48324, 48325, 48323, 48322, 48321,
            48327, 48326, 48328, 48329, 48330,
            48334, 48335, 48333, 48332, 48331,
          },
          setBonuses = {
            [2] = { 17 }
          }
        },
        ["Elemental Tier 10"] = {
          items = {
            51239, 51238, 51237, 51236, 51235,
            51200, 51201, 51202, 51203, 51204,
            50841, 50842, 50843, 50844, 50845,
            51757, 51758, 51759, 51760, 51761, -- TODO WTF is this set ?????
          },
          setBonuses = {
            [4] = { 18 }
          }
        },
      },
      glyphs = {},
      talents = {},
    },
    ["ROGUE"] = {
      itemSets = {},
      glyphs = {
        [56800] = { 19 },
        [56812] = { 20 },
        [56801] = { 21 },
      },
      talents = {}
    },
    ["HUNTER"] = {
      itemSets = {},
      glyphs = {
        [56832] = { 22 },
      },
      talents = {
        tabs = {
          [2] = {
            talentIndexes = {
              [27] = {
                [1] = { 23 }
              }
            }
          }
        },
      }
    },
  },
  list = {
    [1] = {
      name = "Spriest T6",
      id = 38413,
      type = modTypes.spell,
      spellIDs = {
        589, 594, 970,
        992, 2767, 10892,
        10893, 10894, 25367,
        25368, 48124, 48125,
      },
      ticks = 1,
    },
    [2] = {
      name = "Spriest T9",
      id = 67193,
      type = modTypes.spell,
      spellIDs = {
        34914, 34916, 34917,
        48159, 48160,
      },
      ticks = 2,
    },
    [3] = {
      name = "Glyph of Hymn of Hope",
      id = 63246,
      type = modTypes.spell,
      spellIDs = { 64901 },
      ticks = 1
    },
    [4] = {
      name = "Warlock T4, Corruption",
      id = 37380,
      type = modTypes.spell,
      spellIDs = { -- Corruption
        172, 6222, 6223,
        7648, 11671, 11672,
        25311, 27216, 47812,
        47813,
      },
      ticks = 1,
    },
    [5] = {
      name = "Warlock T4, Immolate",
      id = 37380,
      type = modTypes.spell,
      spellIDs = { -- Immolate
        348, 707, 1094,
        2941, 11665, 11667,
        11668, 25309, 27215,
        47810, 47811,
      },
      ticks = 1,
    },
    [6] = {
      name = "Glyph of Curse of Agony",
      id = 56241,
      type = modTypes.spell,
      spellIDs = {
        980, 1014, 6217,
        11711, 11712, 11713,
        27218, 47863, 47864
      },
      ticks = 2,
    },
    [7] = {
      name = "Demo lock Molten Core talent 1 pt.",
      id = 47245,
      type = modTypes.spell,
      spellIDs = {
        348, 707, 1094,
        2941, 11665, 11667,
        11668, 25309, 27215,
        47810, 47811,
      },
      ticks = 1,
    },
    [8] = {
      name = "Demo lock Molten Core talent 2 pts.",
      id = 47246,
      type = modTypes.spell,
      spellIDs = {
        348, 707, 1094,
        2941, 11665, 11667,
        11668, 25309, 27215,
        47810, 47811,
      },
      ticks = 2
    },
    [9] = {
      name = "Demo lock Molten Core talent 3 pts.",
      id = 47247,
      type = modTypes.spell,
      spellIDs = {
        348, 707, 1094,
        2941, 11665, 11667,
        11668, 25309, 27215,
        47810, 47811,
      },
      ticks = 3,
    },
    [10] = {
      name = "Balance Druid T6",
      id = 38414,
      type = modTypes.spell,
      spellIDs = { -- Moonfire
        8921, 8924, 8925,
        8926, 8927, 8928,
        8929, 9833, 9834,
        9835, 26987, 26988,
        48462, 48463, 38414,
      },
      ticks = 1,
    },
    [11] = {
      name = "Balance Druid Nature's Splendor talent",
      id = 57865,
      type = modTypes.spell,
      spellIDs = {
        8924, 8921, 8925,
        8926, 8927, 8928,
        8929, 9833, 9834,
        9835, 26987, 26988,
        48462, 48463, 5570,
        24974, 24975, 24976,
        24977, 27013, 48468,
      },
      ticks = 1,
    },
    [12] = {
      name = "Glyph of Rip",
      id = 54818,
      type = modTypes.spell,
      spellIDs = {
        1079, 9492, 9493,
        9752, 9894, 9896,
        27008, 49799, 49800,
      },
      ticks = 2,
    },
    [13] = { --  TODO
      name = "Glyph of Shred",
      id = 54815,
      type = modTypes.aura,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        subEvent = {
          "SPELL_CAST_SUCCESS",
        },
        spellIDs = {
          [5221] = true,
          [6800] = true,
          [8992] = true,
          [9829] = true,
          [9830] = true,
          [27001] = true,
          [27002] = true,
          [48571] = true,
          [48572] = true,
        }
      },
      spellIDs = {
        1079, 9492, 9493,
        9752, 9894, 9896,
        27008, 49799, 49800,
      },
      ticks = 1,
      limit = 3,
    },
    [14] = {
      name = "Feral Druid T7",
      id = 60141,
      type = modTypes.spell,
      spellIDs = {
        1079, 9492, 9493,
        9752, 9894, 9896,
        27008, 49799, 49800,
      },
      ticks = 2,
    },
    [15] = {
      name = "Feral Druid T9",
      id = 67121,
      type = modTypes.spell,
      spellIDs = {
        1822, 1823, 1824,
        9904, 27003, 48573,
        48574,
      },
      ticks = 1,
    },
    [16] = {
      name = "Mage T6",
      id = 38396,
      type = modTypes.spell,
      spellIDs = { 12051 },
      ticks = 1,
    },
    [17] = {
      name = "Ele Shaman T9",
      id = 67227,
      type = modTypes.spell,
      spellIDs = {
        8050, 8052, 8053,
        10447, 10448, 29228,
        25457, 49232, 49233,
      },
      ticks = 3,
    },
    [18] = { --  TODO
      name = "Ele Shaman T10",
      id = 70817,
      type = modTypes.aura,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        missType = "ABSORB",
        subEvent = {
          "SPELL_DAMAGE", "SPELL_MISSED",
        },
        spellIDs = {
          [51505] = true,
          [60043] = true,
        }
      },
      spellIDs = {
        8050, 8052, 8053,
        10447, 10448, 29228,
        25457, 49232, 49233,
      },
      ticks = 2,
    },
    [19] = {
      name = "Glyph of Backstab",
      id = 56800,
      type = modTypes.aura,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        subEvent = {
          "SPELL_CAST_SUCCESS",
        },
        spellIDs = {
          [53] = true,
          [2589] = true,
          [2590] = true,
          [2591] = true,
          [8721] = true,
          [11279] = true,
          [11280] = true,
          [11281] = true,
          [25300] = true,
          [26863] = true,
          [48656] = true,
          [48657] = true,
        }
      },
      spellIDs = {
        1943, 8639, 8640,
        11273, 11274, 11275,
        26867, 48671, 48672,
      },
      ticks = 1,
      limit = 3,
    },
    [20] = {
      name = "Glyph of Garrote",
      id = 56812,
      type = modTypes.spell,
      spellIDs = {
        703, 8631, 8632,
        8633, 11289, 11290,
        26839, 26884, 48675,
        48676,
      },
      ticks = -1,
    },
    [21] = {
      name = "Glyph of Rupture",
      id = 56801,
      type = modTypes.spell,
      spellIDs = {
        1943, 8639, 8640,
        11273, 11274, 11275,
        26867, 48671, 48672,
      },
      ticks = 2,
    },
    [22] = {
      name = "Glyph of Serpent Sting",
      id = 56832,
      type = modTypes.spell,
      spellIDs = {
        1978, 13549, 13550,
        13551, 13552, 13553,
        13554, 13555, 25295,
        27016, 49000, 49001,
      },
      ticks = 2,
    },
    [23] = {
      name = "MM Hunter Chimera Shot talent",
      id = 53209,
      type = modTypes.auraFull,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        missType = "ABSORB",
        subEvent = {
          "SPELL_DAMAGE", "SPELL_MISSED",
        },
        spellIDs = {
          [53209] = true,
        },
      },
      spellIDs = {
        1978, 13549, 13550,
        13551, 13552, 13553,
        13554, 13555, 25295,
        27016, 49000, 49001,
        3034,
      },
    },
    [24] = {
      name = "Affli Lock Everlasting Affliction talent, casts",
      id = 47205,
      type = modTypes.auraFull,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        missType = "ABSORB",
        subEvent = {
          "SPELL_DAMAGE", "SPELL_MISSED",
        },
        spellIDs = {
          [686] = true,
          [695] = true,
          [705] = true,
          [1088] = true,
          [1106] = true,
          [7641] = true,
          [11659] = true,
          [11660] = true,
          [11661] = true,
          [25307] = true,
          [27209] = true,
          [47808] = true,
          [47809] = true,
          [48181] = true,
          [59161] = true,
          [59163] = true,
          [59164] = true,
        }
      },
      spellIDs = {
        172, 6222, 6223,
        7648, 11671, 11672,
        25311, 27216, 47812,
        47813,
      },
    },
    [25] = {
      name = "Affli Lock Everlasting Affliction talent, channeled",
      id = 47205,
      type = modTypes.auraFull,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        subEvent = {
          "SPELL_CAST_SUCCESS",
        },
        spellIDs = {
          [1120] = true,
          [8288] = true,
          [8289] = true,
          [11675] = true,
          [27217] = true,
          [47855] = true,
          [689] = true,
          [699] = true,
          [709] = true,
          [7651] = true,
          [11699] = true,
          [11700] = true,
          [27219] = true,
          [27220] = true,
          [47857] = true,
        }
      },
      spellIDs = {
        172, 6222, 6223,
        7648, 11671, 11672,
        25311, 27216, 47812,
        47813,
      },
    },
    [26] = {
      name = "Shadow Priest Pain and Suffering talent",
      id = 47582,
      type = modTypes.auraFull,
      trigger = {
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        subEvent = {
          "SPELL_CAST_SUCCESS",
        },
        spellIDs = {
          [15407] = true,
          [17311] = true,
          [17312] = true,
          [17313] = true,
          [17314] = true,
          [18807] = true,
          [25387] = true,
          [48155] = true,
          [48156] = true,
        }
      },
      spellIDs = {
        589, 594, 970,
        992, 2767, 10892,
        10893, 10894, 25367,
        25368, 48124, 48125,
      },
    },
  }
}

Context:InitSpellMods()
onInit()
