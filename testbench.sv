`timescale 1ns/1ns
import uvm_pkg::*;
`include "uvm_macros.svh"



// ==========================================================
// TRANSACTION
// ==========================================================
class apb_txn extends uvm_sequence_item;
  rand bit        write;
  rand bit [7:0]  addr;
  rand bit [31:0] data;

  constraint c_addr {
    addr inside {
      [8'h00:8'h0F],
      8'h40, 8'h44,
      8'h50,
      [8'h60:8'h6C]
    };
  }

  `uvm_object_utils(apb_txn)

  function new(string name="apb_txn");
    super.new(name);
  endfunction
endclass


// ==========================================================
// SEQUENCE
// ==========================================================
class apb_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_seq)

  function new(string name="apb_seq");
    super.new(name);
  endfunction

  task body();
    repeat(500) begin
      `uvm_do(req)
    end
  endtask
endclass


// ==========================================================
// COVERAGE
// ==========================================================
class apb_coverage extends uvm_subscriber #(apb_txn);
  `uvm_component_utils(apb_coverage)

  apb_txn tr;

  covergroup cg_apb;
    option.per_instance = 1;

    ADDR_BINS: coverpoint tr.addr {
      bins MEM  = {[8'h00:8'h0F]};
      bins TIM  = {8'h40, 8'h44};
      bins GPIO = {8'h50};
      bins ALU  = {[8'h60:8'h6C]};
    }

    ALU_OPS: coverpoint tr.data[1:0] iff (tr.addr == 8'h68 && tr.write) {
      bins ADD = {2'b00};
      bins SUB = {2'b01};
      bins AND = {2'b10};
      bins OR  = {2'b11};
    }

    RW_X_ADDR: cross ADDR_BINS, tr.write;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_apb = new();
  endfunction

  function void write(apb_txn t);
    tr = t;
    cg_apb.sample();
  endfunction
endclass


// ==========================================================
// DRIVER
// ==========================================================
class apb_driver extends uvm_driver #(apb_txn);
  virtual soc_if vif;

  `uvm_component_utils(apb_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","No VIF")
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn tx;

    forever begin
      seq_item_port.get_next_item(tx);

      @(posedge vif.PCLK);
      vif.PSEL    <= 1;
      vif.PENABLE <= 0;
      vif.PWRITE  <= tx.write;
      vif.PADDR   <= tx.addr;
      vif.PWDATA  <= tx.data;

      @(posedge vif.PCLK);
      vif.PENABLE <= 1;

      @(posedge vif.PCLK);
      vif.PSEL    <= 0;
      vif.PENABLE <= 0;

      @(posedge vif.PCLK); // idle

      seq_item_port.item_done();
    end
  endtask
endclass


// ==========================================================
// MONITOR
// ==========================================================
class apb_monitor extends uvm_monitor;
  virtual soc_if vif;
  uvm_analysis_port #(apb_txn) ap;

  `uvm_component_utils(apb_monitor)

  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap = new("ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","No VIF")
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn tx;

    forever begin
      @(posedge vif.PCLK);

      if(vif.PSEL && vif.PENABLE) begin
        tx = apb_txn::type_id::create("tx");

        tx.write = vif.PWRITE;
        tx.addr  = vif.PADDR;

        @(posedge vif.PCLK);

        if(tx.write)
          tx.data = vif.PWDATA;
        else
          tx.data = vif.PRDATA;

        ap.write(tx);
      end
    end
  endtask
endclass


// ==========================================================
// SCOREBOARD
// ==========================================================
class apb_scoreboard extends uvm_component;
  uvm_analysis_imp #(apb_txn, apb_scoreboard) imp;

  bit [31:0] mem_model[0:63];
  bit [7:0]  gpio_model;
  bit [31:0] alu_A, alu_B;
  bit [1:0]  alu_op;

  `uvm_component_utils(apb_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name,parent);
    imp = new("imp",this);
  endfunction

  function void build_phase(uvm_phase phase);
    foreach(mem_model[i]) mem_model[i] = 0;
  endfunction

  function void write(apb_txn tx);

    if(tx.write) begin
      if(tx.addr inside {[8'h00:8'h0F]})
        mem_model[tx.addr] = tx.data;
      else if(tx.addr == 8'h50)
        gpio_model = tx.data[7:0];
      else if(tx.addr == 8'h60) alu_A = tx.data;
      else if(tx.addr == 8'h64) alu_B = tx.data;
      else if(tx.addr == 8'h68) alu_op = tx.data[1:0];
    end
    else begin
      bit [31:0] exp;

      if(tx.addr inside {[8'h00:8'h0F]})
        exp = mem_model[tx.addr];
      else if(tx.addr == 8'h50)
        exp = {24'd0, gpio_model};
      else if(tx.addr == 8'h6C) begin
        case(alu_op)
          2'b00: exp = alu_A + alu_B;
          2'b01: exp = alu_A - alu_B;
          2'b10: exp = alu_A & alu_B;
          2'b11: exp = alu_A | alu_B;
        endcase
      end
      else if(tx.addr == 8'h44)
        return;
      else
        return;

      if(exp !== tx.data)
        `uvm_error("SB",$sformatf("Mismatch Addr:%h Exp:%h Got:%h",
                                  tx.addr, exp, tx.data))
      else
        `uvm_info("SB",$sformatf("MATCH Addr:%h Data:%h",
                                 tx.addr, tx.data), UVM_LOW)
    end
  endfunction
endclass


// ==========================================================
// ENV
// ==========================================================
class apb_env extends uvm_env;
  apb_driver drv;
  apb_monitor mon;
  apb_scoreboard sb;
  apb_coverage cov;
  uvm_sequencer #(apb_txn) seqr;

  `uvm_component_utils(apb_env)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    drv  = apb_driver::type_id::create("drv",this);
    mon  = apb_monitor::type_id::create("mon",this);
    sb   = apb_scoreboard::type_id::create("sb",this);
    cov  = apb_coverage::type_id::create("cov",this);
    seqr = uvm_sequencer#(apb_txn)::type_id::create("seqr",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(sb.imp);
    mon.ap.connect(cov.analysis_export);
  endfunction
endclass


// ==========================================================
// TEST
// ==========================================================
class apb_test extends uvm_test;
  apb_env env;

  `uvm_component_utils(apb_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    env = apb_env::type_id::create("env",this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq seq = apb_seq::type_id::create("seq");

    phase.raise_objection(this);

    env.drv.vif.PRESETn = 0;
    #20;
    env.drv.vif.PRESETn = 1;

    seq.start(env.seqr);

    #100;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("FINAL_COV",
      $sformatf("Coverage: %0.2f%%",
        env.cov.cg_apb.get_inst_coverage()),
      UVM_NONE)
  endfunction
endclass


// ==========================================================
// TOP
// ==========================================================
module tb;
  bit PCLK = 0;
  always #5 PCLK = ~PCLK;

  soc_if vif(PCLK);

  soc_subsystem dut (
    .PCLK(PCLK),
    .PRESETn(vif.PRESETn),
    .PSEL(vif.PSEL),
    .PENABLE(vif.PENABLE),
    .PWRITE(vif.PWRITE),
    .PADDR(vif.PADDR),
    .PWDATA(vif.PWDATA),
    .PRDATA(vif.PRDATA)
  );

  initial begin
    uvm_config_db#(virtual soc_if)::set(null,"*","vif",vif);
    run_test("apb_test");
  end
endmodule
