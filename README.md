# AirReader

> **Desktop WiFi survey and planning tool** — place access points on a floor plan, simulate RF propagation across 2.4 / 5 / 6 GHz bands, and instantly visualise signal coverage with a heat map.

---

## Features

| Category | Details |
|---|---|
| **Floor Plan Import** | Load PDF or SVG floor plans; scale and position them on the canvas |
| **Access Point Management** | Place, configure, and manage multiple APs with per-AP TX power, antenna gain, and band selection |
| **Wall & Material Modelling** | Draw walls and assign building materials (drywall, concrete, brick, metal, glass…) with per-material RF attenuation values for all three bands |
| **RF Heat Map** | Real-time signal-strength overlay with a configurable opacity slider and per-band selector (2.4 GHz / 5 GHz / 6 GHz) |
| **RF Engineering Analysis** | Full link-budget report: FSPL, path loss, EIRP, receiver sensitivity, SNR margin, and coverage radius |
| **Network Performance** | Estimated throughput, channel utilisation, and co-channel interference projections |
| **Environment Zones** | Define named zones (office, warehouse, outdoor…) with distinct attenuation profiles |
| **Client Devices** | Model client device capabilities to predict real-world per-client performance |
| **Dark / Light Mode** | Toggle between themes at any time |
| **Project Save / Open** | Persist the entire survey to a local file and reload it later |

---

## Platform Support

| Platform | Status |
|---|---|
| 🐧 Linux | ✅ Supported |
| 🍎 macOS | ✅ Supported |
| 🪟 Windows | ✅ Supported |

AirReader is a **desktop-only** application; mobile and web builds are not officially supported.

---

## Tech Stack

- **[Flutter](https://flutter.dev/)** — cross-platform UI framework
- **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** — predictable state management (BLoC / Cubit)
- **[pdfx](https://pub.dev/packages/pdfx)** — PDF page rasterisation for floor plan import
- **[flutter_svg](https://pub.dev/packages/flutter_svg)** — SVG rasterisation for floor plan import
- **[file_picker](https://pub.dev/packages/file_picker)** — native file-open/save dialogs
- **[window_manager](https://pub.dev/packages/window_manager)** — desktop window title, size, and constraints
- **[vector_math](https://pub.dev/packages/vector_math)** — geometry helpers for RF calculations
- **[uuid](https://pub.dev/packages/uuid)** — stable unique identifiers for model objects

---

## Getting Started

### Prerequisites

| Tool | Minimum Version |
|---|---|
| Flutter SDK | 3.10 |
| Dart SDK | 3.10 |

Install Flutter by following the [official guide](https://docs.flutter.dev/get-started/install).

### Clone & Run

```bash
# 1 — Clone the repository
git clone https://github.com/ScNeville/airreader.git
cd airreader

# 2 — Fetch dependencies
flutter pub get

# 3 — Run on your desktop
flutter run -d linux     # or macos / windows
```

### Build a Release Binary

```bash
flutter build linux --release   # or macos / windows
```

The compiled application is placed in `build/linux/x64/release/bundle/` (Linux) or the equivalent platform folder.

---

## Project Structure

```
lib/
├── blocs/          # BLoC / Cubit state management
├── models/         # Pure data models (AP, wall, floor plan, signal map…)
├── providers/      # Lightweight InheritedWidget providers
├── screens/        # Top-level page widgets
├── services/       # Business logic (RF simulation, file I/O, PDF import…)
├── utils/          # Constants, desktop-window helpers
└── widgets/        # Reusable UI components and canvas painters
```

---

## Signal Strength Reference

The heat map uses the following colour-coded thresholds:

| Signal (dBm) | Quality |
|---|---|
| ≥ −50 | 🟢 Excellent |
| −50 to −65 | 🟡 Good |
| −65 to −75 | 🟠 Fair |
| −75 to −85 | 🔴 Poor |
| < −85 | ⚫ No signal |

---

## Contributing

Contributions are welcome! Please open an issue to discuss your idea before submitting a pull request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "feat: add my feature"`
4. Push the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

This project is private and not published to pub.dev. See the repository owner for licensing details.
