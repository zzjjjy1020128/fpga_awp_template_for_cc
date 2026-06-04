# FPGA-AWP v0.1 Makefile
# 常用操作的快捷入口。

.PHONY: help dirs clean validate-awp status task-board

help:
	@echo "FPGA-AWP v0.1 —— 可用目标："
	@echo "  make validate-awp  —— 校验工作空间完整性（task 格式、ID 规范、跨引用）"
	@echo "  make status        —— 项目全局仪表盘（任务、session、问题、下一步）"
	@echo "  make task-board    —— 根据 .awp/tasks/*.yaml 自动生成 task_board.md"
	@echo "  make dirs          —— 确保所有工作目录存在"
	@echo "  make clean         —— 清理临时文件（保留 .gitkeep）"

validate-awp:
	@python scripts/validate_awp.py

status:
	@python scripts/validate_awp.py --dashboard

task-board:
	@python scripts/validate_awp.py --gen-task-board

dirs:
	@mkdir -p rtl tb sim vivado constraints board scripts
	@mkdir -p .awp/tasks .awp/sessions .awp/handoffs .awp/reviews .awp/runs
	@mkdir -p docs

clean:
	@echo "FPGA-AWP clean placeholder —— 真实项目请补充具体清理规则"
