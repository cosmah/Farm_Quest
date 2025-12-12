# 🌾 Farm From Scratch

An addictive farming management game built with Flutter. Start with nothing, take a loan, build your farm empire, and manage crops with real consequences!

## 🎮 Game Features

### Core Gameplay
- **Bank Loan System**: Choose from 3 loan tiers with different risks and rewards
- **Crop Management**: Plant, water, weed, and protect crops from pests
- **Real Consequences**: Neglect crops and they die; miss loan payment and lose everything
- **Endless Progression**: No win condition - keep growing your farm empire forever
- **Persistent Save**: Progress is auto-saved; pick up where you left off

### Crop Types
- 🥕 **Carrots**: Fast-growing, low profit (30s, $10 → $25)
- 🌽 **Corn**: Medium growth, good profit (60s, $30 → $80)
- 🍅 **Tomatoes**: Slow growth, high profit (90s, $50 → $150)

### Game Mechanics
- **Watering**: Crops need water every 20-40s or they wilt and die
- **Weeding**: Random weeds spawn, slowing growth by 50%
- **Pest Control**: Random pests appear that kill crops if ignored
- **Plot Expansion**: Start with 4 plots, unlock up to 8
- **Loan Pressure**: Race against the clock to repay before deadline

## 🚀 How to Run

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Android Studio / VS Code
- Android device/emulator or iOS simulator

### Run the Game

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Or for specific platform
flutter run -d <device-id>

# Check available devices
flutter devices
```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📱 Platforms Supported
- ✅ Android
- ✅ iOS
- ✅ Linux (desktop)
- ✅ Windows (desktop)
- ✅ macOS (desktop)
- ✅ Web

## 🎯 Game Strategy Tips

1. **Start Small**: Take the small loan first to learn the mechanics
2. **Water Regularly**: Set reminders to check your crops every 20 seconds
3. **Act Fast on Pests**: Pests kill crops quickly - remove them immediately
4. **Calculate Profit**: Tomatoes have highest profit margin but take longest
5. **Unlock Plots Early**: More plots = more parallel income
6. **Repay Before Deadline**: Always aim to repay with time to spare

## 🏗️ Project Structure

```
lib/
├── main.dart                    # Entry point & splash screen
├── models/
│   ├── crop_type.dart          # Crop definitions
│   ├── crop.dart               # Crop instance with state
│   ├── plot.dart               # Farm plot container
│   ├── loan.dart               # Bank loan system
│   └── game_state.dart         # Global game state
├── screens/
│   ├── intro_screen.dart       # Story introduction
│   ├── bank_screen.dart        # Loan selection
│   ├── farm_screen.dart        # Main gameplay
│   └── game_over_screen.dart   # Lose screen
├── widgets/
│   ├── plot_widget.dart        # Individual farm plot UI
│   └── shop_bottom_sheet.dart  # Seed shop
└── services/
    └── game_service.dart       # Game logic & save system
```

## 🎨 Design Philosophy

- **Emoji-Based Graphics**: No custom assets needed, works everywhere
- **Minimalist UI**: Clean, modern, professional design
- **Programmatic Effects**: Gradients, animations, particles in code
- **Mobile-First**: Optimized for portrait mode on phones

## 💾 Save System

- Auto-saves every 10 seconds
- Saves on app close
- Saves after major actions
- Persistent across sessions
- Calculates time elapsed when returning

## 🔮 Future Enhancements

Potential features to add:
- 🧑‍🌾 Workers for auto-farming
- 🌦️ Weather system
- 🐄 Animals for passive income
- 🏆 Achievements
- 🎯 Daily challenges
- 📊 Leaderboards
- 🎵 Sound effects
- 🌈 Special events

## 📄 License

This project is open source and available for personal and commercial use.

## 🤝 Contributing

Feel free to fork, modify, and improve! This was built as a weekend project to explore Flutter game development.

---

**Made with ❤️ and Flutter**

*Time to build your farm empire!* 🚜🌾
