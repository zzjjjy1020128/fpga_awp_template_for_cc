# Skill: axi-lite-review

## When to use
审查 AXI-Lite 从机/主机接口设计时使用。

## Input files
- AXI-Lite 相关 RTL 文件
- 寄存器映射文档

## Checklist
- [ ] AWVALID/AWREADY, WVALID/WREADY, BVALID/BREADY 握手信号正确
- [ ] ARVALID/ARREADY, RVALID/RREADY 读通道握手正确
- [ ] 读/写通道独立，无意外耦合
- [ ] 地址对齐检查
- [ ] 寄存器地址空间与文档一致
- [ ] 响应信号（RRESP/BRESP）正确

## Required output
- `.awp/reviews/REV-{exp}-{task_seq}-AXIL-{seq}.md`（格式见 `.awp/registry/namespaces.yaml`）

## Language policy
- 审查报告：zh
- 信号名：en
