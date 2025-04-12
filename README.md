# 🫀 **CPR PulseCoach**
#### *Train to Save Lives — with Precision and Rhythm*

**CPR PulseCoach** is an embedded training device that helps civilians and first responders alike improve their CPR timing and rhythm. Built for real-world readiness, it offers engaging modes, live performance feedback, and seamless mobile integration — all designed to help users master the life-saving skill of chest compressions.

💡 *Built at [BitHacks] 2025 — Turning rhythm into rescue.*

## 🚑 **What It Does**
**CPR PulseCoach** is a smart CPR training tool that lets users practice and test their CPR technique with accurate, real-time feedback.

- **Real-time BPM detection** via a load cell and amplifier
- **Feedback delivered through:**
  - An OLED screen
  - A mini metal speaker (metronome or song mode)
  - A color-coded interface (Too Slow, On Beat, Too Fast)
  - Wireless communication via Bluetooth
  - Companion Flutter mobile app for real-time plotting, audio feedback, and stats

## 🎮 **Modes**

### 🟢 **Training Mode** ("Freeplay")
**Visual feedback of:**
- Live BPM
- Target BPM (103 — AHA recommended rate)

**Color or text indicators:**
- ✅ **On beat**
- 🐢 **Too slow**
- 🐇 **Too fast**

**Choose between:**
- Metronome beat
- Classic training songs like *Stayin' Alive* or *Mario Theme*

### 🔴 **Testing Mode** ("Simulation")
- OLED displays a countdown timer only — *no live feedback*
- User must keep tempo without assistance
- Performance is logged via Bluetooth to the app
- Optional "ambient/emergency" noise to mimic stressful real-world environment

**After the session:**
- App displays accuracy score and timing graph

## 📱 **Mobile App** (Flutter)
The Flutter companion app enhances the CPR PulseCoach with:

- 📊 **Real-time BPM graphing** in Training mode
- 🔔 **Song/metronome selection**
- 🎯 **Post-test analytics**: accuracy score, BPM consistency plot
- 💾 **Optional session logging** for long-term tracking

## 🛠️ **Built With**
- **Arduino UNO R4 WiFi**
- **HX711 Amplifier + Load Cell**
- **OLED Display** (128x64)
- **Mini Metal Speaker**
- **Flutter** (Dart) Mobile App
- **PlatformIO + VSCode** for embedded development

## 🧠 **Why It Matters**
*Every second counts in a cardiac emergency* — but even trained individuals often struggle to keep a proper compression pace under stress. **CPR PulseCoach** makes high-quality CPR accessible, engaging, and portable, helping users turn practice into instinct.

Whether you're a medical student, paramedic, or just someone who wants to be ready — **CPR PulseCoach** helps you stay on beat when it matters most.

## 📸 **Demo**
⚡ *Coming soon: Check out our demo video and app screenshots!*

## 🤝 **Team**
*Built with care by Ryder Risic, Youngwoo Chang, Evan Velek, Ethan Vo*
🚀 **Hackathon 2025 Submission**
