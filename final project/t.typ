本项目是一个基于 Verilog HDL 的经典 Pong 乒乓球游戏，运行在 Sword Kintex 7 FPGA 开发板上。系统采用 640×480 60Hz VGA 显示，支持矩阵键盘和 PS/2 键盘双输入，具有 AI 对手、多种难度、道具系统、音效、七段数码管和 LED 状态指示等功能。

整个设计由 14 个源文件组成，采用模块化层次结构，顶层模块 `Top.v` 连接所有子模块。下面逐一详细解释每个模块的原理。


== 1. defines.vh — 全局宏定义头文件 

`defines.vh` 是全项目的"参数中枢"，使用 Verilog 宏（define）定义了所有关键常量，目的在于：
- 统一管理：修改一处即可全局生效（如球大小、分数上限等）
- *避免魔术数字*：代码中不出现"裸数字"，全部用有意义的宏名

主要宏定义分类：

#table(
  columns: (auto, auto, auto),
  align: left,
  table.header([*类别*], [*宏名示例*], [*作用*]),
  [显示几何], [`SCREEN_W/H`], [VGA 分辨率 640×480],
  [挡板参数], [`PADDLE_W/H`, `LEFT/RIGHT_PADDLE_X`], [挡板宽10px、高80px、左右各距边界20px],
  [球参数], [`BALL_SIZE`], [球为 8×8 正方形],
  [游戏规则], [`MAX_SCORE`], [先得 11 分者获胜],
  [AI 参数], [`AI_DEAD_ZONE`, `AI_UPDATE_BASE/RANGE`], [死区60px、更新间隔24+随机0~15帧],
  [难度等级], [`TICK_THRESH_SPEED1~5`], [控制 game_tick 频率：60Hz / 120Hz / 180Hz / 240Hz / 300Hz],
  [计时参数], [`TICK_MAX`, `SCORE_TIMEOUT`, `SERVE_TIMEOUT`], [game_tick 周期约419583时钟≈60Hz；得分后暂停60帧≈1s；自动发球超时60帧],
  [数码管扫描], [`SCAN_MAX`], [25.175MHz / 6294 ≈ 4kHz 扫描频率],
  [文字缩放], [`TEXT_SCALE`], [GAME OVER 字体放大系数，2 = 16×32px/字符],
)

*game_tick 机制原理*：系统时钟 25.175MHz 过快，不能每帧都移动球。因此用一个计数器 `tick_counter` 从 0 计数到 `TICK_MAX`，仅在计满时产生一个 `game_tick` 脉冲（约60Hz）。球和挡板只在 `game_tick` 有效时移动，从而将物理速率解耦于时钟频率。

---

=== 2. Top.v — 顶层模块 ===

`Top.v` 是整个系统的最高层，负责：
- *时钟生成*：调用 `clk_wiz` 将 100MHz 主时钟转为 25.175MHz VGA 像素时钟
- *复位管理*：双级同步器 `rst_s1 → rst_s2 → rst_n`，确保 PLL 锁定和 SW[0] 开关复位信号同步释放
- *模块例化与连接*：像"主板"一样把所有子模块连在一起

#figure(
  rect(
    width: 100%,
    inset: 12pt,
    align(center)[
      `clk(100MHz)` → `clk_wiz` → `clk_25m(25.175MHz)` \
      `SW[0]` + `pll_locked` → 同步复位 `rst_n` \
      \
      `keypad_scanner`  ↘ \
      `ps2_keyboard`    → `input_merger` → `game_logic` → `vga_render` → `vgac` → VGA输出 \
                              ↘ `buzzer_ctrl` → 蜂鸣器 \
                              ↘ `led_status` → LED \
                              ↘ `seg_display` → 七段数码管 \
      `powerup_ctrl` ← `game_logic.game_tick` → `game_logic`
    ]
  ),
  caption: [系统模块连接关系]
)

关键信号流：
- *输入路径*：矩阵键盘/PS/2键盘 → `input_merger`（OR逻辑合并）→ `game_logic`
- *游戏路径*：`game_logic` 输出球坐标、挡板坐标、分数、状态 → `vga_render` 生成像素 → `vgac` 输出时序和颜色
- *外设路径*：`game_logic` 的事件脉冲 → `buzzer_ctrl`（声音）/ `led_status`（LED指示）/ `seg_display`（难度显示）
- *开关信号*：`SW[1]`=AI使能，`SW[3:2]`=难度选择

---

=== 3. game_logic.v — 游戏逻辑核心状态机 ===

这是整个项目最核心的模块，实现了一个有限状态机（FSM）控制游戏流程，并包含球的物理运动和碰撞检测。

==== 3.1 状态机设计 ====

状态机共有 6 个状态：

#table(
  columns: (auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*状态*], [*编码*], [*功能*]),
  [`S_IDLE`], [3'd0], [空闲：等待开始，球和挡板居中],
  [`S_SERVE`], [3'd1], [发球：球居中，随机选择发射角度；等待按键或超时自动发球],
  [`S_PLAY`], [3'd2], [游戏进行：球移动、碰撞检测、挡板控制],
  [`S_PAUSE`], [3'd3], [暂停：一切冻结，等待继续],
  [`S_SCORE`], [3'd4], [得分暂停：约1秒后回到发球],
  [`S_OVER`], [3'd5], [游戏结束：显示 GAME OVER，等待按键重置],
)

状态转移：
- `IDLE` → (按开始) → `SERVE` → (按开始/超时) → `PLAY` → (按开始) → `PAUSE` → (按开始) → `PLAY`
- `PLAY` → (球出界) → `SCORE` → (超时) → `SERVE`
- `PLAY` → (球出界+满11分) → `OVER` → (按开始) → `IDLE`
- 任意状态 → (Esc软复位) → `IDLE`

==== 3.2 game_tick 分频 ====

使用 19 位计数器 `tick_counter`，从 0 计数到 `tick_threshold`。`tick_threshold` 根据难度设定不同值：
- Easy: 419583 → 约 60Hz
- Hard: 209791 → 约 120Hz
- Master: 139861 → 约 180Hz
- Auto: 初始60Hz，每次击球乘以 ×(10/11)，即加速约 1.1 倍

==== 3.3 球运动与碰撞 ====

- *速度表示*：`ball_dx`（水平速度）和 `ball_dy`（垂直速度）均为 11 位有符号数，支持负方向
- *位置更新*：`next_x_s = ball_x + ball_dx`，`next_y_s = ball_y + ball_dy`，使用有符号运算避免溢出

*碰撞检测逻辑*：

1. **上下边界反弹**：当 `next_y_s ≤ 0` 或 `next_y_s ≥ 464` 时，`ball_dy` 取反
2. **左挡板碰撞**：当球右缘进入左挡板区域 (`next_x_s ≤ 30 && next_x_s + 8 ≥ 20`) 且 Y 坐标与挡板重叠时触发
3. **右挡板碰撞**：类似，检测球左缘与右挡板 (`next_x_s + 8 ≥ 610 && next_x_s ≤ 620`) 的重叠
4. **出界得分**：若球未碰挡板且 `next_x_s ≤ 0`（右方得分）或 `next_x_s + 8 ≥ 640`（左方得分）

==== 3.4 反弹角度计算 ====

碰撞时根据球心与挡板中心的偏移量确定反弹角度：

#table(
  columns: (auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*偏移量*], [*角度索引*], [*效果*]),
  [> 20px], [±2], [大角度：dx=4, dy=±2],
  [> 5px], [±1], [中角度：dx=5, dy=±1],
  [-5 ~ +5px], [0], [水平：dx=5, dy=0],
  [ < - 5px], [-1], [中角度反向],
  [ < - 20px], [-2], [大角度反向],
)

通过查找表（`velocity lookup table`）将角度索引映射为 `(vel_dx_mag, vel_dy)`，确保球速总量约恒定（|V|≈5），避免某些角度过快或过慢。

==== 3.5 宽挡板道具（Powerup） ====

当 `pw_hit_left` 或 `pw_hit_right` 脉冲到来时，`wide_timer` 设为 300 个 game_tick（约5秒），期间挡板上下各扩展5像素（灰色显示）。

==== 3.6 难度与挡板速度 ====

挡板速度也随难度缩放，但步长×频率保持"等效速度"合理：
- Easy: 6px/帧 × 60Hz = 360 px/s
- Hard: 4px/帧 × 120Hz = 480 px/s
- Master: 3px/帧 × 180Hz = 540 px/s

==== 3.7 边沿检测 ====

`start_pause` 和 `soft_reset` 信号需要边沿检测（`start_pause_d` 延迟一拍后比较），确保一次按键只触发一次状态转换，而不是连续触发。

---

=== 4. vga_render.v — VGA 图像渲染 ===

`vga_render` 是"画师"模块，根据当前扫描到的像素坐标和各种游戏对象坐标，逐像素计算颜色输出。

==== 4.1 球的拖尾效果 ====

使用三级移位寄存器保存球的前三帧位置：
```
game_tick 有效时：
  bx1 <= ball_x（当前帧）→ bx2 <= bx1（前一帧）→ bx3 <= bx2（前两帧）
```
渲染时按优先级叠加：
- `bx3/by3`：最暗拖尾（`12'h333`，深灰）
- `bx2/by2`：中等拖尾（`12'h777`，中灰）
- `bx1/by1`：较亮拖尾（`12'hBBB`，浅灰）
- `ball_x/ball_y`：当前球（`12'hFFF`，白色，覆盖拖尾）

==== 4.2 分数数字显示 ====

每个数字由 16 行 × 8 列的位图（bitmap）表示，存储在 `digit_bitmap` 寄存器数组中。0~9 的位图是硬编码的点阵字体 ROM。

显示位置：
- 左方分数十位：(200, 30)，个位：(216, 30)
- 右方分数十位：(408, 30)，个位：(424, 30)

渲染逻辑：判断当前像素是否落在某个数字区域内 → 计算行内偏移和列内偏移 → 从位图中取出对应位 → 决定是白还是黑。

==== 4.3 GAME OVER 文字 ====

"GAME OVER" 由 9 个字符（含空格）组成，每个字符也是 8×16 点阵字体。通过 `TEXT_SCALE` 宏（=2）将每个字符放大到 16×32 像素。

居中计算：
- `GAMEOVER_W = 9 × 16 = 144px`
- `GAMEOVER_X = (640 - 144) / 2 = 248`
- `GAMEOVER_Y = (480 - 32) / 2 = 224`

仅在 `game_state == S_OVER` 时显示，优先级最高。

==== 4.4 渲染优先级 ====

从低到高叠加（后写的覆盖先写的）：
1. 黑色背景
2. 中线虚线（`col 318~320`，`row[3:0] < 8`)
3. 球拖尾（由暗到亮）
4. 当前球（白色）
5. 挡板（白色主体 + 灰色扩展部分）
6. 道具菱形（绿色，去角）
7. 分数数字（白色）
8. GAME OVER 文字（白色，最高优先级）

---

=== 5. vgac.v — VGA 时序控制器 ===

`vgac.v` 是 VGA 信号的"行场同步发生器"，产生标准的 640×480 @60Hz VGA 时序。

==== 5.1 计数器 ====

- `h_count`：水平计数器，0~799（共800个时钟周期，含消隐区）
- `v_count`：垂直计数器，0~524（共525行，含消隐区）

`h_count` 每 25.175MHz 时钟加1，到 799 归零；每当 `h_count` 归零时 `v_count` 加1。

==== 5.2 同步信号 ====

- 行同步 `hs`：`h_count > 95` 时为高（同步脉宽96像素）
- 场同步 `vs`：`v_count > 1` 时为高（同步脉宽2行）
- 显示使能 `rdn`（低有效）：当 `143 < h_count < 783` 且 `34 < v_count < 515` 时有效（即 640×480 可见区域）

==== 5.3 坐标输出 ====

- `row_addr = v_count - 35`（减去消隐区偏移，得到 0~479）
- `col_addr = h_count - 144`（减去消隐区偏移，得到 0~639）

==== 5.4 颜色输出 ====

12位输入 `d_in = {B[3:0], G[3:0], R[3:0]}`，仅在 `rdn=0`（可见区域）时输出到 RGB 引脚，消隐区输出 0。

---

=== 6. ai_paddle.v — AI 对手 ===

实现一个简单但有趣的 AI 对手来控制右挡板。

==== 6.1 追踪与死区 ====

- 计算球的中心 Y 和挡板中心 Y
- 死区 `AI_DEAD_ZONE = 60px`：当球中心在挡板中心 ±60px 范围内时，AI 不主动追踪
- 死区外：球在上方则 `move_up`，球在下方则 `move_down`

==== 6.2 随机延迟 ====

- 自由运行计数器 `rand_cnt` 不断递增
- `update_timer` 从 `(AI_UPDATE_BASE + rand_cnt[3:0])` 倒数到 0
- 仅当 `update_timer == 0` 时 AI 才重新采样球位置并决策
- 这使 AI 表现"犹豫"，降低难度

==== 6.3 空闲振荡 ====

当球远离或球在死区内时，AI 进行小幅上下振荡（`osc_phase` 每32帧翻转方向），模拟"活"的表现而不会呆立不动。

==== 6.4 回中行为 ====

当球远离 AI 时，挡板缓慢回到屏幕中心（Y=240），为下次防守做准备。

---

=== 7. ps2_keyboard.v — PS/2 键盘接口 ===

实现 PS/2 协议的接收端，解析键盘扫描码并映射为游戏控制信号。

==== 7.1 PS/2 协议基础 ====

PS/2 协议是 11 位异步串行协议：
- 1 位起始位（0）
- 8 位数据位（LSB first）
- 1 位奇校验位
- 1 位停止位（1）

数据在 PS/2 时钟的下降沿采样。

==== 7.2 下降沿检测 ====

使用三级同步器 `ps2_clk_s0 → s1 → s2`：
- 第一级：消除亚稳态
- `neg_edge_ps2_clk = !s1 && s2`：检测下降沿

数据线同样经过两级同步 `ps2_data_s0 → s1`。

==== 7.3 帧接收 ====

`bit_cnt` 从 0 计数到 10：
- `bit_cnt=0`：跳过起始位
- `bit_cnt=1~8`：将数据位移入 `shift_reg`
- `bit_cnt=9`：跳过校验位
- `bit_cnt=10`：帧完成，产生 `frame_done` 脉冲

==== 7.4 扫描码解码 ====

PS/2 键盘使用"Make/Break"机制：
- 按键按下：发送 Make 码（如 W=`0x1D`）
- 按键释放：发送 `0xF0` + Make 码（Break 序列）
- 扩展键（方向键等）：前缀 `0xE0`

状态变量：
- `is_extended`：收到 `0xE0` 前缀标志
- `is_break`：收到 `0xF0` 前缀标志
- `key_valid`：解码完成脉冲

==== 7.5 键位映射 ====

#table(
  columns: (auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*按键*], [*扫描码*], [*功能*]),
  [W], [`0x1D`], [左挡板上移],
  [S], [`0x1B`], [左挡板下移],
  [↑ (E0,75)], [`E0 75`], [右挡板上移],
  [↓ (E0,72)], [`E0 72`], [右挡板下移],
  [Space], [`0x29`], [开始/暂停],
  [Enter], [`0x5A`], [开始/暂停],
  [Esc], [`0x76`], [软复位],
)

当收到 Make 码时对应信号置1，收到 Break 码时置0。

---

=== 8. keypad_scanner.v — 矩阵键盘扫描器 ===

实现 5×4 矩阵键盘的逐行扫描和去抖动。

==== 8.1 工作原理 ====

矩阵键盘有5行4列共20个交叉点：
- *行线*（`key_row`）：输出，由 FPGA 驱动，逐行拉低（active low）
- *列线*（`key_col`）：输入，有内部上拉电阻，默认高电平
- 当某行被拉低时，若该行某列的按键被按下，对应列线变为低

==== 8.2 扫描时序 ====

- 扫描周期：每行持续约 1ms（`SCAN_DELAY = 5035` 个 25.175MHz 时钟周期）
- 5行总扫描周期约 5ms，扫描频率 200Hz

行驱动采用独热编码：`5'b11110`（Row0有效）→ `5'b11101`（Row1）→ ... → `5'b01111`（Row4）。

==== 8.3 去抖动 ====

机械按键在按下/释放时会产生弹性抖动（约5~20ms），需要滤除。

采用递增/递减计数器去抖动：
- 按键按下（列线低）：计数器递增
- 按键释放（列线高）：计数器递减
- 计数器达到 `DEBOUNCE_CNT=8` 时判定为按下
- 计数器降为0时判定为释放

8 次连续一致的采样 × 5ms/次 = 40ms 去抖动时间，足够滤除抖动。

==== 8.4 按键映射 ====

#table(
  columns: (auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*行*], [*列*], [*功能*]),
  [Row 4], [Col 0], [left_down],
  [Row 4], [Col 1], [left_up],
  [Row 4], [Col 2], [right_down],
  [Row 4], [Col 3], [right_up],
  [Row 0], [Col 0], [start_pause],
)

---

=== 9. input_merger.v — 输入合并器 ===

这是一个纯组合逻辑模块，使用 OR 运算将矩阵键盘和 PS/2 键盘的信号合并：

```
left_up     = kp_left_up     | ps2_left_up
left_down   = kp_left_down   | ps2_left_down
right_up    = kp_right_up    | ps2_right_up
right_down  = kp_right_down  | ps2_right_down
start_pause = kp_start       | ps2_start
soft_reset  =                    ps2_soft_reset
```

OR 逻辑的含义：任一输入源按下即视为有效，两种输入可同时使用不冲突。`soft_reset` 仅有 PS/2 的 Esc 键可触发，矩阵键盘无此功能。

---

=== 10. buzzer_ctrl.v — 蜂鸣器音效控制 ===

驱动无源蜂鸣器产生三种不同频率的方波音效。

==== 10.1 音效种类 ====

#table(
  columns: (auto, auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*事件*], [*频率*], [*半周期计数*], [*持续时间*]),
  [击球 hit_paddle], [1000Hz], [12587], [0.2秒],
  [得分 score_event], [1500Hz], [8391], [0.2秒],
  [结束 game_over], [2000Hz], [6293], [0.2秒],
)

==== 10.2 方波生成原理 ====

- `half_period_cnt`：从0计数到 `current_half - 1`
- 计满时 `note_phase` 翻转 → 产生方波
- 方波频率 = 25.175MHz / (2 × current_half)

==== 10.3 边沿检测 ====

游戏逻辑输出的脉冲较宽（约16ms），需要通过延迟一拍进行上升沿检测，将其转换为单时钟周期的窄脉冲，避免重复触发。

==== 10.4 优先级 ====

若多个事件同时到来，游戏结束 > 得分 > 击球，后者覆盖前者的音高设定。

---

=== 11. led_status.v — LED 状态指示 ===

8 个 LED 指示灯映射如下：

#table(
  columns: (auto, auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*LED位*], [*含义*], [*表现*]),
  [0], [空闲 IDLE], [常亮],
  [1], [发球 SERVE], [常亮],
  [2], [游戏中 PLAY], [常亮],
  [3], [发球方], [0=左, 1=右],
  [4], [击球], [快闪],
  [5], [得分], [快闪],
  [6], [暂停 PAUSE], [慢闪 约0.5Hz],
  [7], [游戏结束 OVER], [常亮],
)

闪烁效果通过 `blink_cnt`（24位计数器，计12.5M次≈0.5秒）和 `blink_phase` 实现。

---

=== 12. seg_display.v — 七段数码管显示 ===

4 位共阳极七段数码管显示当前难度模式。

==== 12.1 动态扫描原理 ====

4 位数码管共享 8 根段选线（a~g, dp），通过分时选通实现"视觉暂留"：
- `scan_counter` 计数到 `SCAN_MAX=6293` 产生 `scan_tick`（约4kHz）
- 每次 `scan_tick` 切换到下一位，对应的 `AN` 拉低（选中），同时输出该位字符的段码
- 4位轮流点亮，每位刷新率 ≈ 4kHz / 4 = 1kHz，远超人眼可感知的闪烁频率

==== 12.2 字符编码 ====

共阳极数码管段码为低电平有效（0=亮，1=灭）：
- `SEG_E = 8'b10000110`：显示 "E"
- `SEG_A = 8'b10001000`：显示 "A"
- 等等

==== 12.3 难度显示 ====

#table(
  columns: (auto, auto),
  align: left,
  table.hlines(stroke: 0.5pt),
  table.header([*SW[3:2]*], [*显示*]),
  [00], [EASy],
  [01], [HArd],
  [10], [nSt（半n+半n）],
  [11], [AUtO],
)

---

=== 13. clk_wiz.v — 时钟管理 ===

封装 Xilinx MMCM（混合模式时钟管理器）IP 核 `clk_wiz_0`：
- 输入：100MHz 系统时钟
- 输出：25.175MHz VGA 像素时钟
- `locked` 信号：PLL 锁定后变高，用于复位控制
- `reset` 输入来自 `SW[0]`，可在运行时重新初始化 PLL

25.175MHz 正好是 VGA 640×480@60Hz 所需的像素时钟（像素率 = 25.175MHz ÷ (800 × 525) ≈ 60Hz 帧率）。

---

=== 14. powerup_ctrl.v — 道具控制器 ===

实现"加宽挡板"道具的生成、显示和碰撞检测。

==== 14.1 状态机 ====

两个状态：
- `S_COOLDOWN`（冷却）：等待一段时间后生成新道具
- `S_ACTIVE`（激活）：道具可见，检测碰撞或超时

==== 14.2 冷却时间 ====

- 基础冷却：`COOLDOWN_BASE = 480` 个 game_tick ≈ 8 秒
- 随机附加：`rand_cnt[5:0]`（0~63），总冷却 ≈ 8~9 秒

==== 14.3 道具生成 ====

- *X 位置*：交替出现在左/右挡板区域的中线处
  - 左：`LEFT_PADDLE_X + PADDLE_W/2 = 25`
  - 右：`RIGHT_PADDLE_X + PADDLE_W/2 = 615`
- *Y 位置*：`40 + rand_cnt[9:4] × 4`，范围 40~292，随机化

==== 14.4 碰撞检测 ====

道具为 6×6 像素，检测其与挡板的 Y 范围重叠：
```
(powerup_y + 6) > paddle_y  &&  powerup_y < (paddle_y + PADDLE_H)
```
碰撞后产生 `hit_left` 或 `hit_right` 脉冲，通知 `game_logic` 激活宽挡板。

==== 14.5 道具存活时间 ====

`LIFETIME = 150` 个 game_tick ≈ 2.5 秒，超时后消失进入冷却。

---

== 设计总结 ==

本项目以状态机为核心驱动游戏流程，以 game_tick 机制将物理速率与系统时钟解耦，以逐像素渲染方式生成 VGA 画面。各模块职责清晰、接口简洁，体现了"分而治之"的数字系统设计思想：

- *输入层*：PS/2 + 矩阵键盘双通道 → 合并 → 统一信号
- *逻辑层*：有限状态机 + 碰撞检测 + AI决策 + 道具管理
- *输出层*：VGA渲染 + 音效 + LED + 数码管
- *支撑层*：PLL时钟 + 全局参数定义