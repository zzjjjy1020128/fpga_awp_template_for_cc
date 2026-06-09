# Skill: vitis-cli-build

## When to use

需要在 CLI 环境下（不使用 Vitis GUI）编译 Zynq baremetal C 代码生成 ELF 时使用。
适用于 CI/CD 集成、sub-agent 自动化、或任何无法启动 Vitis GUI 的场景。

## 前置条件

- Vitis 2022.2 已安装（`G:/vivado2022.2/Vitis/2022.2/`）
- `xsct.bat` 可用
- 已从 Vivado 导出 XSA（包含 bitstream + PS 配置）
- 已通过 XSCT 创建 Platform + BSP（或可以在此 skill 中一并创建）

## 编译流程

### 1. 创建 Vitis Platform + BSP（首次）

```tcl
# XSCT 脚本
setws <workspace_path>
platform create -name <platform_name> -hw <xsa_path> -proc ps7_cortexa9_0 -os standalone
# BSP 自动随 platform 创建为 standalone_domain
```

### 2. 编译 C 代码为 ELF

```tcl
# 在 XSCT 中执行（xsct.bat 启动的 Tcl shell）
set bsp "<workspace>/<platform>/ps7_cortexa9_0/standalone_domain/bsp/ps7_cortexa9_0"
set src_dir "<source_directory>"
set out_dir "<output_directory>"

# 定位 BSP 路径（关键：不同 Vivado 版本路径结构可能不同）
# include: $bsp/include/
# libxil.a: $bsp/lib/libxil.a
# xil-crt0.o: $bsp/lib/xil-crt0.o
# lscript.ld: 从 Vitis 模板复制到 src_dir

# 编译命令
arm-none-eabi-gcc -c -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -O0 -g -Wall \
    -I$src_dir -I$bsp/include \
    -o $out_dir/file.o $src_dir/file.c

# 链接命令
arm-none-eabi-gcc -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard \
    -nostartfiles -nostdlib \
    -Wl,-T -Wl,$src_dir/lscript.ld \
    -Wl,--defsym=_init=0 -Wl,--defsym=_fini=0 \
    -o $out_dir/app.elf \
    $bsp/lib/xil-crt0.o \
    $out_dir/*.o \
    -Wl,--start-group $bsp/lib/libxil.a -lc -lgcc -Wl,--end-group
```

## 常见 API 差异（Vitis 2022.2）

| 问题 | 修正 |
|------|------|
| `XAxiDma_CfgInitialize(dma, cfg, BASEADDR)` 参数过多 | SDK v9.15 只接受 2 参数：`(XAxiDma*, XAxiDma_Config*)` |
| `XAxiDma_Reset()` 返回值 | 返回 `void`，不是 `int` |
| `XAxiDma_IntrGetStatus` / `XAxiDma_IntrClear` 不存在 | 使用 `XAxiDma_IntrGetIrq` / `XAxiDma_IntrAckIrq(Mask, Direction)` |
| `XPAR_AXIL_2D_SHIFT_0_S_AXI_BASEADDR` 宏名不匹配 | BSP 实际宏名可能无 `_S_AXI` 部分，在 `xparameters.h` 中搜索确认 |
| `xil_types.h` 路径错误 | BSP include 路径在 `<bsp>/ps7_cortexa9_0/include/` |
| `platform.h` 不在 BSP include 中 | 从 Vitis 模板（Hello World）复制或自行创建 minimal 版本 |

## XPAR 宏名验证方法

```bash
grep "AXIL_2D_SHIFT\|AXI_DMA_0\|S2MM_INTROUT" $bsp/include/xparameters.h
```

输出示例（实际值因 BD address editor 配置而异）：
```
XPAR_AXIL_2D_SHIFT_0_BASEADDR = 0x60000000
XPAR_AXI_DMA_0_BASEADDR = 0x40400000
XPAR_AXI_DMA_0_DEVICE_ID = 0
XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR = 62
```

## 语言策略

- C 代码注释：zh 或 en
- 变量/函数名：en
- API 宏名：en
