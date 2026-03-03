interface soc_if(input logic PCLK);

  logic PRESETn;
  logic PSEL;
  logic PENABLE;
  logic PWRITE;
  logic [7:0]  PADDR;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;

endinterface



// ---------------- Memory Block ----------------
module apb_memory (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [31:0] mem [0:63];

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if(!PRESETn)
      PRDATA <= 0;
    else if(PSEL && PENABLE) begin
      if(PWRITE)
        mem[PADDR] <= PWDATA;
      else
        PRDATA <= mem[PADDR];
    end
  end

endmodule



// ---------------- Timer Block ----------------
module apb_timer (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [31:0] timer_val;
  logic enable;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if(!PRESETn) begin
      timer_val <= 0;
      enable    <= 0;
    end
    else begin
      if(enable)
        timer_val <= timer_val + 1;

      if(PSEL && PENABLE && PWRITE) begin
        if(PADDR == 8'h40)
          enable <= PWDATA[0];
      end
    end
  end

  always_comb begin
    if(PADDR == 8'h44)
      PRDATA = timer_val;
    else
      PRDATA = 0;
  end

endmodule



// ---------------- GPIO Block ----------------
module apb_gpio (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [7:0] gpio_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if(!PRESETn)
      gpio_reg <= 0;
    else if(PSEL && PENABLE && PWRITE && PADDR == 8'h50)
      gpio_reg <= PWDATA[7:0];
  end

  always_comb begin
    if(PADDR == 8'h50)
      PRDATA = {24'd0, gpio_reg};
    else
      PRDATA = 0;
  end

endmodule



// ---------------- ALU Block ----------------
module apb_alu (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [31:0] A, B;
  logic [1:0]  op;
  logic [31:0] result;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if(!PRESETn) begin
      A <= 0; B <= 0; op <= 0;
    end
    else if(PSEL && PENABLE && PWRITE) begin
      case(PADDR)
        8'h60: A  <= PWDATA;
        8'h64: B  <= PWDATA;
        8'h68: op <= PWDATA[1:0];
      endcase
    end
  end

  always_comb begin
    case(op)
      2'b00: result = A + B;
      2'b01: result = A - B;
      2'b10: result = A & B;
      2'b11: result = A | B;
    endcase
  end

  assign PRDATA = (PADDR == 8'h6C) ? result : 0;

endmodule



// ---------------- SoC Subsystem Top ----------------
module soc_subsystem (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [31:0] mem_r, timer_r, gpio_r, alu_r;

  apb_memory mem  (PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, mem_r);
  apb_timer  tim  (PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, timer_r);
  apb_gpio   gpio (PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, gpio_r);
  apb_alu    alu  (PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, alu_r);

  always_comb begin
    case(PADDR[7:4])
      4'h0: PRDATA = mem_r;
      4'h4: PRDATA = timer_r;
      4'h5: PRDATA = gpio_r;
      4'h6: PRDATA = alu_r;
      default: PRDATA = 32'hBAD_ADDR;
    endcase
  end

endmodule
