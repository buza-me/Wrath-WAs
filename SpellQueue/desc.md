Delays your casts by temporarily freezing your game to prevent early channeled spell and DOT clips.  
Configurable in Custom Options.  
Works with 3.3.5 and 2.5.2 (TBC Classic) clients.  
Requires calibration for your computer, if you are using an old WOTLK or TBC client, not a recent classic client.  
Negative world ping offset is more cast delay.  
Positive world ping offset is less cast delay.  
"Absolute Offset" does nothing unless "Use World Ping Offset" is disabled.  
For example 40ms world ping and -10 offset is same as an Absolute Offset of 30.

Preferably test your settings while inside an instance. Some WA or addon that plays a sound on channeling spell tick can help with adjustment.

Use /run SQToggle() to toggle spell queue enabled on and off.  
Use /run SQCalibrate() to calibrate the freeze duration for your computer.  
Calibrate every time you enter a raid and when your processor speed changes, like a battery saver mode or overclock.

To use the spell queue, include this below #showtooltip, as second line of the spell macro:  
/run SQ(spell, unitID)  
unitID is optional.  
Unit id can be anything like "target" or "focus" or "pettarget" etc.

Mind Flay example with spell name (auto max rank):  
#showtooltip  
/run SQ("Mind Flay")  
/cast Mind Flay

Mind Flay example with spell name and specific rank:  
#showtooltip  
/run SQ("Mind Flay(Rank 9)")  
/cast Mind Flay(Rank 9)

Mind Flay example with spell ID:  
#showtooltip  
/run SQ(48156)  
/cast Mind Flay(Rank 9)

Devouring Plague example with spell name and focus as a tracked unit:  
#showtooltip  
/run SQ("Devouring Plague", "focus")  
/cast [target=focus] Devouring Plague

Reports spell queue delay amounts (in milliseconds) via WeakAuras.ScanEvents("SOLTI_SPELL_QUEUE_DELAY", delay)  
Reports spell queue max delay (ms) setting via WeakAuras.ScanEvents("SOLTI_SPELL_QUEUE_MAX_WAIT", val)

Supports all spell modifiers with glyphs and gear sets.

Supported spells:

**PRIEST:**

- Mind Flay
- Mind Sear
- Vampiric Touch
- Devouring Plague
- Shadow Word: Pain
- Holy Fire
- Hymn of Hope
- Divine Hymn
- Penance

**WARLOCK:**

- Drain Soul
- Drain Life
- Drain Mana
- Health Funnel
- Hellfire
- Immolate
- Rain of Fire
- Corruption
- Curse of Agony
- Unstable Affliction

**DRUID:**

- Hurricane
- Tranquility
- Moonfire
- Insect Swarm
- Rake
- Rip

**MAGE:**

- Evocation
- Blizzard
- Arcane Missiles
- Living Bomb

**SHAMAN:**

- Flame Shock

**ROGUE:**

- Garrote
- Rupture

**HUNTER:**

- Volley
- Viper Sting
- Serpent Sting

---

Made by Solti, Whitemane-Frostmourne.

Based on WA by Heaviside:  
https://wago.io/7AVcaIwn7  
Which is based on WA by Ducks:  
https://wago.io/Atm6dVYpK
