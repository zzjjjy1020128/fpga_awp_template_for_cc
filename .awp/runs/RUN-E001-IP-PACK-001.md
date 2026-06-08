# IP 打包运行报告

> Run ID: RUN-E001-IP-PACK-001
> Task: TASK-E001-017
> Date: 2026-06-07
> Tool: Vivado 2022.2 (tcl mode, MCP automated)

## 结果：PASS

IP 核 `axil_2d_shift_v1_0` 打包成功，综合通过。

## IP 核信息

| 属性 | 值 |
|------|-----|
| IP 名称 | axil_2d_shift_v1_0 |
| Vendor | awp |
| Library | user |
| 目标器件 | xc7z020clg400-1 |
| 源文件 | 8 个 .sv 文件（全部子模块） |

## 总线接口（全部自动推断）

| 接口 | VLNV | 推断结果 |
|------|------|:--:|
| s_axil | xilinx.com:interface:aximm:1.0 | 自动 |
| s_axis | xilinx.com:interface:axis:1.0 | 自动 |
| m_axis | xilinx.com:interface:axis:1.0 | 自动 |
| clk | xilinx.com:signal:clock:1.0 | 自动 |
| rstn | xilinx.com:signal:reset:1.0 | 自动 |

## 时钟/复位关联

- ASSOCIATED_BUSIF = m_axis:s_axis:s_axil
- ASSOCIATED_RESET = rstn
- POLARITY = ACTIVE_LOW

## 综合结果

| 指标 | 值 |
|------|-----|
| Error | 0 |
| Critical Warning | 0 |
| Warning | 58（主要是未连接寄存器位、unused sequential element，均为预期行为）|
| LUT | 811 |
| FF | 313 |
| BRAM (RAMB36E1) | 1 |
| DSP (DSP48E1) | 2 |
| 综合时间 | 39 秒 |

## 自动化评估

**完全可自动化。** 整个流程（create_project → add_files → ipx::package_project → synth_design）通过 Vivado Tcl 模式无人工干预完成。

注意事项：
- `ipx::package_project` 对 .sv 顶层文件会给出 WARNING（非 ERROR），不影响功能
- 接口推断依赖端口命名规范（s_axil_*/s_axis_*/m_axis_*/clk/rstn），当前命名全部通过

## 产出文件

```
vivado/ip/axil_2d_shift_v1_0/
  component.xml
  xgui/axil_2d_shift_v1_0.tcl
  src/axil_2d_shift.sv
  src/axil_slave_if.sv
  src/regs_top.sv
  src/ctrl_fsm.sv
  src/axis_input.sv
  src/shift_addr_gen.sv
  src/axis_output.sv
  src/frame_buf_mgr.sv
```
