module convolution3_memory_interface #(
  parameter PRECISION_WIDTH = 4,
  parameter VALID_ADDR_WIDTH = 14,
  parameter DATA_WIDTH = 32
) (
  input i_clk, i_rst_n,
  input i_we, i_re,
  input [VALID_ADDR_WIDTH-1:0] i_write_addr,
  input [VALID_ADDR_WIDTH-1:0] i_read_addr,
  input [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data
);
  
  // parameter RAM_DEPTH = 1 << VALID_ADDR_WIDTH;
  parameter RAM_DEPTH = 16; // Example depth, adjust as needed

  // Memory declaration
  // (* RAM_STYLE="BLOCK" *)
  logic [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

  // Output data
  logic [DATA_WIDTH-1:0] output_data;
  logic [2*PRECISION_WIDTH+3:0] cumulative_sum_r, cumulative_sum_w, cov_result;
  logic [PRECISION_WIDTH-1:0] weight [0:2][0:2];
  logic [PRECISION_WIDTH-1:0] data [0:2][0:2];
  logic start_r, start_w, done_r, done_w;

  logic [2:0] counter_w, counter_r;
  
  assign o_data = output_data;
  assign {data[0][0], data[0][1], data[0][2], data[1][0], data[1][1], data[1][2], data[2][0], data[2][1], data[2][2]} 
    = {ram[0], ram[1][DATA_WIDTH-1 -: PRECISION_WIDTH]};
  assign {weight[0][0], weight[0][1], weight[0][2], weight[1][0], weight[1][1], weight[1][2], weight[2][0], weight[2][1], weight[2][2]} 
    = {ram[2], ram[3][DATA_WIDTH-1 -: PRECISION_WIDTH]};

  convolution3 #(
    .DATA_WIDTH(PRECISION_WIDTH)
  ) CV3 (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_data(data),
    .i_kernel(weight),
    .i_cumulative_sum(0),
    .o_result(cov_result)
  );
  
  // Read operation
  always_comb begin
    if (i_re) begin
      if(i_read_addr == 2**VALID_ADDR_WIDTH - 1) begin
        output_data = done_r;
      end else if (i_read_addr == 2**VALID_ADDR_WIDTH - 2) begin
        output_data = start_r;
      end else if (i_read_addr == 2**VALID_ADDR_WIDTH - 3) begin
        output_data = cumulative_sum_r;
      end else if (i_read_addr < RAM_DEPTH) begin
        // Read from memory
        output_data = ram[i_read_addr];
      end
    end else begin
      output_data = '0; // Default value when not reading
    end
  end

  always_comb begin
    start_w = 0;
    if (i_we && i_write_addr == 2**VALID_ADDR_WIDTH - 2) begin
      start_w = 1;
    end
  end

  always_comb begin
    counter_w = counter_r;
    done_w = done_r;
    cumulative_sum_w = cumulative_sum_r;
    if(start_r || counter_r) begin
      counter_w = counter_r + 1;
      if(counter_r == 3) begin
        done_w = 1;
        counter_w = 0;
        cumulative_sum_w = cov_result;
      end 
    end else if (i_re && i_read_addr == 2**VALID_ADDR_WIDTH - 1) begin
      done_w = 0;
    end
  end
  
  // Initialize memory
  initial begin
    for (int i = 0; i < RAM_DEPTH; i++) begin
      ram[i] = '0;
    end
  end

  
  
  // Write operation
  always_ff @(posedge i_clk) begin
    if (~i_rst_n) begin
      // Reset logic can be added here if needed
      counter_r <= 0;
      done_r <= 0;
      start_r <= 0;
      cumulative_sum_r <= 0;
    end else begin
      counter_r <= counter_w;
      done_r <= done_w;
      start_r <= start_w;
      cumulative_sum_r <= cumulative_sum_w;
      if (i_we && ~(|i_write_addr[VALID_ADDR_WIDTH-1:4])) begin
        ram[i_write_addr] <= i_data;
      end
    end
  end

  
endmodule