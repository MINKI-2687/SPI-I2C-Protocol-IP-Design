`timescale 1ns / 1ps

module tb_i2c_top ();
    logic       clk;
    logic       reset;
    // Master Signals
    logic       mst_cmd_start;
    logic       mst_cmd_write;
    logic       mst_cmd_read;
    logic       mst_cmd_stop;
    logic [7:0] mst_tx_data;
    logic       mst_ack_in;
    logic [7:0] mst_rx_data;
    logic       mst_done;
    logic       mst_busy;
    logic       mst_ack_out;
    // Slave Signals
    logic [7:0] slv_tx_data;
    logic       slv_ack_in;
    logic [7:0] slv_rx_data;
    logic       slv_ack_out;
    logic       slv_rx_done;
    logic       slv_tx_req;
    logic       slv_busy;
    // tri1: 아무도 구동하지 않으면 자동으로 1이 되는 선
    tri1        sda;
    tri1        scl;

    localparam SLA = 7'h12;

    i2c_top dut (.*);

    always #5 clk = ~clk;
    // 1. Master 제어용 BFM Tasks
    task i2c_start();
        mst_cmd_start = 1'b1;
        mst_cmd_write = 1'b0;
        mst_cmd_read  = 1'b0;
        mst_cmd_stop  = 1'b0;
        @(posedge clk);
        wait (mst_done);
        @(posedge clk);
    endtask

    task i2c_addr(byte addr);
        mst_tx_data   = addr;
        mst_cmd_start = 1'b0;
        mst_cmd_write = 1'b1;
        mst_cmd_read  = 1'b0;
        mst_cmd_stop  = 1'b0;
        @(posedge clk);
        wait (mst_done);
        @(posedge clk);
    endtask

    task i2c_write(byte data);
        mst_tx_data   = data;
        mst_cmd_start = 1'b0;
        mst_cmd_write = 1'b1;
        mst_cmd_read  = 1'b0;
        mst_cmd_stop  = 1'b0;
        @(posedge clk);
        wait (mst_done);
        @(posedge clk);
    endtask

    task i2c_read(logic ack_val);
        mst_ack_in    = ack_val;
        mst_cmd_start = 1'b0;
        mst_cmd_write = 1'b0;
        mst_cmd_read  = 1'b1;
        mst_cmd_stop  = 1'b0;
        @(posedge clk);
        wait (mst_done);
        @(posedge clk);
    endtask

    task i2c_stop();
        mst_cmd_start = 1'b0;
        mst_cmd_write = 1'b0;
        mst_cmd_read  = 1'b0;
        mst_cmd_stop  = 1'b1;
        @(posedge clk);
        wait (mst_done);
        @(posedge clk);
    endtask

    // 2. Slave 에뮬레이션 블록
    always_ff @(posedge clk) begin
        if (reset) begin
            slv_ack_in  <= 1'b0;
            slv_tx_data <= 8'hC0;
        end else begin
            if (slv_tx_req) begin
                slv_tx_data <= slv_tx_data + 1;
            end
        end
    end

    // 3. 메인 테스트 시나리오
    initial begin
        clk = 0;
        reset = 1;
        mst_cmd_start = 0;
        mst_cmd_write = 0;
        mst_cmd_read = 0;
        mst_cmd_stop = 0;

        repeat (5) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // [시나리오 1] 마스터 -> 슬레이브 Burst Write
        i2c_start();
        i2c_addr((SLA << 1) | 1'b0);
        i2c_write(8'h55);
        i2c_write(8'hAA);
        i2c_stop();

        #100;

        // [시나리오 2] 슬레이브 -> 마스터 Read 테스트
        i2c_start();
        i2c_addr((SLA << 1) | 1'b1);
        i2c_read(1'b0);
        i2c_read(1'b1);
        i2c_stop();

        #100;
        $finish;
    end

endmodule
