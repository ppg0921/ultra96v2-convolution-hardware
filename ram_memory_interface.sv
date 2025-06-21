module ram_memory_interface #(
  parameter VALID_ADDR_WIDTH = 14,
  parameter DATA_WIDTH = 32
) (
  input i_clk, i_rst,
  input i_we, i_re,
  input [VALID_ADDR_WIDTH-1:0] i_write_addr,
  input [VALID_ADDR_WIDTH-1:0] i_read_addr,
  input [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data
);
  parameter RAM_DEPTH = 1 << VALID_ADDR_WIDTH;
  
  (* RAM_STYLE="BLOCK" *)
  logic [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];
  
  
  logic [DATA_WIDTH-1:0] output_data;
  integer i, j;
  
  assign o_data = output_data;

  always_comb begin
    if (i_re) begin
      output_data = ram[i_read_addr];
    end else begin
      output_data = 0; // Default value when not reading
    end
  end

  initial begin
    for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
      for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
        ram[j] = 0;
      end
    end
  end

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      // Reset logic can be added here if needed
      // two nested loops for smaller number of iterations per loop
      // workaround for synthesizer complaints about large loop counts
      
    end else if (i_we) begin
      ram[i_write_addr] <= i_data;
    end
  end

endmodule