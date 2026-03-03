interface soc_if(input logic PCLK);

  logic PRESETn;
  logic PSEL;
  logic PENABLE;
  logic PWRITE;
  logic [7:0]  PADDR;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;

endinterface



module mini_soc(
  input  logic PCLK,
  input  logic PRESETn,
  input  logic PSEL,
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA
);

  logic [31:0] mem [256];

  always @(posedge PCLK or negedge PRESETn) begin
    if(!PRESETn) begin
      PRDATA <= 0;
    end
    else if(PSEL && PENABLE) begin
      if(PWRITE)
        mem[PADDR] <= PWDATA;
      else
        PRDATA <= mem[PADDR];
    end
  end

endmodule
