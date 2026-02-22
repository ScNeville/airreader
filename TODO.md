# AirReader – Development TODO

A desktop-first (macOS/Windows) WiFi survey & planning tool built in Flutter.

---

## Phase 1 – Project Foundation ✅

- [x] Configure desktop targets (macOS + Windows) as primary, disable mobile platforms
- [x] Set up project structure (`lib/` folders: `models/`, `providers/`, `screens/`, `widgets/`, `services/`, `utils/`)
- [x] Add core dependencies: `flutter_bloc`, `equatable`, `file_picker`, `vector_math`, `uuid`, `window_manager`
- [x] Create app shell: main window, navigation sidebar, theme (dark/light)
- [x] Define core data models:
  - `FloorPlan` (image bytes, scale, dimensions)
  - `WallSegment` (material, thickness, attenuation dB)
  - `AccessPoint` (brand, model, frequency bands, power, position)
  - `ClientDevice` (type, position, preferred band, AP association)
  - `Survey` (top-level container: floor plan + walls + APs + clients)

---

## Phase 2 – Floor Plan Import & Editor ✅

- [x] Implement floor plan import (PNG, JPG, SVG, PDF)
- [x] Display imported floor plan on a zoomable, pannable canvas
- [x] Set real-world scale (e.g. drag to define a known distance)
- [x] Wall drawing tool: draw wall segments over the floor plan
- [x] Wall material picker:
  - Plasterboard / drywall
  - Brick
  - Concrete
  - Glass
  - Metal / steel
  - Wood
  - Custom (user-defined attenuation & thickness)
- [x] Wall thickness input per segment
- [x] Edit / delete individual wall segments
- [x] Save / load floor plan with wall data

---

## Phase 3 – Access Point Placement ✅

- [x] Access point library (brand + model database):
  - Ubiquiti, Cisco/Meraki, Aruba, TP-Link, Netgear, etc.
  - Per-model specs: TX power, antenna gain, supported bands (2.4 GHz / 5 GHz / 6 GHz)
- [x] Add custom/generic AP option
- [x] Drag-and-drop AP placement on the floor plan canvas
- [x] AP configuration panel:
  - Select brand/model
  - Set channel & bandwidth (20/40/80/160 MHz)
  - Set transmit power (mW / dBm)
  - Set allocated bandwidth/speed cap per AP
  - Enable/disable individual frequency bands
- [x] Multi-AP support (unlimited APs per floor plan)
- [x] Highlight selected AP; show coverage radius preview

---

## Phase 4 – RF Signal Simulation Engine ✅

- [x] Implement free-space path loss (FSPL) model
- [x] Implement wall attenuation: sum dB loss per wall segment crossed (ray-casting from AP to each grid point)
- [x] Ray-casting / line-of-sight calculation through wall segments
- [x] Per-frequency-band simulation (2.4 GHz / 5 GHz / 6 GHz)
- [x] Aggregate signal from multiple APs (best-signal or weighted sum)
- [x] Background compute isolate so UI stays responsive during recalculation
- [x] Recalculate signal map when:
  - AP is moved / settings changed
  - Wall added / removed / modified
  - Frequency band toggled

---

## Phase 5 – Heat Map Visualisation ✅

- [x] Render signal-strength heat map overlay on the floor plan canvas
- [x] Colour gradient: strong (green) → medium (yellow) → weak (orange) → no signal (red/transparent)
- [x] Adjustable opacity of heat map overlay
- [x] Toggle heat map on/off
- [x] Per-band heat map toggle (show 2.4 GHz, 5 GHz, or 6 GHz separately)
- [x] Legend / colour-scale indicator (dBm values)
- [x] Live update heat map as AP is dragged

---

## Phase 6 – Client Device Simulation ✅

- [x] Client device library (laptop, phone, tablet, IoT sensor, etc.)
- [x] Drag-and-drop client placement on the floor plan
- [x] Per-client info panel:
  - Associated AP (best signal or manually set)
  - Received signal strength (dBm / RSSI)
  - Estimated throughput based on AP allocation and signal quality
- [x] Show client–AP association lines on canvas
- [x] Per-client frequency band preference setting

---

## Phase 7 – Network Performance Modelling

- [ ] Input total WAN bandwidth available
- [ ] Allocate bandwidth per AP (fixed or proportional)
- [ ] Estimate per-client throughput based on:
  - Signal quality (SNR → MCS index → PHY rate)
  - Number of clients sharing the AP
  - AP bandwidth allocation
- [ ] Display network performance summary panel:
  - Per-AP: connected clients, utilisation %, estimated aggregate throughput
  - Per-client: expected download/upload speed
- [ ] Congestion warnings (AP overloaded / signal below threshold)

---

## Phase 8 – Scenario Management

- [ ] Named scenario snapshots (save current AP + wall + client configuration as a scenario)
- [ ] Scenario comparison view (side-by-side heat maps or overlay diff)
- [ ] Undo / redo for all canvas operations
- [ ] Duplicate scenario for what-if testing

---

## Phase 9 – Export & Reporting

- [ ] Export heat map as PNG/PDF (floor plan + overlay)
- [ ] Export network performance summary as CSV or PDF report
- [ ] Export full survey project file (JSON) for later editing
- [ ] Import previously saved survey project file
- [ ] Report includes: AP positions, wall materials, client associations, throughput estimates

---

## Phase 10 – Polish & Platform Specifics

- [ ] macOS: native menu bar integration, window sizing/resizing
- [ ] Windows: taskbar integration, window management
- [ ] Keyboard shortcuts (delete selected item, undo/redo, toggle bands, zoom in/out)
- [ ] Localisation groundwork (English first)
- [ ] Unit tests for RF simulation engine
- [ ] Integration tests for canvas interactions
- [ ] Performance profiling & heat map render optimisation
- [ ] App icon & branding

---

## Backlog / Future Ideas

- [ ] Multi-floor / multi-storey support (floor-to-floor interference)
- [ ] Import Ekahau or other vendor survey files
- [ ] Real-time AP discovery via OS WiFi APIs (live survey overlay)
- [ ] Channel interference visualisation (co-channel / adjacent-channel)
- [ ] Mesh network modelling (AP-to-AP backhaul links)
