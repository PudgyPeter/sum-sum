# Anime Tower Defense - Comprehensive Feature Plan

Exhaustive feature plan covering all aspects of a successful anime tower defense game, based on research from ASTD X, Anime Adventures, Tower Defense Simulator, gacha game best practices, and industry standards.

---

## Table of Contents
1. [Core Unit Systems](#part-1-core-unit-systems)
2. [Gacha & Summoning](#part-2-gacha--summoning-systems)
3. [Progression Systems](#part-3-progression-systems)
4. [Game Modes](#part-4-game-modes)
5. [Social Features](#part-5-social-features)
6. [Economy & Trading](#part-6-economy--trading)
7. [Events & Limited Content](#part-7-events--limited-content)
8. [Monetization](#part-8-monetization)
9. [Quality of Life](#part-9-quality-of-life)
10. [Audio & Visual Polish](#part-10-audio--visual-polish)
11. [Technical & Backend](#part-11-technical--backend)
12. [Code Refactoring](#part-12-code-refactoring)

---

## Part 1: Core Unit Systems

### 1.1 Color Type System ⭐
**Source:** Dragon Ball Legends, ASTD X

| Color | Strong Against | Weak Against | RGB Value |
|-------|---------------|--------------|-----------|
| RED | YEL | BLU | (255, 50, 50) |
| YEL | PUR | RED | (255, 220, 50) |
| PUR | GRN | YEL | (180, 80, 255) |
| GRN | BLU | PUR | (80, 220, 80) |
| BLU | RED | GRN | (80, 150, 255) |
| LIGHT | DARK | DARK | (255, 255, 200) |
| DARK | LIGHT | LIGHT | (60, 40, 80) |

**Damage Multipliers:**
- Type Advantage: 1.3x (30% bonus)
- Type Disadvantage: 0.7x (30% penalty)
- Neutral: 1.0x

---

### 1.2 Unit Tags System ⭐
**Source:** Dragon Ball Legends Z-Abilities

**Tag Categories:**
```
ANIME SERIES:     #OnePiece, #Naruto, #DragonBall, #Bleach, #JJK, #DemonSlayer, #AOT, #MHA
FACTION:          #StrawHat, #Akatsuki, #Saiyan, #Marine, #SoulReaper, #Hashira, #Survey Corps
ROLE:             #Captain, #Swordsman, #Support, #Tank, #Assassin, #Healer, #Buffer
COMBAT STYLE:     #Melee, #Ranged, #Magic, #Brawler, #AOE, #SingleTarget
SPECIAL:          #Legendary, #Villain, #Hero, #Awakened, #Limited
```

**Tag Interactions:**
1. **Map Buffs** - Maps buff specific tags (Grand Line → #OnePiece +20% damage)
2. **Team Synergies** - 3+ matching tags = team bonus
3. **Challenge Restrictions** - "Complete with only #Swordsman units"

---

### 1.3 Unit Evolution & XP Progression ⭐
**Source:** User-specified, anime power scaling

**Evolution Chain Example (Luffy):**
| Stage | Name | XP Required | Stat Multi | New Features |
|-------|------|-------------|------------|--------------|
| 0 | East Blue Luffy | - | 1.0x | 3 base paths (Pistol/Bazooka/Gatling) |
| 1 | Gear 2 Luffy | 1,000 | 1.25x | Jet versions of paths |
| 2 | Haki Luffy | 5,000 | 1.5x | Conqueror's Haki ability |
| 3 | Gear 4 Luffy | 15,000 | 2.0x | Boundman/Tankman/Snakeman sub-paths |
| 4 | Gear 5 Nika | Trial | 3.0x | Reality-bending abilities, passive aura |

**XP Gain Methods:**
- Per mob killed: +1 XP
- Per boss killed: +10 XP
- Per wave completed: +50 XP
- Per act completed: +500 XP
- First clear bonus: 2x XP

---

### 1.4 Unit Upgrade Paths
**Current System:** A/B/C paths with 6 tiers each + Paragon

**Enhanced System:**
- **Path Unlocking:** Evolution unlocks new paths or enhances existing ones
- **Path Branching:** At tier 3, choose specialization within path
- **Cross-Path Bonuses:** Certain path combinations grant hidden bonuses
- **Visual Upgrades:** Model changes at tier 3 and 6 of each path

---

### 1.5 Active Abilities
**Source:** ASTD, Anime Adventures

**Ability Types:**
| Type | Example | Cooldown | Effect |
|------|---------|----------|--------|
| Damage | King Kong Gun | 60s | 10x damage to single target |
| AoE | Conqueror's Haki | 45s | Stun all mobs in range 3s |
| Buff | Gear 2 Activation | 30s | 2x attack speed for 10s |
| Utility | Instant Transmission | 20s | Teleport to any tower position |
| Summon | Shadow Clone | 40s | Spawn 3 temporary attacking clones |

**Unlock Conditions:**
- Rarity-based (Mythic units have abilities by default)
- Evolution-based (unlocked at specific evolution stages)
- Trial completion (special abilities from challenges)

---

### 1.6 Passive Abilities
**Source:** Universal Tower Defense

**Passive Types:**
- **Aura:** Buff nearby allies (Drums of Liberation: +20% attack speed)
- **On-Kill:** Trigger effect when killing mobs (Gain +5 cash per kill)
- **On-Hit:** Chance to trigger effect (10% chance to apply burn)
- **Threshold:** Activate when conditions met (Below 50% HP: +50% damage)
- **Stacking:** Build up power over time (Each attack +1% damage, max 50%)

---

### 1.7 Unit Traits System
**Source:** Universal Tower Defense

**Trait Categories:**
```lua
Traits = {
    -- Offensive
    "Berserker",     -- +30% damage, -20% defense
    "Precision",     -- +15% crit chance
    "Relentless",    -- Attacks ignore 20% armor
    
    -- Defensive  
    "Fortified",     -- +25% HP
    "Regeneration",  -- Heal 1% HP per second
    
    -- Utility
    "Economy",       -- +10% cash from kills
    "Swift",         -- +15% attack speed
    "Far Sight",     -- +20% range
}
```

**Trait Acquisition:**
- Random on summon (1-3 traits based on rarity)
- Reroll with special currency
- Inherit from evolution

---

### 1.8 Relic/Equipment System
**Source:** Universal Tower Defense

**Relic Slots:** 4 per unit (Weapon, Armor, Accessory, Artifact)

**Set Bonuses:**
| Set | 2-Piece | 4-Piece |
|-----|---------|---------|
| Warrior | +15% damage | +30% damage, ignore 10% armor |
| Guardian | +20% HP | +40% HP, reflect 5% damage |
| Swift | +10% attack speed | +25% attack speed, chance for double attack |
| Vampire | +5% lifesteal | +15% lifesteal, heal allies on kill |

**Relic Rarities:** Common → Rare → Epic → Legendary → Mythic

**Relic Stats:**
- Main Stat: Damage, HP, Attack Speed, Range, Crit Chance, Crit Damage
- Sub Stats: 1-4 random substats based on rarity

---

## Part 2: Gacha & Summoning Systems

### 2.1 Banner Types
**Source:** Genshin Impact, ASTD X

| Banner Type | Description | Rotation |
|-------------|-------------|----------|
| **Standard** | All non-limited units | Permanent |
| **Featured** | Rate-up for specific unit | 2-week rotation |
| **Limited** | Exclusive units (collabs, events) | Event duration only |
| **Beginner** | Discounted, guaranteed starter | One-time per account |
| **Step-Up** | Escalating rewards per multi | Monthly reset |

---

### 2.2 Pity System
**Current:** 50 Legendary pity, 100 Mythic pity

**Enhanced System:**
```lua
PitySystem = {
    -- Soft Pity (increased rates)
    SoftPityStart = {
        Legendary = 40,  -- Rates increase after 40 pulls
        Mythic = 75,     -- Rates increase after 75 pulls
    },
    
    -- Hard Pity (guaranteed)
    HardPity = {
        Legendary = 50,
        Mythic = 100,
    },
    
    -- 50/50 System
    Featured5050 = true,  -- 50% featured, 50% standard
    GuaranteedFeatured = true,  -- After losing 50/50, next is guaranteed
    
    -- Pity Carryover
    CarryOverBetweenBanners = true,  -- Same banner type shares pity
}
```

---

### 2.3 Summon Costs & Rates
**Current:** 50 gems single, 450 gems multi (10 pulls)

**Rates:**
| Rarity | Base Rate | Soft Pity Rate |
|--------|-----------|----------------|
| Common | 45% | - |
| Uncommon | 30% | - |
| Rare | 15% | - |
| Epic | 7% | - |
| Legendary | 2.5% | 5% |
| Mythic | 0.5% | 2% |

---

### 2.4 Beginner Banner
**Source:** Genshin Impact Noelle Banner

**Features:**
- 20% discount (40 gems per pull instead of 50)
- Limited to 20 pulls total
- Guaranteed Legendary at pull 10
- Guaranteed unit selection at pull 20 (choose from 3 options)
- One-time per account

---

### 2.5 Step-Up Banner
**Source:** Dragon Ball Legends

**Structure:**
| Step | Cost | Bonus |
|------|------|-------|
| 1 | 300 gems | Guaranteed Rare+ |
| 2 | 400 gems | 2x Legendary rate |
| 3 | 450 gems | Guaranteed Epic+ |
| 4 | 450 gems | 3x Mythic rate |
| 5 | 500 gems | Guaranteed Featured Legendary |
| 6 | FREE | Guaranteed Featured unit (Legendary/Mythic) |

Resets monthly or per banner.

---

### 2.6 Spark/Token System
**Source:** Granblue Fantasy, Limbus Company

**Concept:** Every pull grants 1 Spark Token. At 200-300 tokens, exchange for any featured unit guaranteed.

**Benefits:**
- Removes "never getting the unit" frustration
- Whales can target specific units
- F2P can save for guaranteed

---

## Part 3: Progression Systems

### 3.1 Account/Player Level
**Features:**
- XP from all activities
- Unlocks features at milestones:
  - Level 5: Trading unlocked
  - Level 10: Infinite Mode unlocked
  - Level 15: Raids unlocked
  - Level 20: Skill Tree unlocked
  - Level 25: Trials unlocked
  - Level 30: Prestige available

---

### 3.2 Skill Tree System
**Source:** Tower Defense Simulator

**Categories:**
```lua
SkillTree = {
    Combat = {
        "DamageBoost",      -- +1% damage per level (max 40)
        "CritMaster",       -- +0.5% crit chance per level (max 20)
        "ArmorPierce",      -- +1% armor ignore per level (max 30)
    },
    Economy = {
        "GoldRush",         -- +2% cash from kills per level (max 25)
        "StartingBonus",    -- +50 starting cash per level (max 20)
        "SellValue",        -- +1% tower sell value per level (max 15)
    },
    Utility = {
        "TowerLimit",       -- +1 max towers per level (max 5)
        "CooldownReduce",   -- -1% ability cooldown per level (max 30)
        "RangeBoost",       -- +1% range per level (max 20)
    },
}
```

**Skill Points:** Earned from leveling, achievements, and events

---

### 3.3 Prestige/Rebirth System
**Source:** Idle games, incremental games

**Concept:** Reset progress for permanent multipliers

**Prestige Rewards:**
- +5% base damage per prestige
- +5% XP gain per prestige
- Exclusive prestige-only units
- Cosmetic titles and badges

**Requirements:**
- Complete all story content
- Reach account level 30+
- Choose to reset (keeps: units, gems, prestige rewards)

---

### 3.4 Achievement System
**Categories:**
```lua
Achievements = {
    -- Combat
    "First Blood",           -- Kill 1 mob (50 gems)
    "Mob Slayer",           -- Kill 10,000 mobs (500 gems)
    "Boss Hunter",          -- Defeat 100 bosses (300 gems)
    
    -- Collection
    "Collector",            -- Own 25 unique units (200 gems)
    "Completionist",        -- Own all units (exclusive title)
    "Evolution Master",     -- Max evolve 10 units (1000 gems)
    
    -- Progression
    "Story Complete",       -- Beat all acts (exclusive unit)
    "Infinite Warrior",     -- Reach wave 100 in Infinite (500 gems)
    "Speed Runner",         -- Beat Act 1 in under 5 minutes (200 gems)
    
    -- Social
    "Party Animal",         -- Complete 50 co-op games (300 gems)
    "Helpful Friend",       -- Help 10 friends beat content (200 gems)
    "Guild Champion",       -- Win 20 guild battles (500 gems)
}
```

---

### 3.5 Daily Login Rewards
**Source:** All successful gacha games

**7-Day Rotation:**
| Day | Free Track | Premium Track |
|-----|------------|---------------|
| 1 | 50 gems | 100 gems |
| 2 | 10,000 gold | 25,000 gold |
| 3 | 5 skill orbs | 15 skill orbs |
| 4 | 100 gems | 200 gems |
| 5 | Random Rare unit | Random Epic unit |
| 6 | 200 gems | 400 gems |
| 7 | Summon Ticket | Premium Ticket (guaranteed Epic+) |

**Streak Bonuses:**
- 14-day streak: Legendary Ticket
- 30-day streak: Mythic Ticket
- Streak breaks: Lose bonus, keep base rewards

---

### 3.6 Daily/Weekly Missions
**Source:** Hearthstone, mobile games

**Daily Missions (3 per day):**
- Complete 3 matches (100 gems)
- Kill 500 mobs (50 gems)
- Use 5 different units (75 gems)
- Win without losing lives (150 gems)

**Weekly Missions:**
- Complete 20 matches (500 gems)
- Evolve a unit (300 gems)
- Complete an Infinite run (400 gems)
- Trade with another player (200 gems)

---

### 3.7 Battle Pass / Season Pass
**Source:** Fortnite, Roblox Bedwars

**Structure:**
- 50 tiers per season (8 weeks)
- Free track: Basic rewards every 5 tiers
- Premium track (500 Robux): Exclusive rewards every tier

**Tier Rewards:**
| Tier | Free | Premium |
|------|------|---------|
| 1-10 | Gems, Gold | + Exclusive skin |
| 11-25 | Tickets, Orbs | + Evolution materials |
| 26-40 | Rare unit | + Legendary unit |
| 41-49 | More gems | + Exclusive relic set |
| 50 | Title | + Limited Mythic unit |

---

## Part 4: Game Modes

### 4.1 Story Mode (Current)
**Structure:** Maps → Acts → Waves

**Enhancements:**
- **Difficulty Tiers:** Easy, Normal, Hard, Nightmare
- **Star Rating:** 1-3 stars based on performance
- **First Clear Bonus:** 2x rewards on initial completion
- **Challenge Conditions:** Complete with specific restrictions for bonus rewards

---

### 4.2 Infinite/Endless Mode
**Source:** Anime Adventures

**Features:**
- Unlocked after completing map's story
- Endless waves with scaling difficulty
- Wave milestones with bonus rewards (25, 50, 100, etc.)
- Leaderboard for highest wave reached
- Unique rewards only from Infinite mode

**Scaling:**
- +5% mob HP per wave
- +3% mob speed per wave
- Boss every 10 waves
- Elite mobs start appearing at wave 25

---

### 4.3 Raids
**Source:** Anime Adventures, MMORPGs

**Concept:** 4-8 player co-op against mega-boss

**Features:**
- Weekly rotation of raid bosses
- Boss has multiple phases with unique mechanics
- Requires coordination (tank, DPS, support roles)
- Exclusive raid-only unit drops
- Difficulty tiers with better rewards

**Example Raid Boss:**
```
KAIDO - Dragon Form
Phase 1: Standard attacks, targetable
Phase 2: Flying phase, ranged only can hit
Phase 3: Enraged, 2x damage, must burst
Mechanic: Thunder Bagua - kills random tower if not stunned
```

---

### 4.4 Trials / Challenge Mode
**Source:** ASTD X

**Types:**
1. **Evolution Trials** - Complete to unlock final evolution
2. **Unit Trials** - Use specific unit to unlock cosmetic
3. **Restriction Trials** - Complete with limitations
4. **Time Trials** - Beat under time limit
5. **No-Damage Trials** - Win without losing base HP

**Rewards:**
- Evolution materials
- Exclusive abilities
- Titles and badges
- Gems and premium currency

---

### 4.5 PvP Mode
**Source:** Tower Defense Simulator

**Types:**
1. **1v1 Competitive** - Send mobs at opponent while defending
2. **2v2 Team Battle** - Co-op vs co-op
3. **Tournament** - Bracket-style elimination

**Ranked System:**
- Bronze → Silver → Gold → Platinum → Diamond → Master → Legend
- Season resets with rewards based on rank
- Exclusive ranked rewards (skins, titles)

---

### 4.6 Guild Wars
**Source:** Mobile MMOs

**Features:**
- Guilds compete weekly
- Guild boss with combined damage leaderboard
- Territory control mini-game
- Guild-exclusive shops and rewards

---

### 4.7 Tower/Abyss Mode
**Source:** Genshin Spiral Abyss

**Structure:**
- 12 floors, 3 chambers each
- Increasingly difficult with modifiers
- Resets bi-weekly
- Top floors give premium currency

---

## Part 5: Social Features

### 5.1 Guild/Clan System
**Features:**
```lua
GuildSystem = {
    MaxMembers = 50,
    Ranks = {"Leader", "Officer", "Elite", "Member", "Recruit"},
    
    GuildPerks = {
        "XPBoost",          -- +10% XP for all members
        "GemBonus",         -- +5% gems from all sources
        "ShopDiscount",     -- -10% guild shop prices
    },
    
    GuildActivities = {
        "GuildBoss",        -- Weekly cooperative boss
        "GuildWar",         -- Compete against other guilds
        "GuildMissions",    -- Cooperative objectives
    },
    
    GuildShop = {
        -- Buy with Guild Coins earned from activities
        "ExclusiveUnits",
        "EvolutionMaterials",
        "Relics",
    },
}
```

---

### 5.2 Friends System
**Features:**
- Add friends via username or code
- See friends' online status
- View friends' showcase units
- Send/receive daily gifts (5 per day)
- Co-op matchmaking priority

---

### 5.3 Friend Referral System
**Source:** Roblox native feature

**Rewards:**
- Inviter: 100 gems per friend who reaches level 10
- Invitee: Bonus starter pack
- Both: Exclusive "Friends Forever" title at 5 referrals

---

### 5.4 Global Chat
**Features:**
- World chat (all players)
- Guild chat
- Party chat
- Trade chat channel
- Moderation and filters

---

### 5.5 Player Profiles
**Displayable:**
- Account level and prestige
- Favorite/showcase units (3 slots)
- Achievement badges
- Play statistics
- Ranked tier

---

## Part 6: Economy & Trading

### 6.1 Currencies
| Currency | Source | Use |
|----------|--------|-----|
| **Gold** | Gameplay | Deploy/upgrade towers in-match |
| **Gems** | Quests, achievements, purchase | Summoning, shop |
| **Tickets** | Events, login | Guaranteed rarity summons |
| **Guild Coins** | Guild activities | Guild shop |
| **PvP Tokens** | Ranked matches | PvP shop |
| **Event Tokens** | Limited events | Event shop |

---

### 6.2 Trading System
**Source:** Anime Adventures, Toilet Tower Defense

**Features:**
- Player-to-player unit trading
- Trade request system with confirmation
- Trade history log
- Scam prevention (value warnings)
- Trade chat channel

**Restrictions:**
- Account level 5+ required
- Cannot trade limited/exclusive units (optional)
- 24-hour cooldown on traded units

---

### 6.3 Marketplace/Auction House
**Source:** Toilet Tower Defense

**Features:**
- List units for sale (gems or gold)
- Browse listings with filters
- Auction mode (bid system)
- Instant buy option
- Tax on sales (10% goes to sink)

---

### 6.4 Unit Value System
**Factors:**
- Base rarity
- Evolution level
- Traits quality
- Limited availability
- Meta relevance

---

## Part 7: Events & Limited Content

### 7.1 Seasonal Events
**Schedule:**
- **Spring:** Cherry Blossom event (anime-themed)
- **Summer:** Beach/vacation event
- **Fall:** Halloween event (spooky units)
- **Winter:** Christmas/New Year event

**Event Features:**
- Limited-time maps
- Event currency and shop
- Exclusive event units
- Cosmetics and decorations

---

### 7.2 Collaboration Events
**Source:** All gacha games

**Potential Collabs:**
- Other Roblox games
- Anime anniversaries
- Creator partnerships

**Collab Features:**
- Limited banner with collab units
- Themed map
- Exclusive cosmetics
- Usually never return (FOMO)

---

### 7.3 Anniversary Events
**Features:**
- Free multi-summon daily
- Returning limited units
- Anniversary-exclusive unit
- Gem giveaways
- Community goals with global rewards

---

### 7.4 Weekly Rotating Content
- **Monday:** Double XP
- **Tuesday:** Raid reset
- **Wednesday:** New weekly missions
- **Thursday:** Trial rotation
- **Friday:** Featured banner change
- **Weekend:** Special event missions

---

### 7.5 Promotional Codes
**Source:** All Roblox games

**Uses:**
- YouTube/streamer partnerships
- Social media milestones
- Bug compensation
- Holiday giveaways

**Implementation:**
- In-game code redemption UI
- Expiration dates
- One-time use per account

---

## Part 8: Monetization

### 8.1 Game Passes (One-Time Purchase)
| Pass | Price | Benefit |
|------|-------|---------|
| VIP | 499 R$ | +25% gems, exclusive badge, VIP chat |
| Auto-Start | 99 R$ | Auto-start waves toggle |
| 2x XP | 199 R$ | Permanent 2x unit XP |
| Extra Loadout | 149 R$ | +1 loadout slot |
| Premium Storage | 249 R$ | +50 inventory slots |
| Damage Stats | 99 R$ | Detailed damage breakdown |

---

### 8.2 Developer Products (Repeatable)
| Product | Price | Gives |
|---------|-------|-------|
| 100 Gems | 49 R$ | 100 gems |
| 500 Gems | 199 R$ | 500 gems (+100 bonus) |
| 1000 Gems | 399 R$ | 1000 gems (+300 bonus) |
| Summon Ticket | 79 R$ | 1 guaranteed Epic+ pull |
| Evolution Pack | 149 R$ | Evolution materials bundle |

---

### 8.3 Battle Pass
- Free track available to all
- Premium track: 500 R$ per season
- Exclusive cosmetics and units

---

### 8.4 Private/VIP Servers
**Price:** 100 R$/month

**Benefits:**
- Play with friends only
- +10% rewards
- Custom game settings
- No random matchmaking

---

### 8.5 Subscription Model
**Monthly Pass (299 R$/month):**
- Daily gems (30 per day = 900/month)
- Premium login track
- -10% shop prices
- Exclusive subscriber badge

---

## Part 9: Quality of Life

### 9.1 Gameplay QoL
- [ ] Auto-wave toggle
- [ ] Speed controls (1x, 2x, 3x)
- [ ] Tower range preview before placement
- [ ] Undo placement (5-second window)
- [ ] Quick-upgrade hotkeys
- [ ] Target priority presets (save/load)
- [ ] Skip wave with bonus rewards

---

### 9.2 UI/UX Improvements
- [ ] Damage numbers display
- [ ] Health bars on mobs
- [ ] Wave preview panel
- [ ] Mini-map with mob positions
- [ ] Tower stat comparison
- [ ] Relic comparison overlay
- [ ] Search/filter in inventory
- [ ] Sort by multiple criteria

---

### 9.3 Inventory Management
- [ ] Bulk sell units
- [ ] Lock/favorite units
- [ ] Preset loadouts (save multiple)
- [ ] Quick-equip best relics
- [ ] Inventory expansion

---

### 9.4 Information Systems
- [ ] In-game wiki/codex
- [ ] Unit tier list (community-voted)
- [ ] Damage calculator
- [ ] Synergy checker
- [ ] Meta team recommendations

---

### 9.5 Accessibility
- [ ] Colorblind modes
- [ ] Screen reader support
- [ ] Adjustable UI scale
- [ ] Subtitles for audio
- [ ] Reduced motion option

---

## Part 10: Audio & Visual Polish

### 10.1 Audio Features
- [ ] Unique attack sounds per unit
- [ ] Voice lines on placement/ability
- [ ] Dynamic music (intensity scales with wave)
- [ ] Boss theme music
- [ ] Victory/defeat jingles
- [ ] UI sound effects

---

### 10.2 Visual Effects
- [ ] Ability VFX (ultimate moves)
- [ ] Critical hit effects
- [ ] Status effect indicators
- [ ] Evolution transformation animation
- [ ] Summon animation (gacha pull)
- [ ] Victory celebration effects

---

### 10.3 Cosmetics System
**Types:**
- Unit skins (visual variants)
- Tower pedestals/platforms
- Attack effect recolors
- Name colors/fonts
- Profile banners
- Emotes/reactions

**Acquisition:**
- Battle pass rewards
- Event exclusives
- Shop purchase
- Achievement unlocks

---

## Part 11: Technical & Backend

### 11.1 Data Management
- [ ] Cloud save with versioning
- [ ] Data migration system
- [ ] Backup/restore functionality
- [ ] Cross-device sync (if applicable)

---

### 11.2 Anti-Cheat
- [ ] Server-side validation
- [ ] Damage calculation verification
- [ ] Currency transaction logs
- [ ] Suspicious activity detection
- [ ] Ban system with appeals

---

### 11.3 Analytics
- [ ] Player retention metrics
- [ ] Popular units tracking
- [ ] Drop-off points identification
- [ ] Economy balance monitoring
- [ ] Feature engagement stats

---

### 11.4 Performance
- [ ] LOD system for units
- [ ] Mob pooling/recycling
- [ ] Network optimization
- [ ] Memory management
- [ ] Loading time reduction

---

## Part 12: Code Refactoring

### 12.1 Critical Priority
1. **Consolidate duplicate files** between lobby and maps
   - PlayerDataManager.lua (727 vs 916 lines)
   - GameConfig.lua (76 vs 167 lines)
   - DataStoreManager.lua

2. **Split Tower.lua** (~1000 lines) into:
   - TowerCore.lua (spawn, placement, selling)
   - TowerCombat.lua (attack, targeting, DPS)
   - TowerUpgrades.lua (upgrades, paragon, model swap)
   - TowerAbilities.lua (active/passive abilities)

### 12.2 Medium Priority
3. **Data-driven wave system** - Move Round.lua definitions to WaveData.lua
4. **Modernize async** - Replace `spawn()` with `task.spawn()`
5. **Centralize constants** - All magic numbers to GameConfig

### 12.3 Lower Priority
6. **Instance batching** - Optimize PlayerDataManager.SetupPlayer()
7. **Module organization** - Consistent folder structure
8. **Documentation** - Add code comments and type annotations

---

## Implementation Phases

### Phase 1: Foundation (2-3 weeks)
- Code refactoring (12.1, 12.2)
- Color Type System
- Unit Tags System
- Basic Evolution System

### Phase 2: Core Features (4-6 weeks)
- Enhanced summoning/pity
- Active/Passive abilities
- Skill Tree
- Achievement System

### Phase 3: Content (4-6 weeks)
- Infinite Mode
- Raids
- Trials
- Daily/Weekly missions
- Battle Pass

### Phase 4: Social (2-3 weeks)
- Trading System
- Guild System
- Friends enhancements
- Leaderboards

### Phase 5: Polish (Ongoing)
- Audio/Visual effects
- QoL improvements
- Events system
- Monetization refinement

---

## Feature Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Color System | High | Low | ⭐⭐⭐ |
| Tags System | High | Medium | ⭐⭐⭐ |
| Evolution System | Very High | High | ⭐⭐⭐ |
| Pity Improvements | High | Low | ⭐⭐⭐ |
| Infinite Mode | High | Medium | ⭐⭐ |
| Skill Tree | Medium | Medium | ⭐⭐ |
| Trading | Medium | Medium | ⭐⭐ |
| Raids | High | High | ⭐⭐ |
| Battle Pass | High | Medium | ⭐⭐ |
| PvP | Medium | Very High | ⭐ |
| Guild System | Medium | High | ⭐ |

---

Review this plan and let me know which features you want to keep, modify, or remove.

---

## Part 13: Bloons TD 6 Inspired Features

### 13.1 Monkey Knowledge / Account-Wide Skill Tree
**Source:** BTD6 Monkey Knowledge

**Concept:** Permanent account-wide upgrades that persist across all games.

**Skill Trees (6 categories):**
```lua
MonkeyKnowledge = {
    -- Primary (Basic units)
    Primary = {
        "DartTraining",      -- +1 pierce for all primary
        "BiggerBlast",       -- +10% explosion radius
        "MilitaryConscript", -- -5% primary unit cost
    },
    
    -- Military (Ranged/special units)
    Military = {
        "AdvancedLogistics", -- -5% military cost
        "FasterFiring",      -- +5% attack speed
        "BiggerAmmo",        -- +15% range for snipers
    },
    
    -- Magic (Ability users)
    Magic = {
        "ManaSurge",         -- +10% ability damage
        "CooldownReduction", -- -5% ability cooldowns
        "MagicTricks",       -- Start with +50 starting cash
    },
    
    -- Support (Buffers/economy)
    Support = {
        "BetterSellDeals",   -- +5% sell value
        "MoreCash",          -- +$50 starting cash
        "VeteranSupport",    -- Support units buff +5% stronger
    },
    
    -- Heroes (Special characters)
    Heroes = {
        "SelfTaught",        -- Heroes gain XP 10% faster
        "WeakPoint",         -- Heroes deal +1 damage to bosses
        "BiggerRadii",       -- +5% hero ability range
    },
    
    -- Powers (Consumables/global)
    Powers = {
        "MoreStartingCash",  -- +$200 starting cash
        "FreeRoadSpikes",    -- 1 free trap per game
        "BiggerPowerBoosts", -- +10% power effectiveness
    },
}
```

**Unlock System:**
- Earn Knowledge Points from leveling up
- Spend Monkey Money (soft currency) to unlock
- Prerequisites within each tree

---

### 13.2 Paragon System (Enhanced)
**Source:** BTD6 Paragons

**Concept:** Ultimate tower form created by sacrificing/combining multiple towers.

**Requirements:**
- Have 3 max-tier towers of same type placed
- Sacrifice them + spend large gold amount
- Paragon "degree" based on total power sacrificed

**Paragon Degrees (1-100):**
```lua
ParagonDegree = {
    -- Factors affecting degree:
    TotalUpgradesCost = weight * 0.3,    -- Gold spent on sacrificed towers
    TotalPops = weight * 0.2,            -- Kills by sacrificed towers
    TotalTowers = weight * 0.2,          -- Number of towers sacrificed
    HighestTier = weight * 0.3,          -- Highest tier among sacrifices
    
    -- Degree bonuses:
    DamagePerDegree = 1.01,  -- +1% damage per degree
    SpeedPerDegree = 1.005,  -- +0.5% speed per degree
    RangePerDegree = 1.002,  -- +0.2% range per degree
}
```

**Paragon Abilities:**
- Unique ultimate ability only Paragons have
- Passive aura buffing nearby towers
- Special attack that hits all enemies on screen

---

### 13.3 Hero System
**Source:** BTD6 Heroes

**Concept:** One special "hero" unit per player that levels up during the match.

**Hero Features:**
- Only 1 hero allowed per player per game
- Auto-levels during gameplay (XP from pops)
- Unlocks abilities at specific levels (3, 7, 10, 15, 20)
- Account-level XP also increases hero starting level

**Hero Abilities (Example - "Commander"):**
| Level | Unlock |
|-------|--------|
| 1 | Basic attack |
| 3 | Ability 1: Rally Cry (+15% damage nearby for 10s) |
| 7 | Enhanced basic attack |
| 10 | Ability 2: Airstrike (heavy damage in area) |
| 15 | Passive: Nearby towers +5% range |
| 20 | Ability 3: Ultimate Command (all towers 2x speed for 15s) |

**Hero Skins:**
- Cosmetic variants purchasable
- Some skins from events only

---

### 13.4 Odyssey Mode
**Source:** BTD6 Odyssey

**Concept:** Weekly voyage across multiple maps with limited "crew."

**Structure:**
- 3-5 maps in sequence
- Limited tower roster (choose 8-10 towers for entire voyage)
- Towers persist HP/cooldowns between maps
- Increasing difficulty per map
- Weekly rotation with different restrictions

**Odyssey Difficulties:**
| Difficulty | Maps | Reward |
|------------|------|--------|
| Easy | 3 | 500 gems |
| Medium | 4 | 1000 gems + trophy |
| Hard | 5 | 2000 gems + exclusive reward |

**Restrictions Examples:**
- "No support towers"
- "Only melee units"
- "Max 2 of each tower type"

---

### 13.5 Boss Bloon Events / Boss Rush
**Source:** BTD6 Boss Events

**Concept:** Weekly rotating boss with competitive leaderboard.

**Boss Mechanics:**
- Appears at specific waves (20, 40, 60, 80, 100)
- Each appearance = higher tier (Tier 1-5)
- Boss has skull phases (damage thresholds)
- Special mechanics per boss type

**Boss Types:**
| Boss | Mechanic |
|------|----------|
| Bloonarius | Spawns bloon children when damaged |
| Lych | Heals from tower sells, steals buffs |
| Vortex | Creates speed zones, teleports |
| Dreadbloon | Rock armor, underground phases |
| Phayze | Phase shifts, immune during transition |

**Leaderboards:**
- Ranked by time to defeat all tiers
- Normal and Elite difficulties
- Weekly reset with rewards

---

### 13.6 Contested Territory / Guild Wars
**Source:** BTD6 Contested Territory

**Concept:** Team-based tile capture on hexagonal map.

**Structure:**
- 6 teams compete on shared hex board
- Capture tiles by completing challenges
- Tiles have different point values
- Banner tiles = bonus effects for team
- Event lasts ~1 week

**Tile Types:**
| Tile | Effect |
|------|--------|
| Regular | Points only |
| Relic | Bonus modifier for team |
| Banner | Major team buff |
| Boss | High points, requires boss kill |

**Team Contribution:**
- Individual captures contribute to team score
- Top contributors get bonus rewards
- Team placement determines final rewards

---

### 13.7 Races / Speedrun Mode
**Source:** BTD6 Races

**Concept:** Competitive time-attack challenges.

**Features:**
- Same map/rules for all players
- Leaderboard by completion time
- Limited attempts (or unlimited with penalty)
- Rewards for top percentile placements

**Race Modifiers:**
- Restricted tower types
- Modified starting cash
- Different wave compositions
- Special rules (e.g., "no abilities")

---

### 13.8 Collection Events
**Source:** BTD6 Collection Events

**Concept:** Limited-time collectible gathering.

**Structure:**
- Collectibles spawn on maps during event
- Collect X items for milestone rewards
- Bonus collectibles from harder difficulties
- Event shop with exclusive items

**Reward Tiers:**
| Collected | Reward |
|-----------|--------|
| 50 | 100 gems |
| 150 | Rare unit |
| 300 | Exclusive skin |
| 500 | Event-only unit |

---

### 13.9 Trophy Store / Cosmetic Shop
**Source:** BTD6 Trophy Store

**Concept:** Earn trophies from events, spend on cosmetics.

**Cosmetic Categories:**
- Tower skins (visual changes)
- Attack effects (projectile colors)
- Placement effects (spawn animations)
- Map themes (visual overlays)
- Profile icons and banners
- Music packs

**Trophy Earning:**
- Events completion
- Achievement unlocks
- Seasonal rewards
- Special challenges

---

### 13.10 Sandbox Mode
**Source:** BTD6 Sandbox

**Concept:** Unrestricted testing environment.

**Features:**
- Unlimited cash
- Spawn any mob type/quantity
- Test tower combinations
- No rewards (practice only)
- Available after completing story

---

## Part 14: Arknights Inspired Features

### 14.1 Deployment Point (DP) System
**Source:** Arknights

**Concept:** Resource management for tower deployment.

**Mechanics:**
- Start with base DP (e.g., 10)
- DP regenerates over time (1 per second)
- Each tower costs DP to deploy
- Higher rarity = higher DP cost
- Some towers generate bonus DP

**DP Costs by Rarity:**
| Rarity | DP Cost |
|--------|---------|
| Common | 5-8 |
| Rare | 10-15 |
| Epic | 15-20 |
| Legendary | 20-30 |
| Mythic | 25-40 |

**DP Generators:**
- Specific support units that generate +1 DP/sec when deployed
- Trade-off: Weaker combat stats

---

### 14.2 Operator Classes & Archetypes
**Source:** Arknights

**Concept:** Distinct classes with placement restrictions.

**Classes:**
| Class | Placement | Role |
|-------|-----------|------|
| Vanguard | Ground | Early DP generation, weak stats |
| Guard | Ground | Melee DPS, various subtypes |
| Defender | Ground | Tank, block multiple enemies |
| Sniper | Elevated | Ranged DPS, priority targeting |
| Caster | Elevated | Magic damage, AOE |
| Medic | Elevated | Heal other towers |
| Supporter | Any | Buff/debuff specialist |
| Specialist | Any | Unique mechanics (push, pull, stealth) |

**Archetypes (Sub-classes):**
- Guard: Duelist, AOE, Ranged, Arts
- Sniper: Anti-Air, Spreadshot, Long-range
- etc.

---

### 14.3 Elite Promotion System
**Source:** Arknights E1/E2

**Concept:** Major upgrade milestones that unlock new capabilities.

**Promotion Levels:**
| Level | Unlock | Cost |
|-------|--------|------|
| E0 | Base stats, Skill 1 | Free |
| E1 | +Stats, Skill 2, Talent 1 | Materials + Gold |
| E2 | +Stats, Skill 3, Talent 2, New Art | Rare Materials + Gold |

**E2 Exclusive Features:**
- Third skill slot
- Second talent
- Mastery training available
- Alternate artwork
- Level cap increase (E0: 50, E1: 70, E2: 90)

---

### 14.4 Skill Mastery System
**Source:** Arknights Mastery

**Concept:** Further enhance individual skills beyond max level.

**Mastery Levels:**
| Mastery | Effect | Cost |
|---------|--------|------|
| M1 | Skill enhancement | Training + Materials |
| M2 | Further enhancement | More Training + Rare Materials |
| M3 | Maximum power | Extensive Training + Very Rare Materials |

**Training Facility:**
- Only 1 skill can train at a time per facility
- Training takes real time (hours)
- Can speed up with premium currency

---

### 14.5 Trust/Bond System
**Source:** Arknights Trust

**Concept:** Units gain stats from being used repeatedly.

**Trust Mechanics:**
- Using unit in battle increases Trust
- Trust maxes at 200%
- Trust provides stat bonuses
- Trust 100% unlocks unit's backstory
- Trust 200% unlocks bonus profile content

**Trust Bonuses:**
```lua
TrustBonus = {
    [50] = {ATK = +20},
    [100] = {ATK = +30, DEF = +20, Story = true},
    [150] = {ATK = +40, DEF = +30, HP = +100},
    [200] = {ATK = +50, DEF = +40, HP = +150, BonusContent = true},
}
```

---

### 14.6 Base Building / RIIC System
**Source:** Arknights Base

**Concept:** Idle game layer with resource generation.

**Base Rooms:**
| Room | Function |
|------|----------|
| Factory | Produces XP items, gold |
| Trading Post | Converts resources to premium currency |
| Power Plant | Provides power for other rooms |
| Dormitory | Restores operator morale |
| Training Room | Skill mastery training |
| Reception | Friend visits, clue exchange |
| Workshop | Craft items |

**Operator Assignment:**
- Assign operators to rooms for bonuses
- Each operator has base skills
- Morale depletes while working
- Rest in dormitory to recover

**Dormitory Furniture:**
- Decorate with furniture sets
- Higher ambiance = faster morale recovery
- Furniture from events and shops

---

### 14.7 Contingency Contract (CC) Mode
**Source:** Arknights CC

**Concept:** Customizable difficulty with stackable modifiers.

**Structure:**
- Choose map
- Select "contracts" (modifiers)
- Each contract adds Risk Level
- Higher Risk = Better rewards

**Contract Examples:**
| Contract | Risk | Effect |
|----------|------|--------|
| HP+ | +1 | Enemies +20% HP |
| ATK+ | +1 | Enemies +15% ATK |
| Speed+ | +2 | Enemies +20% movement |
| Deployment Limit | +2 | Can only deploy 6 units |
| No Healing | +3 | Towers cannot be healed |
| Elite Enemies | +3 | All enemies are elite |
| DP Drain | +2 | DP regen -50% |
| Specific Ban | +1 | Cannot use [Class] |

**Risk Level Rewards:**
| Risk | Reward |
|------|--------|
| 5 | 100 gems |
| 10 | 300 gems + materials |
| 15 | 500 gems + rare materials |
| 18 | 1000 gems + exclusive badge |
| 20+ | Leaderboard placement |

---

### 14.8 Integrated Strategies / Roguelike Mode
**Source:** Arknights IS

**Concept:** Roguelike tower defense with random elements.

**Structure:**
- Start with limited roster
- Progress through branching paths
- Recruit new operators at nodes
- Gain relics (run-specific buffs)
- Permadeath - fail = restart

**Node Types:**
| Node | Effect |
|------|--------|
| Combat | Standard battle |
| Elite | Harder battle, better rewards |
| Boss | Major challenge |
| Recruitment | Add unit to squad |
| Shop | Buy items/relics |
| Rest | Heal units |
| Event | Random encounter |

**Relics:**
- Run-specific powerful buffs
- Common/Rare/Epic tiers
- Synergize with certain playstyles

**Monthly Reset:**
- Different themes each month
- Exclusive rewards per theme
- Permanent unlocks from playing

---

### 14.9 Annihilation Mode
**Source:** Arknights Annihilation

**Concept:** Weekly resource farm with auto-deploy.

**Features:**
- Long battle (400 enemies)
- First clear manual, then auto-repeat
- Weekly cap on rewards
- Multiple maps with different rewards

**Auto-Deploy System:**
- Record your successful run
- System replays your exact actions
- Can fail if units changed (trust, levels)
- Re-record if needed

---

### 14.10 Clue Exchange / Social Gifts
**Source:** Arknights Clue System

**Concept:** Collect and exchange items with friends.

**Mechanics:**
- Operators find clues while assigned to Reception
- 7 different clue types
- Collect all 7 = Host party (bonus rewards for you + friends)
- Can gift clues to friends who need them
- Daily friend credits from visitors

**Benefits:**
- Friend Credits spent in special shop
- Encourages daily social interaction
- Mutual benefit system

---

### 14.11 Retreating & Redeployment
**Source:** Arknights

**Concept:** Towers can be manually retreated and redeployed.

**Mechanics:**
- Retreat tower to recover partial DP
- Redeployment timer before placing again
- Some skills trigger on deployment (use strategically)
- "Fast Redeploy" class = short timers

**Strategic Uses:**
- Reposition for different threats
- Refresh deployment-triggered abilities
- Recover DP in emergencies

---

## Part 15: Additional Unique Mechanics

### 15.1 Tower Sacrifice System
**Source:** BTD6 Sun Temple

**Concept:** Sacrifice towers to power up a special tower.

**Implementation:**
- Special "Temple" tower type
- Absorbs nearby towers when upgraded
- Gains abilities based on what was sacrificed
- Categories: Damage, Support, Speed, Magic

---

### 15.2 MOAB-Class / Boss Tier System
**Source:** BTD6

**Concept:** Hierarchical boss enemy types.

**Boss Tiers:**
| Tier | Name | HP Multi | Speed | Children |
|------|------|----------|-------|----------|
| 1 | Mini-Boss | 5x | 1.0x | None |
| 2 | Boss | 20x | 0.8x | 4 Mini-Boss |
| 3 | Mega-Boss | 100x | 0.5x | 4 Boss |
| 4 | Giga-Boss | 500x | 0.3x | 4 Mega-Boss |
| 5 | Final Boss | 2000x | 0.2x | 4 Giga-Boss |

---

### 15.3 Support Tower Buffs (Villages/Alchemists)
**Source:** BTD6

**Concept:** Towers that exist primarily to buff others.

**Buff Tower Types:**
- **Village/Commander:** Area buff to all nearby towers
- **Alchemist/Enchanter:** Single-target powerful buff
- **Engineer/Mechanic:** Create additional attacking sentries

**Buff Stacking Rules:**
- Same buff type doesn't stack
- Different buff types stack multiplicatively
- Visual indicator for buffed towers

---

### 15.4 Terrain/Elevation System
**Source:** Arknights, BTD6

**Concept:** Map tiles affect tower placement and stats.

**Terrain Types:**
| Terrain | Effect |
|---------|--------|
| Ground | Melee only |
| Elevated | Ranged only, +10% range |
| Water | Amphibious only, +speed |
| Hazard | Damage over time to towers |
| Buff Zone | +damage in this area |

---

### 15.5 Blocking/Tanking System
**Source:** Arknights

**Concept:** Melee towers "block" enemies, preventing movement.

**Block Count:**
- Each melee tower can block X enemies
- Blocked enemies attack the tower
- Tower has HP, can be destroyed
- Healing towers can restore HP

**Block Values:**
| Class | Block Count |
|-------|-------------|
| Assassin | 1 |
| Guard | 2 |
| Defender | 3-4 |
| Special | 0 (don't block) |

---

### 15.6 Direction/Facing System
**Source:** Arknights

**Concept:** Towers have a facing direction that matters.

**Mechanics:**
- Melee towers attack in front only
- Can rotate on placement
- Some abilities are directional cones
- Repositioning requires retreat + redeploy

---

### 15.7 Limited Deployment Slots
**Source:** Arknights

**Concept:** Can only have X towers deployed at once.

**Default:** 8-12 tower limit per map
**Modifiers:** Some skills/relics increase limit
**Strategy:** Choose carefully, retreat and redeploy

---

### 15.8 Sanity/Stamina System
**Source:** Arknights

**Concept:** Energy system limiting plays per day.

**Mechanics:**
- Each battle costs Sanity
- Sanity regenerates over time (1 per 6 min)
- Can refill with premium currency
- Harder content costs more Sanity

**Note:** Consider if this fits your game's monetization strategy. Can be frustrating but drives engagement.

---

## Updated Feature Priority Matrix

| Feature | Impact | Effort | Priority | Source |
|---------|--------|--------|----------|--------|
| Color System | High | Low | ⭐⭐⭐ | DBL/ASTD |
| Tags System | High | Medium | ⭐⭐⭐ | DBL |
| Evolution System | Very High | High | ⭐⭐⭐ | User |
| Monkey Knowledge | High | Medium | ⭐⭐⭐ | BTD6 |
| Trust/Bond System | Medium | Low | ⭐⭐ | Arknights |
| Elite Promotion | High | Medium | ⭐⭐⭐ | Arknights |
| Skill Mastery | Medium | Medium | ⭐⭐ | Arknights |
| Paragon System | High | High | ⭐⭐ | BTD6 |
| Hero System | High | Medium | ⭐⭐ | BTD6 |
| Odyssey Mode | Medium | Medium | ⭐⭐ | BTD6 |
| Boss Rush | High | High | ⭐⭐ | BTD6 |
| Roguelike Mode | Very High | Very High | ⭐⭐ | Arknights |
| Contingency Contract | High | High | ⭐⭐ | Arknights |
| Base Building | Medium | High | ⭐ | Arknights |
| Contested Territory | Medium | Very High | ⭐ | BTD6 |

---

## Final Summary

This plan now includes **150+ features** across 15 categories, inspired by:
- **Your specifications** (Color, Tags, XP Evolution)
- **ASTD X / Anime Adventures** (Gacha, trading, events)
- **Tower Defense Simulator** (Skills, co-op, raids)
- **Bloons TD 6** (Paragons, heroes, odyssey, boss events, monkey knowledge)
- **Arknights** (DP system, classes, promotions, mastery, roguelike, base building, CC mode)

Review and let me know what to keep, modify, or cut!
