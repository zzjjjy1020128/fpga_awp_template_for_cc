---
run_id: "RUN-E001-BOARD-006"
task_id: "TASK-E001-027"
title: "ILA Cross-Trigger 上板验证"
date: "2026-06-09"
platform: "HW_BASE_AX7010_v1.2"
status: "pending"
---

# ILA Cross-Trigger 上板验证

## 状态：待执行

L5/L6 上板验证尚未完成。L0-L4 验证结果：
- L0 (RTL 审查): pass — REV-E001-027-RTL-001
- L1a-L1c: pending
- L2 (综合): 通过 (Vivado 2022.2, 0 errors, 0 CW, 52s)
- L3 (实现): 通过 (WNS +6.086ns, WHS +0.031ns)
- L4 (比特流): 已生成

## 待执行测试
1. 烧写比特流到 AX7010
2. 运行 ila_cross_trigger.tcl 脚本
3. 验证 ILA cross-trigger 同步捕获
4. 记录 ILA 波形数据
