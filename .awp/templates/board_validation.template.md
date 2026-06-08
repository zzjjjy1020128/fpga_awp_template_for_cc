# 上板验证记录

> 文件命名：`.awp/runs/RUN-{exp}-BOARD-{seq}.md`（格式定义见 `.awp/registry/namespaces.yaml`）

## 基本信息

- **Board**：`<开发板型号>`
- **Platform ID**：`<HW_BASE_xxx_vX.X>`
- **Bitstream**：`<bitstream 文件路径 + SHA256 或生成日期>`
- **Vivado Version**：`<版本号>`
- **Date**：`<YYYY-MM-DD>`
- **Validation Level**：`<L5 | L6>`
- **Round**：`<当前轮次>/<类别最大轮次>`

## 硬件设置

- **电源**：`<供电方式 + 电压/电流>`
- **JTAG 适配器**：`<型号 + 速度>`
- **时钟源**：`<时钟频率和来源>`
- **外部接口**：`<连接的外部设备>`
- **启动模式**：`<JTAG/QSPI/SD + 开关位置>`
- **串口**：`<波特率 + 端口号>`

## 测试激励

`<如何产生输入数据的描述>`
- **激励方式**：`<PS 端程序 / XSCT 命令 / 外部信号发生器 / ILA 触发等>`
- **测试数据**：`<数据内容或数据源>`

## 预期结果

`<期望观察到的信号行为或数据输出>`

## 观察结果

`<实际观察到的结果>`

## 硬件证据采集

### 证据检查清单
- [ ] ILA 波形捕获已保存：`<路径>`
- [ ] PS 控制台日志已保存：`<路径>`
- [ ] VIO 状态快照已保存：`<路径 if applicable>`
- [ ] Hardware Manager 截图已保存：`<路径 if applicable>`

### ILA 捕获详情
- **ILA 核**：`<ila_capture / ila_shift / system_ila_0>`
- **触发条件**：`<触发信号和条件>`
- **捕获窗口**：`<采样深度 + pre/post 比例>`
- **关键信号观测值**：
  - `<signal1>`: `<observed value>`
  - `<signal2>`: `<observed value>`

### PS 日志摘录
```
<关键日志行>
```

## ILA/VIO 证据

- **ILA 截图**：`<路径或描述>`
- **VIO 状态**：`<虚拟 I/O 状态>`
- **关键信号波形描述**：`<描述>`

## 结论

- **Pass/Fail**：`<pass | fail | partial>`
- **Failure Category**（若 fail）：`<CAT-HW | CAT-BS | CAT-AX | CAT-IL | CAT-SW | CAT-DT | CAT-RT>`
- **Failure Notes**：`<如果失败，描述失败现象和初步定位>`
- **Evidence Files**：`<ILA 捕获 + PS 日志 + 截图路径>`

## 迭代轮次

- **当前轮次**：`<N>`
- **最大轮次**：`<根据失败类别确定>`
- **上一轮参考**：`<ISS-ID 或 RUN-ID>`

## 后续行动

- `<下一步，含目标 task 或 ISS issue>`
