`timescale 1ns / 1ps

module system_top (
    input  logic       clk,
    input  logic       reset,
    // ==========================================
    // [입력/출력 인터페이스]
    // ==========================================
    input  logic [7:0] sw,         // 전송할 데이터 세팅
    input  logic       btn_send,   // 전송 시작 버튼
    output logic [3:0] fnd_digit,  // FND 제어
    output logic [7:0] fnd_data,   // FND 제어
    // ==========================================
    // [마스터 물리 핀] (JB PMOD로 할당할 포트)
    // ==========================================
    output logic       jb_sclk,
    output logic       jb_cs_n,
    output logic       jb_mosi,
    input  logic       jb_miso

    // // ==========================================
    // // [슬레이브 물리 핀] (JC PMOD로 할당할 포트)
    // // ==========================================
    // input  logic jc_sclk,
    // input  logic jc_cs_n,
    // input  logic jc_mosi,
    // output logic jc_miso
);
    logic btn_debounced;

    logic [7:0] w_slave_rx_data;
    logic w_slave_done;
    logic [7:0] fnd_data_reg;

    logic [7:0] w_master_rx_data;  // 슬레이브로부터 받아온 데이터
    logic w_master_done;  // 마스터 수신 완료 펄스
    logic [7:0] master_fnd_reg;   // 마스터 FND 깜빡임 방지용 래치 창고

    btn_debounce u_btn_debounce (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_send),
        .o_btn(btn_debounced)
    );

    // [1] 마스터 인스턴스: 칩 내부가 아닌 JB 핀으로 데이터를 쏜다!
    spi_master u_master (
        .clk    (clk),
        .reset  (reset),
        .cpol   (1'b0),
        .cpha   (1'b0),
        .clk_div(8'd40),
        .start  (btn_debounced),
        .tx_data(sw),
        .rx_data(w_master_rx_data),
        .done   (w_master_done),
        .busy   (),

        // 물리 핀 연결
        .sclk(jb_sclk),
        .cs_n(jb_cs_n),
        .mosi(jb_mosi),
        .miso(jb_miso)
    );

    // // [2] 슬레이브 인스턴스: 칩 내부가 아닌 JC 핀에서 데이터를 읽어온다!
    // spi_slave u_slave (
    //     .clk    (clk),
    //     .reset  (reset),
    //     .tx_data(8'h00),
    //     .rx_data(w_slave_rx_data),
    //     .done   (w_slave_done),
    //     .busy   (),

    //     // 물리 핀 연결
    //     .sclk(jc_sclk),
    //     .cs_n(jc_cs_n),
    //     .mosi(jc_mosi),
    //     .miso(jc_miso)
    // );

    // [3] Data Latch (이전과 동일)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            fnd_data_reg <= 8'h00;
        end else if (w_slave_done) begin
            fnd_data_reg <= w_slave_rx_data;
        end
    end
    // 마스터 FND를 위한 데이터 래치
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            master_fnd_reg <= 8'h00;
        end else if (w_master_done) begin // 마스터가 8비트를 다 받았을 때!
            master_fnd_reg <= w_master_rx_data;
        end
    end

    // [4] FND Controller (이전과 동일)
    fnd_controller u_fnd_ctrl (
        .clk        (clk),
        .reset      (reset),
        .fnd_in_data(master_fnd_reg),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );
endmodule
