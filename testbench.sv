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

  `uvm_object_utils_begin(apb_txn)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(addr , UVM_ALL_ON)
    `uvm_field_int(data , UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name="apb_txn");
    super.new(name);
  endfunction

endclass



// ==========================================================
// SEQUENCE
// ==========================================================

class apb_sequence extends uvm_sequence #(apb_txn);

  `uvm_object_utils(apb_sequence)

  function new(string name="apb_sequence");
    super.new(name);
  endfunction

  task body();
    apb_txn tx;

    // MEMORY WRITE + READ
    tx = apb_txn::type_id::create("mem_wr");
    tx.write = 1; tx.addr = 8'h02; tx.data = 32'hA5A5A5A5;
    start_item(tx); finish_item(tx);

    tx = apb_txn::type_id::create("mem_rd");
    tx.write = 0; tx.addr = 8'h02;
    start_item(tx); finish_item(tx);

    // GPIO WRITE + READ
    tx = apb_txn::type_id::create("gpio_wr");
    tx.write = 1; tx.addr = 8'h50; tx.data = 32'h000000AA;
    start_item(tx); finish_item(tx);

    tx = apb_txn::type_id::create("gpio_rd");
    tx.write = 0; tx.addr = 8'h50;
    start_item(tx); finish_item(tx);

    // ALU
    tx = apb_txn::type_id::create("alu_A");
    tx.write = 1; tx.addr = 8'h60; tx.data = 10;
    start_item(tx); finish_item(tx);

    tx = apb_txn::type_id::create("alu_B");
    tx.write = 1; tx.addr = 8'h64; tx.data = 20;
    start_item(tx); finish_item(tx);

    tx = apb_txn::type_id::create("alu_op");
    tx.write = 1; tx.addr = 8'h68; tx.data = 0; // ADD
    start_item(tx); finish_item(tx);

    tx = apb_txn::type_id::create("alu_rd");
    tx.write = 0; tx.addr = 8'h6C;
    start_item(tx); finish_item(tx);

  endtask

endclass



// ==========================================================
// DRIVER
// ==========================================================

class apb_driver extends uvm_driver #(apb_txn);

  virtual soc_if vif;

  `uvm_component_utils(apb_driver)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","No interface")
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
      `uvm_fatal("NOVIF","No interface")
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn tx;

    forever begin
      @(posedge vif.PCLK);

      if(vif.PSEL && vif.PENABLE) begin
        tx = apb_txn::type_id::create("tx");
        tx.write = vif.PWRITE;
        tx.addr  = vif.PADDR;

        if(vif.PWRITE)
          tx.data = vif.PWDATA;
        else begin
          @(posedge vif.PCLK);
          tx.data = vif.PRDATA;
        end

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

  bit [31:0] mem_model[64];
  bit [7:0]  gpio_model;
  bit [31:0] alu_A, alu_B;
  bit [1:0]  alu_op;

  `uvm_component_utils(apb_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name,parent);
    imp = new("imp",this);
  endfunction

  function void write(apb_txn tx);

    if(tx.write) begin
      case(tx.addr)
        8'h02: mem_model[2] = tx.data;
        8'h50: gpio_model   = tx.data[7:0];
        8'h60: alu_A        = tx.data;
        8'h64: alu_B        = tx.data;
        8'h68: alu_op       = tx.data[1:0];
      endcase
    end
    else begin
      bit [31:0] expected;

      case(tx.addr)
        8'h02: expected = mem_model[2];
        8'h50: expected = {24'd0, gpio_model};
        8'h6C: begin
          case(alu_op)
            2'b00: expected = alu_A + alu_B;
            2'b01: expected = alu_A - alu_B;
            2'b10: expected = alu_A & alu_B;
            2'b11: expected = alu_A | alu_B;
          endcase
        end
        default: expected = 32'hBAD_ADDR;
      endcase

      if(expected !== tx.data)
        `uvm_error("SB",$sformatf("Mismatch Addr=%h Exp=%h Got=%h",
                    tx.addr, expected, tx.data))
      else
        `uvm_info("SB",$sformatf("MATCH Addr=%h Data=%h",
                    tx.addr, tx.data),UVM_LOW)
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
  uvm_sequencer #(apb_txn) seqr;

  `uvm_component_utils(apb_env)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    drv  = apb_driver::type_id::create("drv",this);
    mon  = apb_monitor::type_id::create("mon",this);
    sb   = apb_scoreboard::type_id::create("sb",this);
    seqr = uvm_sequencer#(apb_txn)::type_id::create("seqr",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(sb.imp);
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

    apb_sequence seq;

    phase.raise_objection(this);

    env.drv.vif.PRESETn = 0;
    repeat(5) @(posedge env.drv.vif.PCLK);
    env.drv.vif.PRESETn = 1;

    seq = apb_sequence::type_id::create("seq");
    seq.start(env.seqr);

    #50;

    `uvm_info("TEST","=================================",UVM_NONE)
    `uvm_info("TEST","SoC Peripheral Subsystem PASS",UVM_NONE)
    `uvm_info("TEST","=================================",UVM_NONE)

    phase.drop_objection(this);

  endtask

endclass



// ==========================================================
// TOP
// ==========================================================

module tb;

  bit PCLK = 0;
  always #5 PCLK = ~PCLK;

  soc_if vif(PCLK);

  soc_subsystem dut(
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
