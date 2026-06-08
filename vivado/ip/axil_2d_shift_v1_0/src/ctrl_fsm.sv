//==============================================================================
// ctrl_fsm - 主控制状态机
//
// 功能:
//   4 状态状态机 (IDLE / CAPTURE / SHIFT / DONE)，管理数据流控制:
//   - IDLE:  等待 ctrl_start 脉冲，输出 idle 标志
//   - CAPTURE: 使能 axis_input 采集数据，等待 capture_done
//   - SHIFT:   使能 shift_addr_gen + axis_output 移位输出，等待 shift_done
//   - DONE:   保持 1 周期后自动返回 IDLE
//
// 状态转换:
//   IDLE ---(ctrl_start)---> CAPTURE
//   CAPTURE -(capture_done)-> SHIFT
//   SHIFT   ---(shift_done)-> DONE
//   DONE    ---(auto 1cy)---> IDLE
//   任意状态 ---(sw_reset)---> IDLE
//
// 输入:
//   clk, rstn           - 单时钟域，同步复位（低有效）
//   ctrl_start          - 启动脉冲（来自 regs_top）
//   ctrl_sw_reset       - 软复位（来自 regs_top）
//   capture_done        - 采集完成脉冲（来自 axis_input）
//   shift_done          - 移位完成脉冲（来自 axis_output）
//
// 输出:
//   status_idle         - 状态标志: 空闲
//   status_busy_capture - 状态标志: 采集中
//   status_busy_shift   - 状态标志: 移位中
//   status_done         - 状态标志: 完成（1 周期脉冲）
//   capture_en          - 采集使能（连 axis_input）
//   shift_en            - 移位使能（连 shift_addr_gen + axis_output）
//==============================================================================

module ctrl_fsm (
    input  logic        clk,
    input  logic        rstn,
    input  logic        ctrl_start,
    input  logic        ctrl_sw_reset,
    input  logic        capture_done,
    input  logic        shift_done,
    output logic        status_idle,
    output logic        status_busy_capture,
    output logic        status_busy_shift,
    output logic        status_done,
    output logic        capture_en,
    output logic        shift_en
);

    // -------------------------------------------------------------------------
    // 状态编码
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        CAPTURE = 2'b01,
        SHIFT   = 2'b10,
        DONE    = 2'b11
    } state_t;

    state_t state, next;

    // -------------------------------------------------------------------------
    // 次态组合逻辑
    // -------------------------------------------------------------------------
    always_comb begin
        next = state;
        case (state)
            IDLE: begin
                if (ctrl_sw_reset)
                    next = IDLE;
                else if (ctrl_start)
                    next = CAPTURE;
            end

            CAPTURE: begin
                if (ctrl_sw_reset)
                    next = IDLE;
                else if (capture_done)
                    next = SHIFT;
            end

            SHIFT: begin
                if (ctrl_sw_reset)
                    next = IDLE;
                else if (shift_done)
                    next = DONE;
            end

            DONE: begin
                if (ctrl_sw_reset)
                    next = IDLE;
                else
                    next = IDLE;   // 保持 1 周期后自动返回 IDLE
            end

            default: begin
                next = IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // 状态寄存器（同步复位，低有效 rstn）
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next;
    end

    // -------------------------------------------------------------------------
    // 输出译码（组合逻辑）
    // -------------------------------------------------------------------------
    always_comb begin
        status_idle         = (state == IDLE);
        status_busy_capture = (state == CAPTURE);
        status_busy_shift   = (state == SHIFT);
        status_done         = (state == DONE);
        capture_en          = (state == CAPTURE);
        shift_en            = (state == SHIFT);
    end

endmodule
