# Pong Game on FPGA

## Project Information
- **Course**: Digital Logic Design
- **Platform**: Sword Kintex 7 FPGA (SWORD-002: Basic I/O Ver 2.0 / 2017-02-24)
- **Language**: Verilog HDL
- **Tools**: Xilinx Vivado, Logisim (auxiliary)
- **Team**: 2 members

## License & Usage Notice

This repository is made public for portfolio and reference purposes only. **No license** is granted — all rights are reserved by the contributors.

If you are a student enrolled in **Zhejiang University's "Digital Logic Design" course**, or any other course with similar content, you are **not permitted** to copy, submit, or incorporate any part of this code into your own coursework, unless this repository or its code is explicitly cited as a demonstration by the course instructor. At most, you may refer to the architecture and ideas presented here for inspiration.

Violation of academic integrity policies is solely your own responsibility.

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

---

# 中文版说明

## 项目信息
- **课程**：数字逻辑设计
- **平台**：Sword Kintex 7 FPGA（SWORD-002：Basic I/O Ver 2.0 / 2017-02-24）
- **语言**：Verilog HDL
- **工具**：Xilinx Vivado、Logisim（辅助）
- **团队成员**：2人

## 许可与使用声明

本仓库公开仅用于作品展示与参考。**未授予任何开源许可**——所有权利由贡献者保留。

如果你是**浙江大学《数字逻辑设计》课程**或任何其他内容相似课程的在读学生，**不得**将本仓库中的任何代码复制、提交或融入到你的课程作业中，除非本仓库或其代码已被课程教师明确引用为教学示范。最多只能参考其中的架构和设计思路。

因违反学术诚信规定而产生的一切后果由行为人自行承担。

## 项目目标
在 FPGA 上复刻经典街机游戏 **Pong**，支持双人对战和简单的 AI 对手。画面通过 VGA 显示器以 640×480@60Hz 输出，可通过板载矩阵键盘或 USB 键盘（PS/2）控制，被动蜂鸣器提供音效。

## 已实现功能

### 核心功能
- 6 状态游戏状态机（空闲、发球、游戏中、暂停、记分、游戏结束）
- 两个挡板通过按键/键盘控制，球在上下边界反弹
- 球碰到挡板时的反弹角度由击中位置决定（5 级：-2 到 +2）
- 未接到球则对方得一分，先得 11 分获胜
- 四个难度级别（Easy / Hard / Master / Auto），通过拨码开关 SW[3:2] 选择
  - **Easy**：约 60 Hz 游戏时钟，挡板 360 px/s
  - **Hard**：约 120 Hz 游戏时钟，挡板 480 px/s
  - **Master**：约 180 Hz 游戏时钟，挡板 540 px/s
  - **Auto**：从 Easy 速度开始，每碰一次挡板速度×1.1，无上限
- 数码管显示当前难度（EASy、HArd、|St、AUtO）
- 8 个 LED 指示游戏状态和发球方

### 扩展功能
- **VGA 显示**：完整游戏画面，含挡板、球、中线、记分
- **球尾迹**：球后 3 帧残影，亮度递减（t-3：暗，t-1：亮）
- **宽挡板道具**：绿色菱形交替出现在左/右挡板侧（约 8 秒冷却）。拾取后挡板上下各延长 5 像素，持续约 5 秒（灰色延长段可视化）
- **PS/2 键盘**：USB 键盘输入（W/S 控制左挡板，↑/↓ 控制右挡板，Enter/Space 开始/暂停，Esc 软复位）；与板载矩阵键盘并行工作
- **蜂鸣器音效**：碰挡板、得分、游戏结束三种不同频率音调
- **单人 AI**：右挡板自动追踪球的 Y 坐标，带有 60 px 死区、随机更新延迟和方向感知行为（球远离时向中央漂移）

### 近期改进
- **挡板速度与游戏时钟解耦**：每 tick 的挡板位移与难度成反比，保持等效速度合理。旧行为将挡板速度绑定到游戏时钟频率，导致 Easy 模式下挡板极慢（120 px/s）
- **修复上边界下溢**：挡板边界检查改用无符号算术防止减法回绕，避免挡板从屏幕顶端消失
- **PS/2 数据同步**：数据线采用两级触发器抗 metastability
- **球尾迹**：3 帧残影亮度递减，视觉上更平滑
- **宽挡板道具**：每约 8 秒在挡板侧交替生成绿色菱形；拾取后上下各延长 5 像素，持续约 5 秒

## 文件结构
```
Pong_Project/
├── README.md
├── CONTRIBUTORS.md
├── docs/
│   └── Final_Report.pdf
├── source_code/
│   ├── defines.vh              # 全局宏定义
│   ├── Top.v                   # 顶层模块
│   ├── clk_wiz.v               # Clocking Wizard 包装器（25.175 MHz）— Vivado IP Catalog 核心
│   ├── game_logic.v            # 状态机、球物理、挡板控制、AI 集成
│   ├── ai_paddle.v             # AI 对手逻辑
│   ├── vga_render.v            # VGA 图像生成器
│   ├── keypad_scanner.v        # 5×4 矩阵键盘扫描
│   ├── ps2_keyboard.v          # PS/2 键盘接收器（修改自潘子悦代码）
│   ├── input_merger.v          # 矩阵键盘与 PS/2 输入合并
│   ├── seg_display.v           # 4 位数码管驱动（显示难度）
│   ├── led_status.v            # LED 状态指示
│   ├── powerup_ctrl.v          # 宽挡板道具控制器
│   └── buzzer_ctrl.v           # 被动蜂鸣器音调生成
├── sim/
│   ├── tb_game_logic.v
│   ├── tb_seg_display.v
│   ├── tb_ai_paddle.v
│   └── ...
├── constraints/
│   └── pong.xdc
└── vivado_project/
    ├── pong_top.bit
    └── Project/                # 整理后的 Vivado 项目
```

## 控制方式

### 板载矩阵键盘
| 按键 | 功能 |
|------|------|
| 第 0 行第 0 列 | 开始 / 暂停 |
| 第 4 行第 0–3 列 | 左挡板上下、右挡板上下 |

### PS/2 USB 键盘
| 按键 | 功能 |
|------|------|
| **W** / **S** | 左挡板 上 / 下 |
| **↑** / **↓** | 右挡板 上 / 下 |
| **Enter** / **Space** | 开始 / 暂停 |
| **Esc** | 软复位（回到空闲状态，清除分数） |

两种输入源通过 `input_merger.v` 的 OR 逻辑并行工作。

### 拨码开关
| 开关 | 功能 |
|------|------|
| SW[0] | 系统复位（高电平有效） |
| SW[1] | AI 使能（0 = 双人对战，1 = AI 控制右挡板） |
| SW[3:2] | 难度：00=Easy，01=Hard，10=Master，11=Auto |

## 球物理与挡板交互

### 反弹角度
球的反弹角度由碰撞时球心与挡板中心的垂直偏移决定：

| 偏移（ball_y - paddle_center_y） | 方向 | 速度 (dx, dy) |
|---|---|---|
| > 20 px | 微向下 | (4, +2) |
| > 5 px | 略向下 | (5, +1) |
| -5 ~ +5 px | 水平 | (5, 0) |
| < -5 px | 略向上 | (5, -1) |
| < -20 px | 微向上 | (4, -2) |

速度查找表保持总速率大致恒定（|V|≈5）。

### 发球方向
- 初始发球向右（朝向右侧挡板）
- 得分后，失分方发球（朝向得分方）
- 发球角度通过自由运行计数器从 7 个选项中随机选择

## 团队分工
- **成员 A**：游戏状态机、球物理、AI、数码管显示、蜂鸣器、顶层集成
- **成员 B**：矩阵键盘、PS/2 接口、VGA 渲染、字库 ROM、LED 指示、约束文件
- **共同**：仿真、调试、设计报告

## 硬件说明
- **时钟**：板载 100 MHz 振荡器；MMCM 生成 25.175 MHz 供 VGA 和游戏逻辑使用。MMCM 通过 Vivado IP Catalog（Clocking Wizard）配置 — clk_wiz.v 是对生成 IP 内核的包装器。重建项目时需在 Vivado 中重新生成 IP 或自行实现时钟分频。
- **矩阵键盘**：5 行（V17, W18, W19, W15, W16）× 4 列（V18, V19, V14, W14），低电平有效扫描，列线上拉。
- **PS/2**：USB 键盘通过板载转换器支持；引脚 N18（时钟）和 M19（数据）。识别的按键码：W（0x1D）、S（0x1B）、Space（0x29）、Enter（0x5A）、Esc（0x76）、↑（0xE0 0x75）、↓（0xE0 0x72）。
- **蜂鸣器**：被动压电式蜂鸣器（AF25），需输出相应频率方波。
- **数码管**：共阳极、动态扫描，Arduino 扩展板引脚 AN[3:0] 和 SEGMENT[7:0]。显示难度而非分数。
- **LED**：Arduino 扩展板上的 8 个高电平有效 LED（AF24, AE21, Y22, Y23, AA23, Y25, AB26, W23）。
- **VGA**：12 位色（R4G4B4），引脚定义见约束文件；课程提供的 `vgac.v` 模块负责同步时序。
- **仿真**：临时将 `defines.vh` 中的 `TICK_MAX`、`SCORE_TIMEOUT` 和 `SCAN_MAX` 改小（如 10）以快速观察波形，综合前恢复原值。

## 参考资料
- 课程提供的 VGA 驱动（`vgac.v`）和 PS/2 示例代码（Pan-Ziyue's design）
- Logisim 用于辅助电路设计（如数码管译码器）

## 贡献者
王传宇、齐思航
