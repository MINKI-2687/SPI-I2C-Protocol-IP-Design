`timescale 1ns / 1ps

module i2c_slave #(
    parameter logic [6:0] SLAVE_ADDR = 7'h12 // 기본 슬레이브 주소 (0x12)
) (
    input logic       clk,
    input logic       reset,
    // internal port 
    input logic [7:0] tx_data,  // mst -> slv
    input logic       ack_in,   // mst -> slv

    output logic [7:0] rx_data,  // slv -> mst
    output logic       ack_out,  // slv -> mst 
    output logic       rx_done,  // slv -> mst 
    output logic       tx_req,   // slv -> mst 
    output logic       busy,
    // I2C Interface
    input  logic       scl,
    input  logic       sda_i,
    output logic       sda_o
);

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        RX_ADDR,
        ADDR_ACK,
        DATA,
        DATA_ACK
    } i2c_state_e;
    i2c_state_e       state;

    logic       [7:0] tx_shift_reg;
    logic       [7:0] rx_shift_reg;
    logic       [3:0] bit_cnt;
    logic             is_read;
    logic             ack_in_r;
    logic             sda_r;

    // Synchronizer & Edge Detector
    logic       [2:0] scl_sync;
    logic       [2:0] sda_sync;
    logic scl_safe, sda_safe;
    logic scl_rising, scl_falling;
    logic sda_rising, sda_falling;
    logic start_detected, stop_detected;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda_i};
        end
    end
    assign scl_safe = scl_sync[1];
    assign sda_safe = sda_sync[1];
    // edge detected (previous vs present)
    assign scl_rising = (scl_sync[2:1] == 2'b01);
    assign scl_falling = (scl_sync[2:1] == 2'b10);
    assign sda_rising = (sda_sync[2:1] == 2'b01);
    assign sda_falling = (sda_sync[2:1] == 2'b10);
    // START / STOP detected (when scl high, change sda)
    assign start_detected = (scl_safe == 1'b1) && sda_falling;
    assign stop_detected = (scl_safe == 1'b1) && sda_rising;
    //
    assign sda_o = sda_r;
    assign busy = (state != IDLE);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            bit_cnt      <= 0;
            rx_shift_reg <= 0;
            tx_shift_reg <= 0;
            is_read      <= 1'b0;
            rx_done      <= 1'b0;
            tx_req       <= 1'b0;
            ack_out      <= 1'b1;
            ack_in_r     <= 1'b1;
            rx_data      <= 0;
        end else if (start_detected) begin
            // START (또는 Repeated Start) 감지 시 초기화 후 수신 대기
            state   <= RX_ADDR;
            bit_cnt <= 0;
            rx_done <= 1'b0;
            tx_req  <= 1'b0;
        end else if (stop_detected) begin
            // STOP 감지 시 모든 동작 중지 후 대기 상태로 복귀
            state   <= IDLE;
            rx_done <= 1'b0;
            tx_req  <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            tx_req  <= 1'b0;
            case (state)
                IDLE: begin
                    // start_detected 예외 처리로 알아서 빠져나가므로 여기선 대기
                end
                RX_ADDR: begin
                    if (scl_rising) begin
                        // SCL이 상승할 때 주소(7bit) + R/W(1bit) 샘플링
                        rx_shift_reg <= {rx_shift_reg[6:0], sda_safe};
                        bit_cnt <= bit_cnt + 1;
                    end else if (scl_falling) begin
                        if (bit_cnt == 8) begin
                            state <= ADDR_ACK;
                            bit_cnt <= 0;
                            is_read <= rx_shift_reg[0]; // 8번째 비트는 R/W signal 
                        end
                    end
                end
                ADDR_ACK: begin
                    if (scl_falling) begin
                        // 수신한 주소(상위 7비트)가 내 주소와 일치하는지 확인
                        if (rx_shift_reg[7:1] == SLAVE_ADDR) begin
                            state <= DATA;
                            if (is_read) begin
                                // 마스터가 읽기를 원하면(Slave TX), 데이터를 보낼 준비
                                tx_shift_reg <= tx_data; // 외부에서 데이터 로드
                                tx_req       <= 1'b1;    // 시스템에 다음 데이터 준비 요청
                            end
                        end else begin
                            state <= IDLE;
                        end
                    end
                end
                DATA: begin
                    if (scl_rising) begin
                        if (!is_read) begin
                            rx_shift_reg <= {rx_shift_reg[6:0], sda_safe};
                        end
                        bit_cnt <= bit_cnt + 1;
                        // [RX 모드] SCL 상승 시 마스터가 보낸 데이터 샘플링
                    end else if (scl_falling) begin
                        // [TX 모드] SCL 하강 시 다음 비트를 내보내기 위해 시프트
                        if (is_read) begin
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                        // 8비트 처리 완료 시
                        if (bit_cnt == 8) begin
                            state   <= DATA_ACK;
                            bit_cnt <= 0;
                            if (!is_read) begin
                                // [RX 모드] 8비트를 다 받았으므로 내부 시스템에 데이터 전달
                                rx_data <= rx_shift_reg;
                                rx_done <= 1'b1;
                                ack_in_r <= ack_in; // 내가 보낼 ACK 상태 캡처
                            end
                        end
                    end
                end
                DATA_ACK: begin
                    if (scl_rising && is_read) begin
                        // [TX 모드] 내가 데이터를 보낸 후, 마스터의 응답(ACK/NACK) 확인
                        ack_out <= sda_safe;
                    end else if (scl_falling) begin
                        if (is_read && ack_out == 1'b1) begin
                            state <= IDLE;
                        end else begin
                            // 다시 데이터 송수신 상태로 루프
                            state <= DATA;
                            if (is_read) begin
                                // [TX 모드] 마스터가 계속 읽겠다고 할 경우 다음 데이터 로드 준비
                                tx_shift_reg <= tx_data;
                                tx_req       <= 1'b1;
                            end
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    always_comb begin
        sda_r = 1'b1;  // Default: 버스에서 손 떼기 (High-Z)
        case (state)
            ADDR_ACK: begin
                if (rx_shift_reg[7:1] == SLAVE_ADDR) begin
                    sda_r = 1'b0;  // 내 주소면 ACK(0) 출력
                end else begin
                    sda_r = 1'b1;  // 아니면 무시(NACK)
                end
            end
            DATA: begin
                if (is_read) begin
                    // [TX 모드] 시프트 레지스터의 최상위 비트(MSB)를 SDA로 출력
                    sda_r = tx_shift_reg[7];
                end
            end
            DATA_ACK: begin
                if (!is_read) begin
                    // [RX 모드] 캡처해둔 안전한 응답(ACK/NACK)을 마스터에게 출력
                    sda_r = ack_in_r;
                end
            end
            // IDLE, RX_ADDR 상태는 기본값(1'b1) 유지
        endcase
    end
endmodule
