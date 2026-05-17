# 小莫划船机 App · 流程图

> 版本 v0.3 · 2026-05-17 · 配套 `prototype/index.html` / `docs/PRD.md`
> 使用 Mermaid,GitHub 直接渲染。

---

## 1. 总导航与训练主流程

```mermaid
flowchart TD
    Start(["启动 App"]) --> Connect["启动页<br/>开始划船 / 选择训练目标"]

    Connect -->|点 开始划船| Connecting["自动连接中<br/>零点击 · 拉手柄唤醒"]
    Connect -->|选择训练目标| Goal["训练目标设置<br/>自由划/定距/定时/定卡/间歇/目标配速"]
    Connect -->|连不上· 兜底| AllDev["手动选择蓝牙设备"]
    Connect -->|蓝牙未开| BtOff["边界:蓝牙未开启"]

    Goal -->|开始训练| Connecting
    AllDev -->|选中设备| Connecting

    Connecting -->|连接成功| Ready["连接成功<br/>3-2-1 倒计时"]
    Connecting -->|重试 N 次失败| ConnFail["边界:连接失败"]
    Connecting -->|取消| Connect
    ConnFail -->|重试| Connecting
    ConnFail -->|手动选设备| AllDev

    Ready -->|倒计时结束<br/>从 0 计时计数| Dash["实时训练仪表盘<br/>配速/桨频/功率/距离/桨数/时间/卡路里/心率 + 分段表"]
    Dash -->|右上角| Raw["原始调试视图<br/>GATT + 13字节帧日志"]
    Dash -->|心率 >5s 无数据| HrWeak["边界:心率信号弱<br/>其余照常记录"]
    HrWeak -->|恢复| Dash
    Dash -->|结束训练并保存| Detail["单次记录详情<br/>统计 + 配速/心率曲线 + 分段明细"]

    %% 底部 Tab(任意页可达,专注流程除外)
    Dash -. 底部Tab .-> History
    Detail --> History["训练记录列表<br/>按日分组 + 本周汇总"]
    History -->|列表/趋势 切换| Trends["趋势 & 个人最佳<br/>每周距离 / 配速趋势 / PR / 打卡"]
    History -->|点记录| Detail
    History -->|无记录| HistEmpty["空状态:无训练记录"]
    HistEmpty -->|开始第一次训练| Connecting

    Connect -. 底部Tab .-> Profile["我的 / 多用户"]
    Profile --> UserSw["切换 / 添加用户<br/>各自独立记录"]
    Profile --> Settings["训练标定<br/>米/脉冲 · 功率k · 抓水阈值 · 心率设备"]
```

底部 Tab(训练 / 记录 / 我的)在所有可浏览页常驻且全程可点;**专注流程**(自动连接中、连接成功倒计时、连接失败)隐藏 Tab,避免误触中断。

## 2. 连接生命周期状态机

```mermaid
stateDiagram-v2
    [*] --> 空闲
    空闲 --> 检查蓝牙: 点"开始划船"
    检查蓝牙 --> 蓝牙未开启: 蓝牙关闭
    蓝牙未开启 --> 检查蓝牙: 用户开启后重新检测
    检查蓝牙 --> 扫描中: 蓝牙就绪
    扫描中 --> 已发现: 命中 AT-R79517 / 已记住设备
    已发现 --> 连接中: 自动发起连接
    连接中 --> 已连接: 握手成功
    连接中 --> 重试: 瞬时失败(自动重试,上限 N)
    重试 --> 连接中: 间隔后再连
    重试 --> 连接失败: 超过重试上限
    连接失败 --> 扫描中: 用户点"重试"
    已连接 --> 倒计时: 进入连接成功页
    倒计时 --> 训练中: 3-2-1 结束,计时计数从 0
    训练中 --> 已断开: 蓝牙断连
    已断开 --> 训练中: 自动重连成功(训练数据保留)
    训练中 --> [*]: 结束训练并保存
```

## 3. 一次训练的数据流

```mermaid
flowchart LR
    BLE["划船机 BLE<br/>0xFFE4 notify<br/>13字节帧/脉冲"] --> Parser["anytum_rower.dart<br/>解析:脉冲计数 + 间隔ms"]
    Parser --> Metrics["rowing_metrics.dart<br/>Concept2 模型<br/>功率=k·v³ · 滚动窗口测速 · 抓水状态机"]
    Metrics --> Live["仪表盘实时指标<br/>配速/桨频/功率/距离/桨数/时间/卡路里"]
    HR["心率设备 BLE<br/>0x180D / 0x2A37"] -. 可选 .-> Live
    Live --> Splits["每 500m 分段累积"]
    Live --> Record["训练记录<br/>(本地存储, 预留云同步接口)"]
    Splits --> Record
    Record --> ListV["记录列表"]
    Record --> DetailV["单次详情 + 分段明细"]
    Record --> TrendsV["趋势 & 个人最佳(PR)"]
    Record -. 多用户隔离 .-> Users["每用户独立记录集"]
```

> 关键不变量:距离 = 累计脉冲 × 米/脉冲(默认 0.45,可标定);计时计数**连接成功后从 0**;卡路里为无参照估算;同一次训练在仪表盘/详情/列表/分段/原始日志间数字一致。
