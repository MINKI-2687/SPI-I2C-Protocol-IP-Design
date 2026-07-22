`timescale 1ns / 1ps

module slave_top (
    input  logic       clk,
    input  logic       reset,
    
    // ==========================================
    // [입력/출력 인터페이스]
    // ==========================================
    input  logic [7:0] sw,         // 마스터에게 보낼 데이터 (스위치 상태 상시 반영)
    // input logic btn_send,       // [삭제] 슬레이브는 전송 시작 버튼이 필요 없습니다!
    
    output logic [3:0] fnd_digit,  // 마스터에게서 받은 데이터를 띄울 FND 제어
    output logic [7:0] fnd_data,   // FND 세그먼트 데이터
    
    // ==========================================
    // [슬레이브 물리 핀] (마스터와 점퍼선으로 연결될 포트)
    // ==========================================
    input  logic       sclk,   // 마스터가 주는 클럭 받기
    input  logic       cs_n,   // 마스터가 주는 칩 셀렉트 받기
    input  logic       mosi,   // 마스터가 주는 데이터 받기
    output logic       miso    // 마스터에게 데이터 보내기
);

    // 내부 연결용 와이어
    logic [7:0] w_slave_rx_data; // 슬레이브가 방금 수신한 데이터
    logic       w_slave_done;    // 8비트 수신 완료 펄스
    logic [7:0] fnd_data_reg;    // FND 출력을 위해 값을 유지하는 창고(래치)

    // ==========================================
    // [1] 슬레이브 IP 인스턴스
    // ==========================================
    spi_slave u_slave (
        .clk     (clk),
        .reset   (reset),
        
        // 핵심: 마스터가 부르면 언제든 튀어나갈 수 있도록, 스위치 핀을 그대로 TX에 물려둡니다.
        .tx_data (sw),              
        
        .rx_data (w_slave_rx_data),
        .done    (w_slave_done),
        .busy    (), // 슬레이브의 busy는 FND 출력에 영향이 없으므로 비워둡니다.

        // 물리 핀 연결
        .sclk    (sclk),
        .cs_n    (cs_n),
        .mosi    (mosi),
        .miso    (miso)
    );

    // ==========================================
    // [2] 수신 데이터 래치 (저장소)
    // ==========================================
    // 마스터로부터 8비트 교환이 '완료(done)'된 순간에만! 수신된 데이터를 창고에 저장합니다.
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            fnd_data_reg <= 8'h00;
        end else if (w_slave_done) begin
            fnd_data_reg <= w_slave_rx_data;
        end
    end

    // ==========================================
    // [3] FND 컨트롤러 인스턴스
    // ==========================================
    // 창고(fnd_data_reg)에 저장된 데이터를 FND로 쏘아줍니다.
    fnd_controller u_fnd_ctrl (
        .clk         (clk),
        .reset       (reset),
        .fnd_in_data (fnd_data_reg),
        .fnd_digit   (fnd_digit),
        .fnd_data    (fnd_data)
    );

endmodule