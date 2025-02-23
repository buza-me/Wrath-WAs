local LIB_NAME = "SoltiSpellQueueContext"
LibStub:NewLibrary(LIB_NAME, 1)
local Context = LibStub(LIB_NAME)

local myClass = select(2, UnitClass("player"))
local gameVersionMajor = string.sub(GetBuildInfo(), 1, 1)
local isTBC = gameVersionMajor == "2"

local spellTypes = {
  channeled = "channeled",
  debuff = "debuff",
  finisherDebuff = "finisherDebuff",
}

Context.spellTypes = spellTypes
Context.spellsByName = {}
Context.spellsByID = {}

function Context:InitSpells()
  local spellTemplates = self.spellTemplates[myClass] or {}

  Context.spellsByName = {}
  Context.spellsByID = {}
  local spellsByName = Context.spellsByName
  local spellsByID = Context.spellsByID

  for _, spellTemplate in pairs(spellTemplates) do
    local templateRanks = spellTemplate.ranks or {}
    local ranks = {}

    for spellID, totalTicks in pairs(templateRanks) do
      local localizedName, localizedRank = GetSpellInfo(spellID)
      localizedRank = localizedRank or ""
      local ticks = totalTicks

      if type(ticks) == "table" then
        ticks = {}

        for i, value in ipairs(totalTicks) do
          ticks[i] = value
        end
      end

      if localizedName then
        if not spellsByName[localizedName] then
          spellsByName[localizedName] = {
            ranks = ranks,
          }
        end

        local spellRecord = {
          type = spellTemplate.type,
          spellID = spellID,
          name = localizedName,
          rankText = localizedRank,
          ticks = ticks,
          defaultTicks = totalTicks,
          oneYardTravelTime = spellTemplate.oneYardTravelTime
        }

        spellsByName[localizedName].ranks[localizedRank] = spellRecord

        spellsByID[spellID] = spellRecord
      end
    end
  end
end

function Context:GetSpellRecord(spellName, rankText, spellID)
  local spellRecord = nil

  if spellName then
    spellRecord = self.spellsByName[spellName] and self.spellsByName[spellName].ranks[rankText or ""]
  else
    spellRecord = self.spellsByID[spellID]
  end

  if not spellRecord and self.log then
    self.log(
      string.format(
        "SQ - Unknown spell. Name: %s. Rank: %s. Spell ID: %s.",
        spellName or "",
        rankText or "",
        spellID or ""
      )
    )
  end

  return spellRecord
end

local spellTemplates = {
  ["PRIEST"] = {
    ["Mind Flay"] = {
      type = spellTypes.channeled,
      ranks = {
        [15407] = 3,
        [17311] = 3,
        [17312] = 3,
        [17313] = 3,
        [17314] = 3,
        [18807] = 3,
        [25387] = 3,
        [48155] = 3,
        [48156] = 3,
      }
    },
    ["Mind Sear"] = {
      type = spellTypes.channeled,
      ranks = {
        [48045] = 5,
        [53023] = 5,
      }
    },
    ["Vampiric Touch"] = {
      type = spellTypes.debuff,
      ranks = {
        [34914] = 5,
        [34916] = 5,
        [34917] = 5,
        [48159] = 5,
        [48160] = 5,
      }
    },
    ["Devouring Plague"] = {
      type = spellTypes.debuff,
      ranks = {
        [2944] = 8,
        [19276] = 8,
        [19277] = 8,
        [19278] = 8,
        [19279] = 8,
        [19280] = 8,
        [25467] = 8,
        [48299] = 8,
        [48300] = 8,
      }
    },
    ["Shadow Word: Pain"] = {
      type = spellTypes.debuff,
      ranks = {
        [589] = 6,
        [594] = 6,
        [970] = 6,
        [992] = 6,
        [2767] = 6,
        [10892] = 6,
        [10893] = 6,
        [10894] = 6,
        [25367] = 6,
        [25368] = 6,
        [48124] = 6,
        [48125] = 6,
      }
    },
    ["Holy Fire"] = {
      type = spellTypes.debuff,
      ranks = {
        [14914] = 7,
        [15262] = 7,
        [15263] = 7,
        [15264] = 7,
        [15265] = 7,
        [15266] = 7,
        [15267] = 7,
        [15261] = 7,
        [25384] = 7,
        [48134] = 7,
        [48135] = 7,
      }
    },
    ["Hymn of Hope"] = {
      type = spellTypes.channeled,
      ranks = {
        [64901] = 4,
      }
    },
    ["Divine Hymn"] = {
      type = spellTypes.channeled,
      ranks = {
        [64843] = 4,
      }
    },
    ["Penance"] = {
      type = spellTypes.channeled,
      ranks = {
        [47540] = 3,
        [53006] = 3,
        [53007] = 3,
      }
    },
  },
  ["WARLOCK"] = {
    ["Drain Soul"] = {
      type = spellTypes.channeled,
      ranks = {
        [1120] = 5,
        [8288] = 5,
        [8289] = 5,
        [11675] = 5,
        [27217] = 5,
        [47855] = 5,
      }
    },
    ["Drain Life"] = {
      type = spellTypes.channeled,
      ranks = {
        [689] = 5,
        [699] = 5,
        [709] = 5,
        [7651] = 5,
        [11699] = 5,
        [11700] = 5,
        [27219] = 5,
        [27220] = 5,
        [47857] = 5,
      }
    },
    ["Drain Mana"] = {
      type = spellTypes.channeled,
      ranks = {
        [5138] = 5,
      }
    },
    ["Health Funnel"] = {
      type = spellTypes.channeled,
      ranks = {
        [755] = 10,
        [3698] = 10,
        [3699] = 10,
        [3700] = 10,
        [11693] = 10,
        [11694] = 10,
        [11695] = 10,
        [27259] = 10,
        [47856] = 10,
      }
    },
    ["Hellfire"] = {
      type = spellTypes.channeled,
      ranks = {
        [1949] = 15,
        [11683] = 15,
        [11684] = 15,
        [27213] = 15,
        [47823] = 15,
      }
    },
    ["Immolate"] = {
      type = spellTypes.debuff,
      ranks = {
        [348] = 5,
        [707] = 5,
        [1094] = 5,
        [2941] = 5,
        [11665] = 5,
        [11667] = 5,
        [11668] = 5,
        [25309] = 5,
        [27215] = 5,
        [47810] = 5,
        [47811] = 5,
      }
    },
    ["Rain of Fire"] = {
      type = spellTypes.channeled,
      ranks = {
        [5740] = 4,
        [6219] = 4,
        [11677] = 4,
        [11678] = 4,
        [27212] = 4,
        [47819] = 4,
        [47820] = 4,
      }
    },
    ["Corruption"] = {
      type = spellTypes.debuff,
      ranks = {
        [172] = 4,
        [6222] = 5,
        [6223] = 6,
        [7648] = 6,
        [11671] = 6,
        [11672] = 6,
        [25311] = 6,
        [27216] = 6,
        [47812] = 6,
        [47813] = 6,
      }
    },
    ["Curse of Agony"] = {
      type = spellTypes.debuff,
      ranks = {
        [980] = 12,
        [1014] = 12,
        [6217] = 12,
        [11711] = 12,
        [11712] = 12,
        [11713] = 12,
        [27218] = 12,
        [47863] = 12,
        [47864] = 12,
      }
    },
    ["Unstable Affliction"] = {
      type = spellTypes.debuff,
      ranks = {
        [30108] = 5,
        [30404] = 5,
        [30405] = 5,
        [47841] = 5,
        [47843] = 5,
      }
    },
  },
  ["DRUID"] = {
    ["Hurricane"] = {
      type = spellTypes.channeled,
      ranks = {
        [16914] = 10,
        [17401] = 10,
        [17402] = 10,
        [27012] = 10,
        [48467] = 10,
      },
    },
    ["Tranquility"] = {
      type = spellTypes.channeled,
      ranks = {
        [740] = 4,
        [8918] = 4,
        [9862] = 4,
        [9863] = 4,
        [26983] = 4,
        [48446] = 4,
        [48447] = 4,
      },
    },
    ["Moonfire"] = {
      type = spellTypes.debuff,
      ranks = {
        [8921] = 3,
        [8924] = 4,
        [8925] = 4,
        [8926] = 4,
        [8927] = 4,
        [8928] = 4,
        [8929] = 4,
        [9833] = 4,
        [9834] = 4,
        [9835] = 4,
        [26987] = 4,
        [26988] = 4,
        [48462] = 4,
        [48463] = 4,
      },
    },
    ["Insect Swarm"] = {
      type = spellTypes.debuff,
      ranks = {
        [5570] = 6,
        [24974] = 6,
        [24975] = 6,
        [24976] = 6,
        [24977] = 6,
        [27013] = 6,
        [48468] = 6,
      },
    },
    ["Rake"] = {
      type = spellTypes.debuff,
      ranks = {
        [1822] = 3,
        [1823] = 3,
        [1824] = 3,
        [9904] = 3,
        [27003] = 3,
        [48573] = 3,
        [48574] = 3,
      },
    },
    ["Rip"] = {
      type = spellTypes.finisherDebuff,
      ranks = {
        [1079] = { 6, 6, 6, 6, 6 },
        [9492] = { 6, 6, 6, 6, 6 },
        [9493] = { 6, 6, 6, 6, 6 },
        [9752] = { 6, 6, 6, 6, 6 },
        [9894] = { 6, 6, 6, 6, 6 },
        [9896] = { 6, 6, 6, 6, 6 },
        [27008] = { 6, 6, 6, 6, 6 },
        [49799] = { 6, 6, 6, 6, 6 },
        [49800] = { 6, 6, 6, 6, 6 },
      },
    },
  },
  ["MAGE"] = {
    ["Evocation"] = {
      type = spellTypes.channeled,
      ranks = {
        [12051] = 4,
      },
    },
    ["Blizzard"] = {
      type = spellTypes.channeled,
      ranks = {
        [10] = 8,
        [6141] = 8,
        [8427] = 8,
        [10185] = 8,
        [10186] = 8,
        [10187] = 8,
        [27085] = 8,
        [42939] = 8,
        [42940] = 8,
      },
    },
    ["Arcane Missiles"] = {
      type = spellTypes.channeled,
      ranks = {
        [5143] = 3,
        [5144] = 4,
        [5145] = 5,
        [8416] = 5,
        [8417] = 5,
        [10211] = 5,
        [10212] = 5,
        [25345] = 5,
        [27075] = 5,
        [38699] = 5,
        [38704] = 5,
        [42843] = 5,
        [42846] = 5,
      },
    },
    ["Living Bomb"] = {
      type = spellTypes.debuff,
      ranks = {
        [44457] = 4,
        [55359] = 4,
        [55360] = 4,
      },
    },
  },
  ["SHAMAN"] = {
    ["Flame Shock"] = {
      type = spellTypes.debuff,
      ranks = {
        [8050] = 6,
        [8052] = 6,
        [8053] = 6,
        [10447] = 6,
        [10448] = 6,
        [29228] = 6,
        [25457] = 6,
        [49232] = 6,
        [49233] = 6,
      }
    }
  },
  ["ROGUE"] = {
    ["Garrote"] = {
      type = spellTypes.debuff,
      ranks = {
        [703] = 6,
        [8631] = 6,
        [8632] = 6,
        [8633] = 6,
        [11289] = 6,
        [11290] = 6,
        [26839] = 6,
        [26884] = 6,
        [48675] = 6,
        [48676] = 6,
      },
    },
    ["Rupture"] = {
      type = spellTypes.finisherDebuff,
      ranks = {
        [1943] = { 4, 5, 6, 7, 8 },
        [8639] = { 4, 5, 6, 7, 8 },
        [8640] = { 4, 5, 6, 7, 8 },
        [11273] = { 4, 5, 6, 7, 8 },
        [11274] = { 4, 5, 6, 7, 8 },
        [11275] = { 4, 5, 6, 7, 8 },
        [26867] = { 4, 5, 6, 7, 8 },
        [48671] = { 4, 5, 6, 7, 8 },
        [48672] = { 4, 5, 6, 7, 8 },
      },
    },
  },
  ["HUNTER"] = {
    type = spellTypes.channeled,
    ["Volley"] = {
      ranks = {
        [1510] = 6,
        [14294] = 6,
        [14295] = 6,
        [27022] = 6,
        [58431] = 6,
        [58434] = 6,
      },
    },
    ["Viper Sting"] = {
      type = spellTypes.debuff,
      oneYardTravelTime = 24.6576,
      ranks = {
        [3034] = 4,
      },
    },
    ["Serpent Sting"] = {
      type = spellTypes.debuff,
      oneYardTravelTime = 24.6576,
      ranks = {
        [1978] = 5,
        [13549] = 5,
        [13550] = 5,
        [13551] = 5,
        [13552] = 5,
        [13553] = 5,
        [13554] = 5,
        [13555] = 5,
        [25295] = 5,
        [27016] = 5,
        [49000] = 5,
        [49001] = 5,
      },
    },
  },
}

local tbcSpellTemplates = {
  ["PRIEST"] = {
    ["Mind Flay"] = {
      type = spellTypes.channeled,
      ranks = {
        [15407] = 3,
        [17311] = 3,
        [17312] = 3,
        [17313] = 3,
        [17314] = 3,
        [18807] = 3,
        [25387] = 3,
      }
    },
    ["Vampiric Touch"] = {
      type = spellTypes.debuff,
      ranks = {
        [34914] = 5,
        [34916] = 5,
        [34917] = 5,
      }
    },
    ["Shadow Word: Pain"] = {
      type = spellTypes.debuff,
      ranks = {
        [589] = 6,
        [594] = 6,
        [970] = 6,
        [992] = 6,
        [2767] = 6,
        [10892] = 6,
        [10893] = 6,
        [10894] = 6,
        [25367] = 6,
        [25368] = 6,
      }
    },
    ["Devouring Plague"] = {
      type = spellTypes.debuff,
      ranks = {
        [2944] = 8,
        [19276] = 8,
        [19277] = 8,
        [19278] = 8,
        [19279] = 8,
        [19280] = 8,
        [25467] = 8,
      }
    },
    ["Starshards"] = {
      type = spellTypes.debuff,
      ranks = {
        [10797] = 5,
        [19296] = 5,
        [19299] = 5,
        [19302] = 5,
        [19303] = 5,
        [19304] = 5,
        [19305] = 5,
        [25446] = 5,
      }
    },
    ["Holy Fire"] = {
      type = spellTypes.debuff,
      ranks = {
        [14914] = 5,
        [15262] = 5,
        [15263] = 5,
        [15264] = 5,
        [15265] = 5,
        [15266] = 5,
        [15267] = 5,
        [15261] = 5,
        [25384] = 5,
      }
    },
  },
  ["WARLOCK"] = {
    ["Drain Soul"] = {
      type = spellTypes.channeled,
      ranks = {
        [1120] = 5,
        [8288] = 5,
        [8289] = 5,
        [11675] = 5,
        [27217] = 5,
      }
    },
    ["Drain Life"] = {
      type = spellTypes.channeled,
      ranks = {
        [689] = 5,
        [699] = 5,
        [709] = 5,
        [7651] = 5,
        [11699] = 5,
        [11700] = 5,
        [27219] = 5,
        [27220] = 5,
      }
    },
    ["Drain Mana"] = {
      type = spellTypes.channeled,
      ranks = {
        [5138] = 5,
        [6226] = 5,
        [11703] = 5,
        [11704] = 5,
        [27221] = 5,
        [30908] = 5,
      }
    },
    ["Health Funnel"] = {
      type = spellTypes.channeled,
      ranks = {
        [755] = 10,
        [3698] = 10,
        [3699] = 10,
        [3700] = 10,
        [11693] = 10,
        [11694] = 10,
        [11695] = 10,
        [27259] = 10,
      }
    },
    ["Hellfire"] = {
      type = spellTypes.channeled,
      ranks = {
        [1949] = 15,
        [11683] = 15,
        [11684] = 15,
        [27213] = 15,
      }
    },
    ["Immolate"] = {
      type = spellTypes.debuff,
      ranks = {
        [348] = 5,
        [707] = 5,
        [1094] = 5,
        [2941] = 5,
        [11665] = 5,
        [11667] = 5,
        [11668] = 5,
        [25309] = 5,
        [27215] = 5,
      }
    },
    ["Rain of Fire"] = {
      type = spellTypes.channeled,
      ranks = {
        [5740] = 4,
        [6219] = 4,
        [11677] = 4,
        [11678] = 4,
        [27212] = 4,
      }
    },
    ["Corruption"] = {
      type = spellTypes.debuff,
      ranks = {
        [172] = 4,
        [6222] = 5,
        [6223] = 6,
        [7648] = 6,
        [11671] = 6,
        [11672] = 6,
        [25311] = 6,
        [27216] = 6,
      }
    },
    ["Curse of Agony"] = {
      type = spellTypes.debuff,
      ranks = {
        [980] = 12,
        [1014] = 12,
        [6217] = 12,
        [11711] = 12,
        [11712] = 12,
        [11713] = 12,
        [27218] = 12,
      }
    },
    ["Unstable Affliction"] = {
      type = spellTypes.debuff,
      ranks = {
        [30108] = 6,
        [30404] = 6,
        [30405] = 6,
      }
    },
    ["Siphon Life"] = {
      type = spellTypes.debuff,
      ranks = {
        [18265] = 10,
        [18879] = 10,
        [18880] = 10,
        [18881] = 10,
        [27264] = 10,
        [30911] = 10,
      }
    },
  },
  ["DRUID"] = {
    ["Hurricane"] = {
      type = spellTypes.channeled,
      ranks = {
        [16914] = 10,
        [17401] = 10,
        [17402] = 10,
        [27012] = 10,
      },
    },
    ["Tranquility"] = {
      type = spellTypes.channeled,
      ranks = {
        [740] = 4,
        [8918] = 4,
        [9862] = 4,
        [9863] = 4,
        [26983] = 4,
      },
    },
    ["Moonfire"] = {
      type = spellTypes.debuff,
      ranks = {
        [8921] = 3,
        [8924] = 4,
        [8925] = 4,
        [8926] = 4,
        [8927] = 4,
        [8928] = 4,
        [8929] = 4,
        [9833] = 4,
        [9834] = 4,
        [9835] = 4,
        [26987] = 4,
        [26988] = 4,
      },
    },
    ["Insect Swarm"] = {
      type = spellTypes.debuff,
      ranks = {
        [5570] = 6,
        [24974] = 6,
        [24975] = 6,
        [24976] = 6,
        [24977] = 6,
        [27013] = 6,
      },
    },
    ["Rake"] = {
      type = spellTypes.debuff,
      ranks = {
        [1822] = 3,
        [1823] = 3,
        [1824] = 3,
        [9904] = 3,
        [27003] = 3,
      },
    },
    ["Rip"] = {
      type = spellTypes.finisherDebuff,
      ranks = {
        [1079] = { 6, 6, 6, 6, 6 },
        [9492] = { 6, 6, 6, 6, 6 },
        [9493] = { 6, 6, 6, 6, 6 },
        [9752] = { 6, 6, 6, 6, 6 },
        [9894] = { 6, 6, 6, 6, 6 },
        [9896] = { 6, 6, 6, 6, 6 },
        [27008] = { 6, 6, 6, 6, 6 },
      },
    },
  },
  ["MAGE"] = {
    ["Evocation"] = {
      type = spellTypes.channeled,
      ranks = {
        [12051] = 4,
      },
    },
    ["Blizzard"] = {
      type = spellTypes.channeled,
      ranks = {
        [10] = 8,
        [6141] = 8,
        [8427] = 8,
        [10185] = 8,
        [10186] = 8,
        [10187] = 8,
        [27085] = 8,
      },
    },
    ["Arcane Missiles"] = {
      type = spellTypes.channeled,
      ranks = {
        [5143] = 3,
        [5144] = 4,
        [5145] = 5,
        [8416] = 5,
        [8417] = 5,
        [10211] = 5,
        [10212] = 5,
        [25345] = 5,
        [27075] = 5,
        [38699] = 5,
        [38704] = 5,
      },
    },
  },
  ["SHAMAN"] = {
    ["Flame Shock"] = {
      type = spellTypes.debuff,
      ranks = {
        [8050] = 4,
        [8052] = 4,
        [8053] = 4,
        [10447] = 4,
        [10448] = 4,
        [29228] = 4,
        [25457] = 4,
      }
    }
  },
  ["ROGUE"] = {
    ["Garrote"] = {
      type = spellTypes.debuff,
      ranks = {
        [703] = 6,
        [8631] = 6,
        [8632] = 6,
        [8633] = 6,
        [11289] = 6,
        [11290] = 6,
        [26839] = 6,
        [26884] = 6,
      },
    },
    ["Rupture"] = {
      type = spellTypes.finisherDebuff,
      ranks = {
        [1943] = { 4, 5, 6, 7, 8 },
        [8639] = { 4, 5, 6, 7, 8 },
        [8640] = { 4, 5, 6, 7, 8 },
        [11273] = { 4, 5, 6, 7, 8 },
        [11274] = { 4, 5, 6, 7, 8 },
        [11275] = { 4, 5, 6, 7, 8 },
        [26867] = { 4, 5, 6, 7, 8 },
      },
    },
  },
  ["HUNTER"] = {
    type = spellTypes.channeled,
    ["Volley"] = {
      ranks = {
        [1510] = 6,
        [14294] = 6,
        [14295] = 6,
        [27022] = 6,
      },
    },
    ["Viper Sting"] = {
      type = spellTypes.debuff,
      oneYardTravelTime = 24.6576,
      ranks = {
        [3034] = 4,
        [14279] = 4,
        [14280] = 4,
        [27018] = 4,
      },
    },
    ["Serpent Sting"] = {
      type = spellTypes.debuff,
      oneYardTravelTime = 24.6576,
      ranks = {
        [1978] = 5,
        [13549] = 5,
        [13550] = 5,
        [13551] = 5,
        [13552] = 5,
        [13553] = 5,
        [13554] = 5,
        [13555] = 5,
        [25295] = 5,
        [27016] = 5,
      },
    },
  },
}

Context.spellTemplates = spellTemplates

if isTBC then
  Context.spellTemplates = tbcSpellTemplates
end

Context:InitSpells()
