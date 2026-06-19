# Pong Game on FPGA

## Project Information
- **Course**: Digital Logic Design
- **Platform**: Sword Kintex 7 FPGA (SWORD-002: Basic I/O Ver 2.0 / 2017-02-24)
- **Language**: Verilog HDL
- **Tools**: Xilinx Vivado, Logisim (auxiliary)
- **Team**: 2 members

## Objective
Recreate the classic arcade game **Pong** on an FPGA, featuring two-player versus and a simple AI opponent. The game is displayed on a VGA monitor at 640×480@60Hz, with controls from either the onboard matrix keyboard or a USB keyboard (via PS/2). Sound effects are provided by a passive buzzer.

## Implemented Features

### Core Functionality
- 6-state game state machine (Idle, Serve, Play, Pause, Score, Game Over)
- Two paddles controlled by buttons/keyboard; ball bounces off top/bottom walls
- Ball reflects off paddles with angle determined by hit position (5 levels: -2 to +2)
- Missed ball awards a point to opponent; first to 11 points wins
- Four difficulty levels (Easy / Hard / Master / Auto) selected via DIP switch SW[3:2]
  - **Easy**: ball at ~60 Hz game tick, paddle at 360 px/s
  - **Hard**: ball at ~120 Hz game tick, paddle at 480 px/s
  - **Master**: ball at ~180 Hz game tick, paddle at 540 px/s
  - **Auto**: starts at Easy pace, speed ×1.1 per paddle hit, no cap
- Seven-segment display shows current difficulty (EASy, HArd, |St, AUtO)
- 8 LEDs indicate game state and serving side

### Extended Features
- **VGA Display**: Full game screen with paddles, ball, center line, and scores
- **Ball Trail**: 3-frame ghost trail behind the ball with fading brightness (t-3: dark, t-1: bright)
- **Wide Paddle Powerup**: Green diamond spawns alternately on left/right paddle lanes (~8 sec cooldown). Collecting it extends the paddle by 5 px on both top and bottom for ~5 seconds (visualized with gray extension bands)
- **PS/2 Keyboard**: USB keyboard input (W/S for left paddle, ↑/↓ for right paddle, Enter/Space for start/pause, Esc for soft reset); works in parallel with onboard matrix keyboard
- **Buzzer Sound Effects**: Different tone frequencies for paddle hit, scoring, and game over events
- **Single-player AI**: Right paddle automatically tracks the ball's Y coordinate with a dead zone (60 px), randomized update delay, and direction-aware behavior (drifts to center when ball moves away)

### Recent Improvements
- **Paddle speed decoupled from game tick**: Paddle displacement per tick scales inversely with difficulty, keeping effective speed fair. Old behavior tied paddle to game tick rate, making Easy paddles extremely slow (120 px/s).
- **Fixed top-boundary underflow**: Paddle boundary check now ensures subtraction doesn't wrap around via unsigned arithmetic, preventing the paddle from disappearing off the top of the screen.
- **PS/2 data synchronization**: Data line now uses double-stage flip-flops for metastability protection.
- **Ball trail**: 3-frame ghost trail behind the ball with fading brightness for smoother visual tracking.
- **Wide paddle powerup**: Green diamond powerup spawns on paddle lanes every ~8 seconds; collecting it extends the paddle by 5 px on both top and bottom for ~5 seconds. Sides alternate to ensure fair distribution.

## File Structure
```
Pong_Project/
├── README.md
├── CONTRIBUTORS.md
├── docs/
│   └── Final_Report.pdf
├── source_code/
│   ├── defines.vh              # Global macro definitions
│   ├── Top.v                   # Top-level module
│   ├── clk_wiz.v               # Clocking Wizard wrapper (25.175 MHz) — Vivado IP Catalog core, see source_code/README.txt
│   ├── game_logic.v            # State machine, ball physics, paddle control, AI integration
│   ├── ai_paddle.v             # AI opponent logic
│   ├── vga_render.v            # VGA image generator (pixel color from coordinates)
│   ├── keypad_scanner.v        # 5×4 matrix keyboard scanner
│   ├── ps2_keyboard.v          # PS/2 keyboard receiver (modified from Pan's code)
│   ├── input_merger.v          # Merges matrix and PS/2 inputs
│   ├── seg_display.v           # 4-digit 7-segment driver (shows difficulty)
│   ├── led_status.v            # LED status indicator
│   ├── powerup_ctrl.v          # Wide-paddle powerup controller
│   └── buzzer_ctrl.v           # Passive buzzer tone generator
├── sim/
│   ├── tb_game_logic.v
│   ├── tb_seg_display.v
│   ├── tb_ai_paddle.v
│   └── ...
├── constraints/
│   └── pong.xdc
└── vivado_project/
    ├── pong_top.bit
    └── Project/                # Cleaned Vivado project
```

## Controls

### Onboard Matrix Keyboard
| Button | Function |
|--------|----------|
| Row 0, Col 0 | Start / Pause |
| Row 4, Col 0–3 | Left paddle up/down, right paddle up/down |

### PS/2 USB Keyboard
| Key | Function |
|-----|----------|
| **W** / **S** | Left paddle up / down |
| **↑** / **↓** | Right paddle up / down |
| **Enter** / **Space** | Start / Pause |
| **Esc** | Soft reset (return to idle, scores cleared) |

Both input sources work in parallel via OR logic in `input_merger.v`.

### DIP Switches
| Switch | Function |
|--------|----------|
| SW[0] | System reset (active high) |
| SW[1] | AI enable (0 = two-player, 1 = AI controls right paddle) |
| SW[3:2] | Difficulty: 00=Easy, 01=Hard, 10=Master, 11=Auto |

## Ball Physics and Paddle Interaction

### Bounce Angle
The ball's bounce angle is determined by the vertical offset between the ball center and paddle center at the moment of collision:

| Offset (ball_y - paddle_center_y) | Angle | Velocity (dx, dy) |
|---|---|---|
| > 20 px | Mild down | (4, +2) |
| > 5 px | Slight down | (5, +1) |
| between -5 and +5 px | Horizontal | (5, 0) |
| < -5 px | Slight up | (5, -1) |
| < -20 px | Mild up | (4, -2) |

The velocity lookup table keeps total speed approximately constant (|V|≈5).

### Serve Direction
- Initial serve goes right (toward right paddle).
- After a point, the conceding player's side serves toward the scorer.
- Serve angle is randomized from 7 options using a free-running counter.

## Team Division
- **Member A**: Game state machine, ball physics, AI, seven-segment display, buzzer, top-level integration
- **Member B**: Matrix keyboard, PS/2 interface, VGA rendering, font ROM, LED indicator, constraints
- **Joint**: Simulation, debugging, design report

## Hardware Notes
- **Clock**: 100 MHz onboard oscillator; MMCM generates 25.175 MHz for VGA and game logic. The MMCM is configured via Vivado IP Catalog (Clocking Wizard) — clk_wiz.v is a wrapper around the generated IP core. When rebuilding the project, either re-generate the core in Vivado's IP Catalog or implement the clock divider manually. If simulating in Vivado, note that the IP simulation model is loaded automatically; for standalone simulation, generate the clock directly in the testbench.
- **Matrix Keyboard**: 5 rows (V17, W18, W19, W15, W16) × 4 columns (V18, V19, V14, W14), active-low scan with pull-up on columns.
- **PS/2**: USB keyboard supported via onboard converter; pins N18 (clock) and M19 (data). Recognizes: W (0x1D), S (0x1B), Space (0x29), Enter (0x5A), Esc (0x76), ↑ (0xE0 0x75), ↓ (0xE0 0x72).
- **Buzzer**: Passive piezoelectric buzzer (AF25), requires square wave of appropriate frequency for sound.
- **7-Segment**: Common anode, dynamic scan, Arduino shield pins AN[3:0] and SEGMENT[7:0]. Shows difficulty level instead of scores.
- **LEDs**: 8 active-high LEDs on Arduino shield (AF24, AE21, Y22, Y23, AA23, Y25, AB26, W23).
- **VGA**: 12-bit color (R4G4B4), pins as defined in constraints file; `vgac.v` module provided by the course handles synchronization.
- **Simulation**: Temporarily reduce `TICK_MAX`, `SCORE_TIMEOUT`, and `SCAN_MAX` in `defines.vh` to small values (e.g., 10) for quick waveform observation; restore before synthesis.

## References
- Course-provided VGA driver (`vgac.v`) and PS/2 example code (Pan-Ziyue's design).
- Logisim used for auxiliary circuit design (e.g., 7-segment decoder).

## Contributors
Chuanyu Wang, Sihang Qi
