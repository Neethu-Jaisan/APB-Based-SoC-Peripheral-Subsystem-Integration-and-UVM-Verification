import uvm_pkg::*;
`include "uvm_macros.svh"

// ==========================================================
// TRANSACTION
// ==========================================================

class apb_txn extends uvm_sequence_item;

  rand bit write;
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

  bit [7:0] saved_addr[5];

  function new(string name="apb_sequence");
    super.new(name);
  endfunction

  task body();
    apb_txn tx;

    // WRITE
    for(int i=0;i<5;i++) begin
      tx = apb_txn::type_id::create($sformatf("write_%0d",i));
      assert(tx.randomize() with { write == 1; });
      saved_addr[i] = tx.addr;
      start_item(tx);
      finish_item(tx);
    end

    // READ
    for(int i=0;i<5;i++) begin
      tx = apb_txn::type_id::create($sformatf("read_%0d",i));
      tx.write = 0;
      tx.addr  = saved_addr[i];
      tx.data  = 0;
      start_item(tx);
      finish_item(tx);
    end
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
      `uvm_fatal("NOVIF","Virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn tx;

    forever begin
      seq_item_port.get_next_item(tx);

      `uvm_info("DRIVER",
        $sformatf("Driving: write=%0b addr=%0h data=%0h",
        tx.write, tx.addr, tx.data), UVM_MEDIUM)

      @(posedge vif.PCLK);
      vif.PSEL    <= 1;
      vif.PWRITE  <= tx.write;
      vif.PADDR   <= tx.addr;
      vif.PWDATA  <= tx.data;
      vif.PENABLE <= 0;

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

  covergroup apb_cg;
    coverpoint vif.PWRITE;
    coverpoint vif.PADDR;
    cross vif.PWRITE, vif.PADDR;
  endgroup

  `uvm_component_utils(apb_monitor)

  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap = new("ap",this);
    apb_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","Virtual interface not set")
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
          @(posedge vif.PCLK); // wait for PRDATA
          tx.data = vif.PRDATA;
        end

        apb_cg.sample();

        `uvm_info("MONITOR",
          $sformatf("Observed: write=%0b addr=%0h data=%0h",
          tx.write, tx.addr, tx.data), UVM_MEDIUM)

        ap.write(tx);
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("COVERAGE",
      $sformatf("Functional Coverage = %0.2f %%", apb_cg.get_coverage()),
      UVM_NONE)
  endfunction

endclass



// ==========================================================
// SCOREBOARD
// ==========================================================

class apb_scoreboard extends uvm_component;

  uvm_analysis_imp #(apb_txn, apb_scoreboard) imp;
  bit [31:0] model_mem[256];

  int write_count;
  int read_count;

  `uvm_component_utils(apb_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name,parent);
    imp = new("imp",this);
  endfunction

  function void write(apb_txn tx);

    if(tx.write) begin
      model_mem[tx.addr] = tx.data;
      write_count++;
      `uvm_info("SCOREBOARD",
        $sformatf("WRITE OK addr=%0h data=%0h",
        tx.addr, tx.data), UVM_LOW)
    end
    else begin
      read_count++;
      if(model_mem[tx.addr] === tx.data)
        `uvm_info("SCOREBOARD",
          $sformatf("READ MATCH addr=%0h data=%0h",
          tx.addr, tx.data), UVM_LOW)
      else
        `uvm_error("SCOREBOARD",
          $sformatf("READ MISMATCH addr=%0h expected=%0h got=%0h",
          tx.addr, model_mem[tx.addr], tx.data))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD",
      $sformatf("Total Writes=%0d Total Reads=%0d",
      write_count, read_count), UVM_NONE)
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
    drv  = apb_driver::type_id::create("drv", this);
    mon  = apb_monitor::type_id::create("mon", this);
    sb   = apb_scoreboard::type_id::create("sb", this);
    seqr = uvm_sequencer#(apb_txn)::type_id::create("seqr", this);
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
    env = apb_env::type_id::create("env", this);
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

    `uvm_info("TEST",
    "=========================================", UVM_NONE)
    `uvm_info("TEST",
    "APB MINI SOC VERIFICATION PASSED", UVM_NONE)
    `uvm_info("TEST",
    "=========================================", UVM_NONE)

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

  mini_soc dut(
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
