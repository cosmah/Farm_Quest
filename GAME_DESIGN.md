# 🌾 Farm From Scratch - Game Design Document

## 🎮 Game Concept

A **farming management survival game** with real stakes and emotional engagement. Player starts with nothing, takes a bank loan, builds a farm, and must manage crops while racing against the loan deadline.

---

## 📖 Story Flow

### ACT 1: The Loan
- Player starts with $0
- Visit bank, choose loan amount:
  - **Small Loan**: $500 (5% interest, 5 min deadline)
  - **Medium Loan**: $2000 (8% interest, 10 min deadline)  
  - **Big Loan**: $5000 (12% interest, 15 min deadline)
- Risk/reward: bigger loan = more opportunity BUT more pressure

### ACT 2: Starting the Farm
- Buy land plots ($100-$500 each)
- Buy seeds (different crops, different prices/growth times/profits)
  - 🥕 **Carrots**: $10, 30s growth, sells for $25
  - 🌽 **Corn**: $30, 60s growth, sells for $80
  - 🍅 **Tomatoes**: $50, 90s growth, sells for $150

### ACT 3: The Grind
Player must actively manage their farm with real consequences.

---

## 🚜 Core Mechanics

### Actions:
1. **Planting**: Tap plot → select seed → plant
2. **Watering** 💧: Crops need water every 20s or they wilt
3. **Weeding** 🌿: Weeds appear randomly, steal 20% growth speed
4. **Pest Control** 🐛: Bugs appear, must tap to remove or crop dies
5. **Harvesting**: When ready, tap to harvest → get coins
6. **Selling**: Auto-sell harvested crops

### ⚠️ Consequences:
- **Miss watering**: Crop wilts (turns brown), dies in 10s
- **Ignore weeds**: Growth slows by 50%
- **Ignore pests**: Crop dies completely
- **Miss loan payment**: GAME OVER - Lose everything and restart from scratch

---

## 📊 Endless Progression System

### The Loop:
1. Take loan → Build farm → Pay off loan (with interest)
2. Keep profits → Expand (more plots, better seeds)
3. Take bigger loans for bigger expansions
4. Hire workers (auto-water, auto-weed)
5. Unlock premium crops
6. Buy animals for passive income
7. Upgrade irrigation systems
8. **Keep growing forever!**

### 🎯 The Hook:
The **PRESSURE** of the loan deadline + the **SATISFACTION** of building from nothing + **REAL CONSEQUENCES** + **ENDLESS GROWTH** = super engaging!

### Win/Lose Conditions:
- **No Win State**: Game continues indefinitely, always new goals to reach
- **Lose State**: Fail to repay loan by deadline = GAME OVER, restart from beginning
- **Persistent Save**: Progress is saved automatically, can close and return anytime

---

## 🎨 Asset & Visual Strategy

### Emojis as Game Assets:
```
🏦 Bank
💰 Coins/Money
📄 Loan Document

CROPS LIFECYCLE:
🌱 Seed → 🌿 Growing → 🌾 Mature → 🥕🌽🍅 Ready to Harvest
💀 Dead crop (withered)

CARE ACTIONS:
💧 Water
🌿 Weeds (bad)
🐛 Pests (bad)
🧑‍🌾 Farmer/Worker

UI ELEMENTS:
⏰ Timer
📊 Progress bar (code-drawn)
🎯 Goals
⚠️ Warnings
```

### Programmatic Graphics:
- **Farm plots**: Rounded rectangles with gradient (brown for soil)
- **Progress bars**: Custom-painted for growth, water level, loan repayment
- **Animations**: Smooth transitions, shake effects, color changes
- **Backgrounds**: Beautiful gradients (green fields, blue sky)
- **Particles**: Floating sparkles when harvesting

---

## 🏗️ Technical Architecture

### File Structure:
```
lib/
├── main.dart                    # Entry point
├── models/
│   ├── crop.dart               # Crop class (type, growth, health)
│   ├── plot.dart               # Farm plot with crop state
│   ├── game_state.dart         # Global game state
│   └── loan.dart               # Loan tracking
├── screens/
│   ├── intro_screen.dart       # Story introduction (first time only)
│   ├── bank_screen.dart        # Choose loan (repeatable)
│   ├── shop_screen.dart        # Buy seeds/land
│   ├── farm_screen.dart        # Main gameplay (where player spends most time)
│   ├── game_over_screen.dart   # Lose screen only
│   └── stats_screen.dart       # Lifetime statistics
├── widgets/
│   ├── plot_widget.dart        # Individual farm plot
│   ├── crop_widget.dart        # Crop with animations
│   ├── action_button.dart      # Water/weed/pest buttons
│   └── stat_display.dart       # Money, loan, timer displays
└── services/
    └── game_service.dart       # Save/load, game loop
```

### Core Classes:

**CropType:**
- name, emoji, seedCost, sellPrice, growthTime
- waterInterval, weedChance, pestChance

**Plot:**
- crop, waterLevel, hasWeeds, hasPests
- plantedTime, lastWatered, growthProgress

**GameState:**
- money, plots, loan, loanDeadline
- workers, upgrades
- totalEarnings, loansRepaid (lifetime stats)
- lastSaveTime (for auto-save)

---

## 🎮 Game Loop (60 FPS)

Every second:
1. Update crop growth
2. Decrease water levels
3. Random weed/pest spawns
4. Check for crop death
5. Update loan timer
6. Check lose condition (loan deadline)
7. Auto-save progress every 10 seconds

---

## 💾 Save System

### What Gets Saved:
- Current money and assets
- All farm plots and their states (crops, water level, weeds, pests)
- Active loan amount and deadline
- Purchased upgrades and workers
- Lifetime statistics (total earnings, loans repaid, crops harvested)
- Current timestamp (for calculating time passed when returning)

### Auto-Save Triggers:
- Every 10 seconds during gameplay
- When closing the app
- After major actions (buying plots, repaying loan, harvesting)
- Before game over screen

### On App Launch:
- Load saved game state
- Calculate time passed since last save
- Update crop states based on elapsed time
- Continue exactly where player left off

### On Game Over (Loan Default):
- Clear all progress
- Keep lifetime statistics for player reference
- Start fresh with new bank visit

---

## 📱 UI Layout

```
┌─────────────────────────┐
│  💰 $450  📄 Loan: $200 │  ← Status bar
│  ⏰ 3:45 remaining       │
├─────────────────────────┤
│  [🌾][🌱][🥕][💀]      │  ← Farm plots (scrollable)
│  [🌿][  ][🌽][🍅]      │
│  [  ][  ][  ][  ]      │
├─────────────────────────┤
│  Selected: Plot 1       │  ← Action panel
│  [💧Water] [🌿Weed]    │
│  [🐛Remove Pest]        │
├─────────────────────────┤
│  [🛒Shop] [🏦Loan] [⚙️] │  ← Bottom nav
└─────────────────────────┘
```

---

## ⚙️ Features Breakdown

### MVP (First Build):
- ✅ Bank loan selection with multiple tiers
- ✅ 3 crop types with different economics
- ✅ 4-6 farm plots (expandable)
- ✅ Plant, water, harvest mechanics
- ✅ Weeds & pests spawn system
- ✅ Crop death mechanics
- ✅ Loan timer & repayment system
- ✅ Lose condition (fail to repay)
- ✅ **Persistent save system** - Progress never lost
- ✅ Ability to take new loans after repaying
- ✅ Endless progression loop

### Enhanced (If time):
- ⭐ Hire workers (auto-actions)
- ⭐ Unlock more crops (5+ additional varieties)
- ⭐ Weather effects (rain, drought, sunny)
- ⭐ Achievements & milestones
- ⭐ Animals for passive income
- ⭐ Special events (market bonus days, festivals)

### Progression Milestones (Goals for Endless Play):
- 💰 Net Worth: $1K → $10K → $100K → $1M
- 🏆 Loans Repaid: 1 → 5 → 10 → 25 → 100
- 🌾 Crops Harvested: 100 → 500 → 1K → 10K
- 📊 Farm Plots: 4 → 8 → 16 → 32
- 🧑‍🌾 Workers Hired: 1 → 5 → 10 → 20
- 🏦 Biggest Loan Repaid: $5K → $50K → $500K

---

## 🚀 Development Plan

1. **Setup** (15 min) - Project structure, dependencies
2. **Models** (30 min) - All game logic classes
3. **Save System** (45 min) - SharedPreferences, JSON serialization, auto-save
4. **Intro & Bank** (30 min) - Story and loan selection (repeatable)
5. **Farm Screen** (2 hours) - Main gameplay, plots, actions
6. **Game Loop** (1 hour) - Timers, updates, spawning, persistence
7. **Shop & Economy** (45 min) - Buying seeds/plots
8. **Loan Repayment System** (30 min) - Pay loan, take new loan, game over
9. **Polish** (1 hour) - Animations, juice, balance, stats screen

**Total Estimated Time: ~6.5 hours**

---

## 🎯 Key Success Factors

1. **Tension**: Loan deadline creates urgency and risk
2. **Consequences**: Real losses make decisions matter (crop death, loan default)
3. **Endless Progression**: Always something new to achieve, no ceiling
4. **Satisfaction**: Building something from nothing, watching empire grow
5. **Persistence**: Progress is never lost (unless you fail the loan)
6. **Risk/Reward**: Taking bigger loans for faster growth vs. playing safe
7. **Strategy**: Different loan strategies, crop choices, expansion paths

---

## 🎨 Visual Style

- **Clean & Modern**: Gradient backgrounds, smooth animations
- **Emoji-Based**: Charming and works on all devices
- **Informative**: Clear progress bars, status indicators
- **Responsive**: Smooth transitions, satisfying feedback

---

## 💡 Monetization Potential (Future)

- Speed boosters
- Premium seeds
- Auto-workers
- Remove ads
- Time skip tokens
- Cosmetic skins for plots/emojis
- Season pass with exclusive crops

---

**Created**: December 12, 2025  
**Platform**: Flutter (Mobile - iOS & Android)  
**Target Audience**: All ages, casual to mid-core players

