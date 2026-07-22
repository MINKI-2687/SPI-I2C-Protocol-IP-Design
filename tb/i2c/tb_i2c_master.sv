`timescale 1ns / 1ps

module tb_i2c_master ();

    logic       clk;
    logic       reset;
    // command port
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] tx_data;
    logic       ack_in;
    // internal output
    logic [7:0] rx_data;
    logic       done;
    logic       busy;
    logic       ack_out;
    // external i2c port
    wire        sda;
    logic       scl;

    // pull up
    //assign sda = 1'b1;

    localparam SLA = 8'h12;

    I2C_Master dut (
        .*,
        .scl(scl),
        .sda(sda)
    );

    always #5 clk = ~clk;

    task i2c_start();
        // start
        cmd_start = 1'b1;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_addr(byte addr);
        // tx_data = address(8'h12) + rw
        tx_data   = addr;
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);  // wait ack
        @(posedge clk);
    endtask

    task i2c_write(byte data);
        tx_data   = data;
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);  // wait ack
        @(posedge clk);
    endtask

    task i2c_read();
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b1;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);  // wait ack
        @(posedge clk);
    endtask

    task i2c_stop();
        // stop
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b1;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        i2c_start();
        i2c_addr({(SLA << 1) + 1'b0});
        i2c_write(8'h55);
        i2c_write(8'haa);
        i2c_write(8'h01);
        i2c_write(8'h02);
        i2c_write(8'h03);
        i2c_write(8'h04);
        i2c_write(8'h05);
        i2c_write(8'hff);
        i2c_stop();

        // IDLE state
        #100;
        $finish;
    end
endmodule
