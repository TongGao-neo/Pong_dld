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
- Ball reflects off paddles; missed ball awards a point to opponent
- First to 11 points wins
- Seven-segment display dynamically shows both players' scores
- 8 LEDs indicate game state and serving side
- Register arrays store ball coordinates, paddle positions, and scores (RAM behavior)
- ROM stores digit bitmaps for score display on VGA

### Extended Features
- **VGA Display**: Full game screen with paddles, ball, center line, and scores
- **PS/2 Keyboard**: USB keyboard input (W/S for left paddle, ↑/↓ for right paddle, Enter to start/pause); works in parallel with onboard matrix keyboard
- **Buzzer Sound Effects**: Different tone frequencies for paddle hit, scoring, and game over events
- **Single-player AI**: Right paddle automatically tracks the ball's Y coordinate with a dead zone

## File Structure
```
Pong_Project/
├── README.md
├── CONTRIBUTORS.md
├── docs/
│   └── Final_Report.pdf
├── source_code/
│   ├── defines.vh              # Global macro definitions
│   ├── Top.v              # Top-level module
│   ├── clk_wiz.v               # Clocking Wizard wrapper (25.175 MHz)
│   ├── game_logic.v            # State machine, ball physics, paddle control, AI integration
│   ├── ai_paddle.v             # AI opponent logic
│   ├── vga_render.v            # VGA image generator (pixel color from coordinates)
│   ├── keypad_scanner.v        # 5×4 matrix keyboard scanner
│   ├── ps2_keyboard.v          # PS/2 keyboard receiver (modified from Pan's code)
│   ├── input_merger.v          # Merges matrix and PS/2 inputs
│   ├── seg_display.v           # 4-digit 7-segment driver
│   ├── led_status.v            # LED status indicator
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

## Team Division
- **Member A**: Game state machine, ball physics, AI, seven-segment display, buzzer, top-level integration
- **Member B**: Matrix keyboard, PS/2 interface, VGA rendering, font ROM, LED indicator, constraints
- **Joint**: Simulation, debugging, design report

## Hardware Notes
- **Clock**: 100 MHz onboard oscillator; MMCM generates 25.175 MHz for VGA and game logic.
- **Matrix Keyboard**: 5 rows (V17, W18, W19, W15, W16) × 4 columns (V18, V19, V14, W14), active-low scan with pull-up on columns.
- **PS/2**: USB keyboard supported via onboard converter; pins N18 (clock) and M19 (data).
- **Buzzer**: Passive piezoelectric buzzer (AF25), requires square wave of appropriate frequency for sound.
- **7-Segment**: Common anode, dynamic scan, Arduino shield pins AN[3:0] and SEGMENT[7:0].
- **LEDs**: 8 active-high LEDs on Arduino shield (AF24, AE21, Y22, Y23, AA23, Y25, AB26, W23).
- **VGA**: 12-bit color (R4G4B4), pins as defined in constraints file; `vgac.v` module provided by the course handles synchronization.
- **Simulation**: Temporarily reduce `TICK_MAX`, `SCORE_TIMEOUT`, and `SCAN_MAX` in `defines.vh` to small values (e.g., 10) for quick waveform observation; restore before synthesis.

## References
- Course-provided VGA driver (`vgac.v`) and PS/2 example code (Pan-Ziyue's design).
- Logisim used for auxiliary circuit design (e.g., 7-segment decoder).

## Contributors
Chuanyu Wang, Sihang Qi

# FPGA 乒乓球游戏 (Pong)

## 项目信息
- **课程**: 数字逻辑设计  
- **平台**: Sword Kintex 7 FPGA（SWORD-002: Basic I/O Ver 2.0 / 2017-02-24）  
- **开发语言**: Verilog HDL  
- **开发工具**: Xilinx Vivado、Logisim（辅助）  
- **小组**: 2 人

## 项目目标
在 FPGA 上复现经典街机游戏 **Pong**，支持双人对战与简单 AI 对手。游戏通过 VGA 显示器 640×480@60Hz 输出画面，可使用板载矩阵键盘或 USB 键盘（PS/2 接口）控制球拍，并由无源蜂鸣器提供音效。

## 已实现功能

### 核心功能
- 6 状态游戏状态机（待机、发球、对打、暂停、得分、结束）
- 两个球拍由按键/键盘控制上下移动，球碰上下边界反弹
- 球碰到球拍反弹，球飞出左右边界对方得分
- 先到 11 分者获胜
- 七段数码管动态显示双方比分
- 8 个 LED 指示游戏状态和发球方
- 使用寄存器阵列存储球坐标、球拍位置和比分（RAM 行为）
- ROM 存储数字字模，用于 VGA 显示比分

### 扩展功能
- **VGA 显示**：完整游戏画面（球拍、球、中线、比分）
- **PS/2 键盘**：支持 USB 键盘（W/S 控制左拍，↑/↓ 控制右拍，Enter 开始/暂停），与板载矩阵键盘并行使用
- **蜂鸣器音效**：击球、得分、游戏结束时发出不同频率提示音
- **单人 AI**：右侧球拍自动追踪球的 Y 坐标，并带有死区避免抖动

## 文件结构
```
Pong_Project/
├── README.md
├── CONTRIBUTORS.md
├── docs/
│   └── Final_Report.pdf
├── source_code/
│   ├── defines.vh              # 全局宏定义
│   ├── Top.v              # 顶层模块
│   ├── clk_wiz.v               # 时钟向导封装（25.175MHz）
│   ├── game_logic.v            # 状态机、球物理、球拍控制、AI 集成
│   ├── ai_paddle.v             # AI 对手逻辑
│   ├── vga_render.v            # VGA 图像生成（根据坐标输出像素颜色）
│   ├── keypad_scanner.v        # 5×4 矩阵键盘扫描
│   ├── ps2_keyboard.v          # PS/2 键盘接收（改编自潘学长代码）
│   ├── input_merger.v          # 矩阵键盘与 PS/2 输入合并
│   ├── seg_display.v           # 4 位数码管动态扫描
│   ├── led_status.v            # LED 状态指示
│   └── buzzer_ctrl.v           # 无源蜂鸣器音调生成
├── sim/
│   ├── tb_game_logic.v
│   ├── tb_seg_display.v
│   ├── tb_ai_paddle.v
│   └── ...
├── constraints/
│   └── pong.xdc
└── vivado_project/
    ├── pong_top.bit
    └── Project/                # 清理后的 Vivado 工程
```

## 分工
- **成员 A**: 游戏状态机、球物理、AI、七段管、蜂鸣器、顶层集成
- **成员 B**: 矩阵键盘、PS/2 接口、VGA 渲染、字模 ROM、LED 指示、约束文件
- **共同**: 仿真调试、设计报告

## 硬件注意事项
- **时钟**: 板载 100MHz 晶振；通过 MMCM 产生 25.175MHz 供 VGA 和游戏逻辑。
- **矩阵键盘**: 5 行（V17, W18, W19, W15, W16）× 4 列（V18, V19, V14, W14），低电平扫描，列内部上拉。
- **PS/2**: 支持 USB 键盘，使用板载转换电路；引脚 N18（时钟）、M19（数据）。
- **蜂鸣器**: 无源压电蜂鸣器（AF25），需提供一定频率的方波才能发声。
- **七段数码管**: 共阳极，动态扫描，Arduino 子板引脚 AN[3:0] 和 SEGMENT[7:0]。
- **LED**: Arduino 子板上 8 个高电平有效的 LED（AF24, AE21, Y22, Y23, AA23, Y25, AB26, W23）。
- **VGA**: 12 位色（R4G4B4），引脚见约束文件；同步时序由课程提供的 `vgac.v` 模块实现。
- **仿真**: 仿真时需将 `defines.vh` 中的 `TICK_MAX`、`SCORE_TIMEOUT`、`SCAN_MAX` 暂时改为小值（例如 10），以便快速观察波形；综合前恢复原值。

## 参考资料
- 课程提供的 VGA 驱动模块（`vgac.v`）及 PS/2 示例代码（潘子悦同学设计）
- 使用 Logisim 辅助部分电路设计（如七段译码器）

## 贡献者
王传宇，齐思航