# Pong Game on FPGA

## 项目信息
- **课程**: 数字逻辑设计  
- **平台**: Sword Kintex 7 FPGA (SWORD4)  
- **语言**: Verilog HDL / System Verilog  
- **工具**: Xilinx Vivado, Logisim (辅助)  
- **小组**: 2 人

## 项目目标
复刻经典游戏 **Pong**，实现双人对战和简单人机对战，并在 VGA 显示器上输出 640×480@60Hz 图像，通过板载键盘或 USB 键盘控制球拍。

## 已实现功能

### 核心功能
- 6 状态游戏状态机（待机、发球、游戏中、暂停、得分、结束）
- 两个球拍可通过按钮/键盘上下移动，球在屏幕内反弹
- 碰到球拍反弹，飞出左右边界对方得分，先得 11 分获胜
- 七段数码管动态显示双方比分
- 8 个 LED 指示游戏状态和发球方
- 使用寄存器阵列存储球坐标、球拍位置和比分（RAM 行为）
- 使用 ROM 存储数字字模，供 VGA 显示比分

### 扩展功能
- **VGA 显示**: 完整游戏画面（球拍、球、中线、比分）
- **PS/2 键盘**: 支持 USB 键盘（W/S 控制左拍，↑/↓ 控制右拍，Enter 开始/暂停），与板载矩阵键盘并行使用
- **蜂鸣器音效**: 击球、得分、游戏结束时发出不同频率提示音
- **单人 AI**: 右侧球拍自动追踪球的 Y 坐标，实现人机对战

## 文件结构

```
Pong_Project/
├── README.md
├── CONTRIBUTORS.md
├── docs/
|   ├── wave_images/       # 波形图图片
│   └── Final_Report.pdf   # 设计报告
├── source_code/           # 所有可综合的 Verilog 源码
│   ├── defines.vh         # 全局宏定义（屏幕尺寸、球拍大小等）
│   ├── Top.v              # 顶层模块
│   ├── clk_wiz.v          # 时钟 IP 例化（25.175MHz）
│   ├── game_logic.v       # 主状态机 + 球物理 + 碰撞检测
|   ├── ai_paddle.v        # 单人模式下的AI决策
│   ├── vga_render.v       # VGA 图像生成（根据坐标输出 RGB）
│   ├── keypad_scanner.v   # 5×4 矩阵键盘扫描
│   ├── ps2_keyboard.v     # PS/2 键盘接收（修改自潘学长代码）
│   ├── input_merger.v     # 矩阵键盘与 PS/2 输入合并
│   ├── seg_display.v      # 4 位数码管动态扫描
│   ├── led_status.v       # LED 状态指示
│   ├── buzzer_ctrl.v      # 蜂鸣器控制
│   └── font_rom.v         # 数字字模 ROM
├── sim/                   # 仿真文件（Testbench）
│   ├── tb_game_logic.v
│   ├── tb_vga_render.v
│   ├── tb_keypad_scanner.v
│   ├── tb_ps2_keyboard.v
|   └── wave_configs/      # 波形配置文件
├── constraints/
│   └── pong.xdc           # 引脚与时序约束
└── vivado_project/        # Vivado 工程（重置后）
    ├── pong_top.bit
    └── Project/
```

## 分工概况
- **成员 A**: 游戏状态机、球物理、AI、七段管、蜂鸣器、顶层集成
- **成员 B**: 矩阵键盘、PS/2 接口、VGA 图形生成、LED 指示、约束文件
- **共同**: 仿真调试、设计报告

## 注意事项
- 主时钟 100MHz，需用 MMCM 生成 25.175MHz 供 VGA 和游戏逻辑
- 矩阵键盘 5 行 × 4 列，低电平扫描，列内部上拉
- 七段管和 Arduino LED 使用 Arduino 子板资源
- PS/2 接口对应 USB 键盘，通过板上转换电路连接