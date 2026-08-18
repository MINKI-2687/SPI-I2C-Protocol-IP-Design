`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// 0. Interface
interface i2c_if (input logic clk, input logic reset);
    // 마스터 제어 포트
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

    // 슬레이브 제어 포트
    logic [7:0] slv_tx_data;
    logic       slv_ack_in;
    logic [7:0] slv_rx_data;
    logic       slv_ack_out;
    logic       slv_rx_done;
    logic       slv_tx_req;
    logic       slv_busy;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output mst_cmd_start, mst_cmd_write, mst_cmd_read, mst_cmd_stop;
        output mst_tx_data, mst_ack_in;
        output slv_tx_data, slv_ack_in;
        input  mst_done, mst_busy, mst_ack_out;
        input  slv_rx_data, slv_ack_out, slv_rx_done, slv_tx_req, slv_busy;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input mst_cmd_start, mst_cmd_write, mst_cmd_read, mst_cmd_stop;
        input mst_tx_data, mst_ack_in, mst_rx_data, mst_done, mst_busy, mst_ack_out;
        input slv_tx_data, slv_ack_in, slv_rx_data, slv_ack_out, slv_rx_done, slv_tx_req, slv_busy;
    endclocking
endinterface

// 1. Sequence Item
class i2c_seq_item extends uvm_sequence_item;
    rand bit       is_read;     // 0: Write, 1: Read
    rand bit [6:0] slave_addr;  // 타겟 주소
    rand logic [7:0] m_tx_data; // 마스터 송신 데이터 (Write 시)
    rand logic [7:0] s_tx_data; // 슬레이브 송신 데이터 (Read 시)

    logic [7:0] m_rx_data;      // 마스터 수신 결과
    logic [7:0] s_rx_data;      // 슬레이브 수신 결과

    constraint addr_c { slave_addr == 7'h12; }
    constraint data_dist_c {
        // m_tx_data
        m_tx_data dist {
            8'h00 := 10,
            8'hFF := 10,
            8'h55 := 10,
            8'hAA := 10,
            [8'h00:8'hFF] :/ 60
        };
       // s_tx_data
        s_tx_data dist {
            8'h00 := 10,
            8'hFF := 10,
            8'h55 := 10,
            8'hAA := 10,
            [8'h00:8'hFF] :/ 60
        };
    }

    `uvm_object_utils_begin(i2c_seq_item)
    `uvm_field_int(is_read,    UVM_ALL_ON)
    `uvm_field_int(slave_addr, UVM_ALL_ON)
    `uvm_field_int(m_tx_data,  UVM_ALL_ON)
    `uvm_field_int(s_tx_data,  UVM_ALL_ON)
    `uvm_field_int(m_rx_data,  UVM_ALL_ON)
    `uvm_field_int(s_rx_data,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        string mode = is_read ? "READ " : "WRITE";
        return $sformatf("[%s] Addr:0x%02h | M_TX:0x%02h, M_RX:0x%02h | S_TX:0x%02h, S_RX:0x%02h",
            mode, slave_addr, m_tx_data, m_rx_data, s_tx_data, s_rx_data);
    endfunction
endclass

// 2. Sequence
class i2c_rand_seq extends uvm_sequence#(i2c_seq_item);
    `uvm_object_utils(i2c_rand_seq)
    int num_trans = 200;

    function new(string name = "i2c_rand_seq");
        super.new(name);
    endfunction

    task body();
        i2c_seq_item item;
        repeat(num_trans) begin
            item = i2c_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_fatal(get_type_name(), "Randomize failed!")
            finish_item(item);
        end
    endtask
endclass

// 3. Driver
class i2c_driver extends uvm_driver#(i2c_seq_item);
    `uvm_component_utils(i2c_driver)
    virtual i2c_if i_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if))
            `uvm_fatal(get_type_name(), "Cannot find i_if!")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item item;

        // 초기화
        i_if.drv_cb.mst_cmd_start <= 1'b0;
        i_if.drv_cb.mst_cmd_write <= 1'b0;
        i_if.drv_cb.mst_cmd_read  <= 1'b0;
        i_if.drv_cb.mst_cmd_stop  <= 1'b0;
        i_if.drv_cb.mst_ack_in    <= 1'b1;
        i_if.drv_cb.slv_ack_in    <= 1'b0;

        wait(i_if.reset == 0);
        @(i_if.drv_cb);

        forever begin
            seq_item_port.get_next_item(item);

            // 슬레이브 송신 데이터 세팅 (Read 테스트용)
            i_if.drv_cb.slv_tx_data <= item.s_tx_data;
            @(i_if.drv_cb);

            // 1. START
            pulse_cmd(1, 0, 0, 0);

            // 2. ADDR + R/W
            i_if.drv_cb.mst_tx_data <= (item.slave_addr << 1) | item.is_read;
            pulse_cmd(0, 1, 0, 0);

            // 3. DATA (Write or Read)
            if (!item.is_read) begin
                i_if.drv_cb.mst_tx_data <= item.m_tx_data;
                pulse_cmd(0, 1, 0, 0);
            end else begin
                i_if.drv_cb.mst_ack_in <= 1'b1;
                @(i_if.drv_cb);
                pulse_cmd(0, 0, 1, 0);
                i_if.drv_cb.mst_ack_in <= 1'b0;
            end

            // 4. STOP
            pulse_cmd(0, 0, 0, 1);
            seq_item_port.item_done();
        end
    endtask

    // 마스터에게 1클럭 펄스 명령을 주고 완료를 기다리는 Task
    task pulse_cmd(bit start, bit write, bit read, bit stop);
        i_if.drv_cb.mst_cmd_start <= start;
        i_if.drv_cb.mst_cmd_write <= write;
        i_if.drv_cb.mst_cmd_read  <= read;
        i_if.drv_cb.mst_cmd_stop  <= stop;
        @(i_if.drv_cb);
        i_if.drv_cb.mst_cmd_start <= 1'b0;
        i_if.drv_cb.mst_cmd_write <= 1'b0;
        i_if.drv_cb.mst_cmd_read  <= 1'b0;
        i_if.drv_cb.mst_cmd_stop  <= 1'b0;
        wait(i_if.mst_done); // FSM 완료 대기
        @(i_if.drv_cb);
    endtask
endclass

// 4. Monitor
class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)
    uvm_analysis_port#(i2c_seq_item) ap;
    virtual i2c_if i_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if))
            `uvm_fatal(get_type_name(), "Cannot find i_if!")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item item;
        forever begin
            item = i2c_seq_item::type_id::create("item");

            // 1. START 캡처 (마스터가 Start 명령을 내릴 때까지 대기)
            do begin
                @(i_if.mon_cb);
            end while (i_if.mon_cb.mst_cmd_start !== 1'b1);

            // 2. ADDR 캡처 (첫 번째 Write 명령이 바로 주소 전송 타이밍)
            do begin
                @(i_if.mon_cb);
            end while (i_if.mon_cb.mst_cmd_write !== 1'b1);

            item.is_read    = i_if.mon_cb.mst_tx_data[0];
            item.slave_addr = i_if.mon_cb.mst_tx_data[7:1];

            // 3. DATA 캡처 (두 번째 Write 또는 Read 명령이 데이터 전송 타이밍)
            do begin
                @(i_if.mon_cb);
            end while (i_if.mon_cb.mst_cmd_write !== 1'b1 && i_if.mon_cb.mst_cmd_read !== 1'b1);

            if (!item.is_read) begin
                // Write 모드: 마스터가 버스에 올린 데이터를 캡처
                item.m_tx_data = i_if.mon_cb.mst_tx_data;
            end else begin
                // Read 모드: 슬레이브가 버스에 올릴 준비를 한 데이터를 캡처
                item.s_tx_data = i_if.mon_cb.slv_tx_data;
            end

            // 4. STOP 캡처
            do begin
                @(i_if.mon_cb);
            end while (i_if.mon_cb.mst_cmd_stop !== 1'b1);

            // 5. 최종 결과 캡처 (통신이 물리적으로 완전히 끝날 때까지 대기)
            wait(i_if.mon_cb.mst_done);
            @(i_if.mon_cb); // 안정화를 위한 1클럭 여유

            item.m_rx_data = i_if.mon_cb.mst_rx_data;
            item.s_rx_data = i_if.mon_cb.slv_rx_data;

            // 조립 완료된 Item을 Scoreboard로 전송
            ap.write(item);
        end
    endtask

endclass

// 5. Scoreboard
class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)
    uvm_analysis_imp#(i2c_seq_item, i2c_scoreboard) ap_imp;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(i2c_seq_item item);
        bit is_match = 1'b1;

        if (!item.is_read) begin
            // Write 모드: 마스터 송신 데이터가 슬레이브에 잘 도착했는가?
            if (item.m_tx_data !== item.s_rx_data) is_match = 1'b0;
        end else begin
            // Read 모드: 슬레이브 송신 데이터가 마스터에 잘 도착했는가?
            if (item.s_tx_data !== item.m_rx_data) is_match = 1'b0;
        end

        if (!is_match) begin
            fail_cnt++;
            `uvm_error(get_type_name(), $sformatf("MISMATCH! %s", item.convert2string()))
        end else begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("MATCH! %s", item.convert2string()), UVM_MEDIUM)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "===== Scoreboard Summary =====", UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("  Pass: %0d | Fail: %0d", pass_cnt, fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Total transactions: %0d",
            pass_cnt + fail_cnt), UVM_LOW)

        `uvm_info(get_type_name(), $sformatf("  Pass: %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Fail: %0d", fail_cnt), UVM_LOW)
        if (fail_cnt > 0) `uvm_error(get_type_name(), "TEST FAILED!")
        else              `uvm_info(get_type_name(), "TEST PASSED!", UVM_LOW)
    endfunction
endclass

// 6. Coverage
class i2c_coverage extends uvm_subscriber#(i2c_seq_item);
    `uvm_component_utils(i2c_coverage)

    bit       cov_is_read;
    logic [7:0] cov_data;

    covergroup cg_i2c;
        cp_mode: coverpoint cov_is_read {
            bins write_mode = {0};
            bins read_mode  = {1};
        }
        cp_data: coverpoint cov_data {
            bins zero     = {8'h00};
            bins max      = {8'hFF};
            bins alt_55   = {8'h55};
            bins alt_AA   = {8'hAA};
            bins others   = default;
        }
        cross_mode_data: cross cp_mode, cp_data;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_i2c = new();
    endfunction

    function void write(i2c_seq_item t);
        cov_is_read = t.is_read;
        // Write일 때는 마스터가 보낸 데이터를, Read일 때는 슬레이브가 보낸 데이터를 수집
        cov_data    = t.is_read ? t.s_tx_data : t.m_tx_data;
        cg_i2c.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "\n\n===== I2C Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("      Overall            : %.1f%%", cg_i2c.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("      Mode (R/W)         : %.1f%%", cg_i2c.cp_mode.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("      Data Pattern       : %.1f%%", cg_i2c.cp_data.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("      Cross (Mode x Data): %.1f%%",
                cg_i2c.cross_mode_data.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), "===== I2C Coverage Summary =====\n\n", UVM_LOW)
    endfunction
endclass

// 7. Agent, Env, Test & Top Module
class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)
    i2c_driver  drv;
    i2c_monitor mon;
    uvm_sequencer#(i2c_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = i2c_driver::type_id::create("drv", this);
        mon = i2c_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)
    i2c_agent      agt;
    i2c_scoreboard scb;
    i2c_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = i2c_agent::type_id::create("agt", this);
        scb = i2c_scoreboard::type_id::create("scb", this);
        cov = i2c_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

class i2c_rand_test extends uvm_test;
    `uvm_component_utils(i2c_rand_test)
    i2c_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = i2c_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_rand_seq seq;
        phase.raise_objection(this);
        seq = i2c_rand_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass

module tb_i2c ();
    logic clk;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
    end

    i2c_if i_if (.clk(clk), .reset(reset));

    wire sda;
    wire scl;
    pullup(sda); // I2C 버스 풀업 저항 모사
    pullup(scl);

    // DUT 연결
    i2c_top dut (
        .clk          (clk),
        .reset        (reset),
        .mst_cmd_start(i_if.mst_cmd_start),
        .mst_cmd_write(i_if.mst_cmd_write),
        .mst_cmd_read (i_if.mst_cmd_read),
        .mst_cmd_stop (i_if.mst_cmd_stop),
        .mst_tx_data  (i_if.mst_tx_data),
        .mst_ack_in   (i_if.mst_ack_in),
        .mst_rx_data  (i_if.mst_rx_data),
        .mst_done     (i_if.mst_done),
        .mst_busy     (i_if.mst_busy),
        .mst_ack_out  (i_if.mst_ack_out),
        .slv_tx_data  (i_if.slv_tx_data),
        .slv_ack_in   (i_if.slv_ack_in),
        .slv_rx_data  (i_if.slv_rx_data),
        .slv_ack_out  (i_if.slv_ack_out),
        .slv_rx_done  (i_if.slv_rx_done),
        .slv_tx_req   (i_if.slv_tx_req),
        .slv_busy     (i_if.slv_busy),
        .sda          (sda),
        .scl          (scl)
    );

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "*", "i_if", i_if);
        run_test("i2c_rand_test");
    end
endmodule
