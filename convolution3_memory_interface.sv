module convolution3_memory_interface #(
  parameter PRECISION_WIDTH = 4,
  parameter VALID_ADDR_WIDTH = 14,
  parameter DATA_WIDTH = 32,
  parameter KERNEL_NUM = 8
) (
  input i_clk, i_rst_n,
  input i_we, i_re,
  input [VALID_ADDR_WIDTH-1:0] i_write_addr,
  input [VALID_ADDR_WIDTH-1:0] i_read_addr,
  input [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data
);
  
  // parameter RAM_DEPTH = 1 << VALID_ADDR_WIDTH;
  parameter RAM_DEPTH = 2+9*(KERNEL_NUM/8); // Example depth, adjust as needed
  parameter GROUP_NUM = KERNEL_NUM/8;

  // Memory declaration
  // (* RAM_STYLE="BLOCK" *)
  logic [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

  // Output data
  logic [DATA_WIDTH-1:0] output_data;
  logic [2*PRECISION_WIDTH+3:0] cumulative_sum_r [0:GROUP_NUM-1][0:7], cumulative_sum_w [0:GROUP_NUM-1][0:7], cov_result [0:GROUP_NUM-1][0:7];
  logic [PRECISION_WIDTH-1:0] weight [0:2][0:2];
  logic [PRECISION_WIDTH-1:0] data [0:GROUP_NUM-1][0:7][0:2][0:2];
  logic start_r, start_w, done_r, done_w;

  logic [2:0] counter_w, counter_r;

  genvar gi, gj;
  integer i, j, k, m;
  
  assign o_data = output_data;
  generate
    for (gi = 0; gi < GROUP_NUM; gi = gi + 1) begin : gen_group
      assign {data[gi][0][0][0], data[gi][0][0][1], data[gi][0][0][2], data[gi][0][1][0], data[gi][0][1][1], data[gi][0][1][2], data[gi][0][2][0], data[gi][0][2][1], data[gi][0][2][2],
              data[gi][1][0][0], data[gi][1][0][1], data[gi][1][0][2], data[gi][1][1][0], data[gi][1][1][1], data[gi][1][1][2], data[gi][1][2][0], data[gi][1][2][1], data[gi][1][2][2],
              data[gi][2][0][0], data[gi][2][0][1], data[gi][2][0][2], data[gi][2][1][0], data[gi][2][1][1], data[gi][2][1][2], data[gi][2][2][0], data[gi][2][2][1], data[gi][2][2][2],
              data[gi][3][0][0], data[gi][3][0][1], data[gi][3][0][2], data[gi][3][1][0], data[gi][3][1][1], data[gi][3][1][2], data[gi][3][2][0], data[gi][3][2][1], data[gi][3][2][2],
              data[gi][4][0][0], data[gi][4][0][1], data[gi][4][0][2], data[gi][4][1][0], data[gi][4][1][1], data[gi][4][1][2], data[gi][4][2][0], data[gi][4][2][1], data[gi][4][2][2],
              data[gi][5][0][0], data[gi][5][0][1], data[gi][5][0][2], data[gi][5][1][0], data[gi][5][1][1], data[gi][5][1][2], data[gi][5][2][0], data[gi][5][2][1], data[gi][5][2][2],
              data[gi][6][0][0], data[gi][6][0][1], data[gi][6][0][2], data[gi][6][1][0], data[gi][6][1][1], data[gi][6][1][2], data[gi][6][2][0], data[gi][6][2][1], data[gi][6][2][2],
              data[gi][7][0][0], data[gi][7][0][1], data[gi][7][0][2], data[gi][7][1][0], data[gi][7][1][1], data[gi][7][1][2], data[gi][7][2][0], data[gi][7][2][1], data[gi][7][2][2]} 
        = {ram[gi], ram[gi+1], ram[gi+2], ram[gi+3], ram[gi+4], ram[gi+5], ram[gi+6], ram[gi+7], ram[gi+8]};
      for (gj = 0; gj < 8; gj = gj + 1) begin : gen_8_kernel
        convolution3 #(
          .DATA_WIDTH(PRECISION_WIDTH)
        ) CV3 (
          .i_clk(i_clk),
          .i_rst_n(i_rst_n),
          .i_data(data[gi][gj]),
          .i_kernel(weight),
          .i_cumulative_sum(cumulative_sum_r[gi][gj]),
          .o_result(cov_result[gi][gj])
        );
      end
    end
  endgenerate

  assign {weight[0][0], weight[0][1], weight[0][2], weight[1][0], weight[1][1], weight[1][2], weight[2][0], weight[2][1], weight[2][2]} 
        = {ram[RAM_DEPTH-2], ram[RAM_DEPTH-1][DATA_WIDTH-1 -: PRECISION_WIDTH]};
  
  
  // Read operation
  always_comb begin
    if (i_re) begin
      if(i_read_addr == 2**VALID_ADDR_WIDTH - 1) begin
        output_data = done_r;
      end else if (i_read_addr == 2**VALID_ADDR_WIDTH - 2) begin
        output_data = start_r;
      end else if (i_read_addr < RAM_DEPTH) begin
        // Read from memory
        output_data = ram[i_read_addr];
      end else if (i_read_addr <= 2**VALID_ADDR_WIDTH - 3) begin
        output_data = cumulative_sum_r[(i_read_addr-RAM_DEPTH)>>3][(i_read_addr-RAM_DEPTH)];
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
    for (i = 0; i < GROUP_NUM; i++) begin
      for (j = 0; j < 8; j++) begin
        cumulative_sum_w[i][j] = cumulative_sum_r[i][j];
      end
    end
    if(start_r || counter_r) begin
      counter_w = counter_r + 1;
      if(counter_r == 3) begin
        done_w = 1;
        counter_w = 0;
        for (i = 0; i < GROUP_NUM; i++) begin
          for (j = 0; j < 8; j++) begin
            cumulative_sum_w[i][j] = cov_result[i][j];
          end
        end
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
      for (k = 0; k < GROUP_NUM; k++) begin
        for (m = 0; m < 8; m++) begin
          cumulative_sum_r[k][m] <= '0;
        end
      end
    end else begin
      counter_r <= counter_w;
      done_r <= done_w;
      start_r <= start_w;
      for (k = 0; k < GROUP_NUM; k++) begin
        for (m = 0; m < 8; m++) begin
          cumulative_sum_r[k][m] <= cumulative_sum_w[k][m];
        end
      end
      if (i_we && ~(|i_write_addr[VALID_ADDR_WIDTH-1:4])) begin
        ram[i_write_addr] <= i_data;
      end
    end
  end

  
endmodule