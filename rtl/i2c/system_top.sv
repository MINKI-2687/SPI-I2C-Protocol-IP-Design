`timescale 1ns / 1ps

module system_top (
    input logic clk,
    input logic reset, // 중앙 버튼

    // 버튼 입력 (마스터 제어용)
    input logic btn_start,  // Up 버튼
    input logic btn_write,  // Right 버튼
    input logic btn_read,   // Left 버튼
    input logic btn_stop,   // Down 버튼

    // 스위치 입력
    input  logic [15:0] sw,         // sw[7:0]: 마스터 TX 데이터, sw[15:8]: 슬레이브 TX 데이터

    // FND 및 LED 출력
    output logic [ 7:0] fnd_data,   // FND 세그먼트
    output logic [ 3:0] fnd_digit,  // FND 자릿수 선택
    output logic [15:0] led,        // 상태 확인용 LED

    // 물리 I2C 핀 (내부 연결 없음! 반드시 외부 점퍼선 필요)
    // 마스터용 핀 (JB로 나갈 선)
    inout  wire mst_sda,
    output wire mst_scl,
    // 슬레이브용 핀 (JC로 들어올 선)
    inout  wire slv_sda,
    input  wire slv_scl
);

    //==================================================
    // 1. 내부 신호 선언
    //==================================================
    logic cmd_start_pulse, cmd_write_pulse, cmd_read_pulse, cmd_stop_pulse;
    logic [7:0] mst_rx_data_out, slv_rx_data_out;
    logic mst_busy_out, slv_busy_out;
    logic mst_ack_out, slv_ack_out, slv_tx_req_out;
    wire slv_sda_o;

    // 슬레이브 SDA 출력 제어 (마스터와 동일한 오픈 드레인 원리)
    assign slv_sda = slv_sda_o ? 1'bz : 1'b0;

    //==================================================
    // 2. 버튼 디바운싱 인스턴스
    //==================================================
    btn_debounce u_btn_start (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_start),
        .o_btn(cmd_start_pulse)
    );
    btn_debounce u_btn_write (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_write),
        .o_btn(cmd_write_pulse)
    );
    btn_debounce u_btn_read (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_read),
        .o_btn(cmd_read_pulse)
    );
    btn_debounce u_btn_stop (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_stop),
        .o_btn(cmd_stop_pulse)
    );

    //==================================================
    // 3. I2C 코어 인스턴스 (마스터와 슬레이브)
    //==================================================
    I2C_Master u_master (
        .clk      (clk),
        .reset    (reset),
        .cmd_start(cmd_start_pulse),
        .cmd_write(cmd_write_pulse),
        .cmd_read (cmd_read_pulse),
        .cmd_stop (cmd_stop_pulse),
        .tx_data  (sw[7:0]),          // 우측 스위치 8개
        .ack_in   (1'b0),             // 마스터 수신 시 항상 ACK
        .rx_data  (mst_rx_data_out),
        .done     (),
        .busy     (mst_busy_out),
        .ack_out  (mst_ack_out),
        // 마스터 핀 할당 (JB)
        .sda      (mst_sda),
        .scl      (mst_scl)
    );

    i2c_slave #(
        .SLAVE_ADDR(7'h12)
    ) u_slave (
        .clk    (clk),
        .reset  (reset),
        .tx_data(sw[15:8]),         // 좌측 스위치 8개
        .ack_in (1'b0),             // 슬레이브 수신 시 항상 ACK
        .rx_data(slv_rx_data_out),
        .ack_out(slv_ack_out),
        .rx_done(),
        .tx_req (slv_tx_req_out),
        .busy   (slv_busy_out),
        // 슬레이브 핀 할당 (JC)
        .scl    (slv_scl),
        .sda_i  (slv_sda),
        .sda_o  (slv_sda_o)
    );

    //==================================================
    // 4. FND 제어 모듈
    //==================================================
    // 좌측 2자리: 슬레이브 수신 데이터 / 우측 2자리: 마스터 수신 데이터
    fnd_controller u_fnd_ctrl (
        .clk        (clk),
        .reset      (reset),
        .fnd_in_data({slv_rx_data_out, mst_rx_data_out}),
        .fnd_data   (fnd_data),
        .fnd_digit  (fnd_digit)
    );

    //==================================================
    // 5. LED 직관적 모니터링
    //==================================================
    assign led[0] = mst_busy_out;  // 마스터 통신 중
    assign led[1] = slv_busy_out;  // 슬레이브 통신 중
    assign led[2]  = slv_tx_req_out;  // 슬레이브 데이터 요구 (찰나의 깜빡임)
    assign led[15] = mst_ack_out;  // NACK 발생 (에러)
    assign led[14:3] = 12'd0;

endmodule
