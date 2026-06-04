# FPGA-AWP v0.1 Makefile
# 常用操作的快捷入口。
# 如果系统没有 make，可以直接用 Python 运行同等命令，见 README 的"环境准备"一节。

# 自动检测 python3 / python（可手动覆盖：make PYTHON=python3 status）
PYTHON := $(shell command -v python3 >/dev/null 2>&1 && echo python3 || echo python)

.PHONY: help dirs clean validate-awp status task-board verify-env

help:
	@echo "FPGA-AWP v0.1 —— 可用目标："
	@echo "  make verify-env    —— 检查 Python、pip、依赖是否就绪"
	@echo "  make validate-awp  —— 校验工作空间完整性（task 格式、ID 规范、跨引用）"
	@echo "  make status        —— 项目全局仪表盘（任务、session、问题、下一步）"
	@echo "  make task-board    —— 根据 .awp/tasks/*.yaml 自动生成 task_board.md"
	@echo "  make dirs          —— 确保所有工作目录存在"
	@echo "  make clean         —— 清理临时文件（保留 .gitkeep）"

verify-env:
	@echo "=== FPGA-AWP 环境检查 ==="
	@echo "Python:"
	@$(PYTHON) --version 2>&1 || (echo "  [FAIL] Python not found. Please install Python 3.8+." && exit 1)
	@echo "  [OK]"
	@echo "pip:"
	@$(PYTHON) -m pip --version 2>&1 || (echo "  [FAIL] pip not found." && exit 1)
	@echo "  [OK]"
	@echo "PyYAML:"
	@$(PYTHON) -c "import yaml" 2>&1 && echo "  [OK]" || (echo "  [MISSING] Run: $(PYTHON) -m pip install -r requirements.txt" && exit 1)
	@echo "=== All checks passed ==="

validate-awp:
	@$(PYTHON) scripts/validate_awp.py

status:
	@$(PYTHON) scripts/validate_awp.py --dashboard

task-board:
	@$(PYTHON) scripts/validate_awp.py --gen-task-board

dirs:
	@mkdir -p rtl tb sim vivado constraints board scripts
	@mkdir -p .awp/tasks .awp/sessions .awp/handoffs .awp/reviews .awp/runs
	@mkdir -p docs

clean:
	@echo "FPGA-AWP clean placeholder —— 真实项目请补充具体清理规则"
