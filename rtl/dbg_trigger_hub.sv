//==============================================================================
// dbg_trigger_hub — ILA cross-trigger hub
//
// 功能:
//   从 PL 内部确定的 anchor event 生成调试触发脉冲, 分发到多个 ILA trig_in。
//   支持 AXI-Lite 可配置的 trig_sel:
//     00: fsm_start_edge    (ctrl_fsm IDLE → CAPTURE)
//     01: axis_first_beat   (s_axis_tvalid && s_axis_tready 第一个 beat)
//     10: shift_start_edge   (ctrl_fsm CAPTURE → SHIFT)
//     11: axis_error         (预留, 当前未实现)
//
// 输出:
//   dbg_trig_out   — 触发脉冲 (1 cycle wide, 展宽为 4 cycles 确保 ILA 捕获)
//   dbg_cycle_cnt  — 自由运行周期计数器 (32-bit, 用于时间比对)
//==============================================================================

module dbg_trigger_hub #(
    parameter NUM_ILA = 2
) (
    input  logic        clk,
    input  logic        rstn,

    // AXI-Lite 配置接口 (来自 regs_top)
    input  logic [1:0]  trig_sel,

    // Anchor event 输入
    input  logic        fsm_idle,          // ctrl_fsm: IDLE state
    input  logic        fsm_capture,       // ctrl_fsm: CAPTURE state
    input  logic        fsm_shift,         // ctrl_fsm: SHIFT state
    input  logic        axis_tvalid,       // s_axis valid
    input  logic        axis_tready,       // s_axis ready
    input  logic        capture_en,        // capture phase active

    // ILA trigger 输出
    output logic        dbg_trig_pulse,    // 触发脉冲 (all ILAs)
    output logic [31:0] dbg_cycle_cnt,     // 自由运行计数器
    output logic        dbg_anchor_status  // anchor event 状态 (用于 ILA 辅助信号)
);

    // ===================================================================
    // 自由运行周期计数器
    // ===================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            dbg_cycle_cnt <= 32'd0;
        else
            dbg_cycle_cnt <= dbg_cycle_cnt + 1'b1;
    end

    // ===================================================================
    // FSM 边沿检测
    // ===================================================================
    logic fsm_prev_idle;
    always_ff @(posedge clk) begin
        if (!rstn)
            fsm_prev_idle <= 1'b1;
        else
            fsm_prev_idle <= fsm_idle;
    end
    wire fsm_start_edge  = fsm_prev_idle && !fsm_idle;  // IDLE -> CAPTURE

    logic fsm_prev_capture;
    always_ff @(posedge clk) begin
        if (!rstn)
            fsm_prev_capture <= 1'b0;
        else
            fsm_prev_capture <= fsm_capture;
    end
    wire shift_start_edge = fsm_prev_capture && !fsm_capture; // CAPTURE -> SHIFT

    // ===================================================================
    // AXIS 第一个 beat 检测
    // ===================================================================
    logic axis_first_beat_seen;
    wire  axis_first_beat = capture_en && axis_tvalid && axis_tready && !axis_first_beat_seen;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            axis_first_beat_seen <= 1'b0;
        else if (!capture_en)
            axis_first_beat_seen <= 1'b0;
        else if (axis_tvalid && axis_tready)
            axis_first_beat_seen <= 1'b1;
    end

    // ===================================================================
    // Anchor event 选择
    // ===================================================================
    wire anchor_raw;
    assign anchor_raw = (trig_sel == 2'd0) ? fsm_start_edge  :
                        (trig_sel == 2'd1) ? axis_first_beat  :
                        (trig_sel == 2'd2) ? shift_start_edge :
                        1'b0;  // trig_sel=3 reserved

    // ===================================================================
    // 触发脉冲展宽 (raw 1-cycle → 4-cycle pulse)
    // 确保 ILA trig_in 满足最小脉冲宽度要求
    // ===================================================================
    logic [2:0] pulse_stretch;
    wire       trig_stretched = |pulse_stretch;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            pulse_stretch <= 3'd0;
        else if (anchor_raw)
            pulse_stretch <= 3'b111;
        else
            pulse_stretch <= {pulse_stretch[1:0], 1'b0};
    end

    assign dbg_trig_pulse   = trig_stretched;
    assign dbg_anchor_status = anchor_raw || trig_stretched;

endmodule
