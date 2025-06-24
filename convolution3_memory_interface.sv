module convolution3_memory_interface #(
  parameter PRECISION_WIDTH = 4,
  parameter VALID_ADDR_WIDTH = 14,
  parameter DATA_WIDTH = 32,
  parameter KERNEL_NUM = 128
) (
  input i_clk, i_rst_n,
  input i_we, i_re,
  input [VALID_ADDR_WIDTH-1:0] i_write_addr,
  input [VALID_ADDR_WIDTH-1:0] i_read_addr,
  input [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data
);
  
  // parameter RAM_DEPTH = 1 << VALID_ADDR_WIDTH;
  parameter RAM_DEPTH = 2*9*(KERNEL_NUM/8); // Example depth, adjust as needed
  parameter GROUP_NUM = KERNEL_NUM/8;
  parameter CHANNEL_SEC = 8;
  parameter CHANNEL_TOTAL = 64;
  parameter WEIGHT_OFFSET = (CHANNEL_TOTAL*9)/8;
  parameter SECOND_OFFSET = (2*CHANNEL_TOTAL*9)/8;
  parameter OUTPUT_POINT = KERNEL_NUM/CHANNEL_TOTAL;

  // Memory declaration
  // (* RAM_STYLE="BLOCK" *)
  logic [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

  // Output data
  logic [DATA_WIDTH-1:0] output_data;
  logic [2*PRECISION_WIDTH+3:0] cov_result [0:OUTPUT_POINT-1][0:CHANNEL_SEC-1][0:7];
  logic [2*PRECISION_WIDTH+6:0] first_stage_sum_r [0:OUTPUT_POINT-1][0:CHANNEL_SEC-1], first_stage_sum_w [0:OUTPUT_POINT-1][0:CHANNEL_SEC-1];
  logic [2*PRECISION_WIDTH+9:0] final_sum_r [0:OUTPUT_POINT-1], final_sum_w [0:OUTPUT_POINT-1];
  logic [PRECISION_WIDTH-1:0] weight [0:OUTPUT_POINT-1][0:CHANNEL_SEC-1][0:7][0:2][0:2];
  logic [PRECISION_WIDTH-1:0] data [0:OUTPUT_POINT-1][0:CHANNEL_SEC-1][0:7][0:2][0:2];
  logic start_r, start_w, done_r, done_w;
  logic [VALID_ADDR_WIDTH-1:0] result_read_addr;

  logic [2:0] counter_w, counter_r;

  genvar gi, gj, gk;
  integer i, j, k, m, p, q;
  
  assign o_data = output_data;
  generate
    for (gk = 0; gk < OUTPUT_POINT; gk = gk + 1) begin : gen_output_point
      for (gi = 0; gi < CHANNEL_SEC; gi = gi + 1) begin : gen_group
        assign {data[gk][gi][0][0][0], data[gk][gi][0][0][1], data[gk][gi][0][0][2], data[gk][gi][0][1][0], data[gk][gi][0][1][1], data[gk][gi][0][1][2], data[gk][gi][0][2][0], data[gk][gi][0][2][1], data[gk][gi][0][2][2],
                data[gk][gi][1][0][0], data[gk][gi][1][0][1], data[gk][gi][1][0][2], data[gk][gi][1][1][0], data[gk][gi][1][1][1], data[gk][gi][1][1][2], data[gk][gi][1][2][0], data[gk][gi][1][2][1], data[gk][gi][1][2][2],
                data[gk][gi][2][0][0], data[gk][gi][2][0][1], data[gk][gi][2][0][2], data[gk][gi][2][1][0], data[gk][gi][2][1][1], data[gk][gi][2][1][2], data[gk][gi][2][2][0], data[gk][gi][2][2][1], data[gk][gi][2][2][2],
                data[gk][gi][3][0][0], data[gk][gi][3][0][1], data[gk][gi][3][0][2], data[gk][gi][3][1][0], data[gk][gi][3][1][1], data[gk][gi][3][1][2], data[gk][gi][3][2][0], data[gk][gi][3][2][1], data[gk][gi][3][2][2],
                data[gk][gi][4][0][0], data[gk][gi][4][0][1], data[gk][gi][4][0][2], data[gk][gi][4][1][0], data[gk][gi][4][1][1], data[gk][gi][4][1][2], data[gk][gi][4][2][0], data[gk][gi][4][2][1], data[gk][gi][4][2][2],
                data[gk][gi][5][0][0], data[gk][gi][5][0][1], data[gk][gi][5][0][2], data[gk][gi][5][1][0], data[gk][gi][5][1][1], data[gk][gi][5][1][2], data[gk][gi][5][2][0], data[gk][gi][5][2][1], data[gk][gi][5][2][2],
                data[gk][gi][6][0][0], data[gk][gi][6][0][1], data[gk][gi][6][0][2], data[gk][gi][6][1][0], data[gk][gi][6][1][1], data[gk][gi][6][1][2], data[gk][gi][6][2][0], data[gk][gi][6][2][1], data[gk][gi][6][2][2],
                data[gk][gi][7][0][0], data[gk][gi][7][0][1], data[gk][gi][7][0][2], data[gk][gi][7][1][0], data[gk][gi][7][1][1], data[gk][gi][7][1][2], data[gk][gi][7][2][0], data[gk][gi][7][2][1], data[gk][gi][7][2][2]} 
          = {ram[gi+gk*SECOND_OFFSET], ram[gi+gk*SECOND_OFFSET+1], ram[gi+gk*SECOND_OFFSET+2], ram[gi+gk*SECOND_OFFSET+3], ram[gi+gk*SECOND_OFFSET+4], ram[gi+gk*SECOND_OFFSET+5], ram[gi+gk*SECOND_OFFSET+6], ram[gi+gk*SECOND_OFFSET+7], ram[gi+gk*SECOND_OFFSET+8]};
        
        assign {weight[gk][gi][0][0][0], weight[gk][gi][0][0][1], weight[gk][gi][0][0][2], weight[gk][gi][0][1][0], weight[gk][gi][0][1][1], weight[gk][gi][0][1][2], weight[gk][gi][0][2][0], weight[gk][gi][0][2][1], weight[gk][gi][0][2][2],
                weight[gk][gi][1][0][0], weight[gk][gi][1][0][1], weight[gk][gi][1][0][2], weight[gk][gi][1][1][0], weight[gk][gi][1][1][1], weight[gk][gi][1][1][2], weight[gk][gi][1][2][0], weight[gk][gi][1][2][1], weight[gk][gi][1][2][2],
                weight[gk][gi][2][0][0], weight[gk][gi][2][0][1], weight[gk][gi][2][0][2], weight[gk][gi][2][1][0], weight[gk][gi][2][1][1], weight[gk][gi][2][1][2], weight[gk][gi][2][2][0], weight[gk][gi][2][2][1], weight[gk][gi][2][2][2],
                weight[gk][gi][3][0][0], weight[gk][gi][3][0][1], weight[gk][gi][3][0][2], weight[gk][gi][3][1][0], weight[gk][gi][3][1][1], weight[gk][gi][3][1][2], weight[gk][gi][3][2][0], weight[gk][gi][3][2][1], weight[gk][gi][3][2][2],
                weight[gk][gi][4][0][0], weight[gk][gi][4][0][1], weight[gk][gi][4][0][2], weight[gk][gi][4][1][0], weight[gk][gi][4][1][1], weight[gk][gi][4][1][2], weight[gk][gi][4][2][0], weight[gk][gi][4][2][1], weight[gk][gi][4][2][2],
                weight[gk][gi][5][0][0], weight[gk][gi][5][0][1], weight[gk][gi][5][0][2], weight[gk][gi][5][1][0], weight[gk][gi][5][1][1], weight[gk][gi][5][1][2], weight[gk][gi][5][2][0], weight[gk][gi][5][2][1], weight[gk][gi][5][2][2],
                weight[gk][gi][6][0][0], weight[gk][gi][6][0][1], weight[gk][gi][6][0][2], weight[gk][gi][6][1][0], weight[gk][gi][6][1][1], weight[gk][gi][6][1][2], weight[gk][gi][6][2][0], weight[gk][gi][6][2][1], weight[gk][gi][6][2][2],
                weight[gk][gi][7][0][0], weight[gk][gi][7][0][1], weight[gk][gi][7][0][2], weight[gk][gi][7][1][0], weight[gk][gi][7][1][1], weight[gk][gi][7][1][2], weight[gk][gi][7][2][0], weight[gk][gi][7][2][1], weight[gk][gi][7][2][2]} 
          = {ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+1], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+2], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+3], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+4], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+5], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+6], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+7], ram[gi+gk*SECOND_OFFSET+WEIGHT_OFFSET+8]};
        
        for (gj = 0; gj < 8; gj = gj + 1) begin : gen_8_kernel
          convolution3 #(
            .DATA_WIDTH(PRECISION_WIDTH)
          ) CV3 (
            .i_clk(i_clk),
            .i_rst_n(i_rst_n),
            .i_data(data[gk][gi][gj]),
            .i_kernel(weight[gk][gi][gj]),
            .o_result(cov_result[gk][gi][gj])
          );
        end

        adder8 #(
          .DATA_WIDTH(12)
        ) u_adder8 (
          .i_a(cov_result[gk][gi]),
          .o_sum(first_stage_sum_w[gk][gi])
        );
      end

      adder8 #(
        .DATA_WIDTH(15)
      ) u_final_adder8 (
        .i_a(first_stage_sum_r[gk]),
        .o_sum(final_sum_w[gk])
      );
    end
  endgenerate

  assign result_read_addr = i_read_addr - RAM_DEPTH;
  
  // Read operation
  always_comb begin
    output_data = '0; // Default value
    if (i_re) begin
      if(i_read_addr == 2**VALID_ADDR_WIDTH - 1) begin
        output_data = done_r;
      end else if (i_read_addr == 2**VALID_ADDR_WIDTH - 2) begin
        output_data = start_r;
      end else if (i_read_addr < RAM_DEPTH) begin
        // Read from memory
        output_data = ram[i_read_addr];
      end else if (i_read_addr <= 2**VALID_ADDR_WIDTH - 3) begin
        output_data = final_sum_r[i_read_addr - RAM_DEPTH];
      end 
    end else begin
      output_data = '0; // Default value when not reading
    end
  end

  always_comb begin
    start_w = 0;
    if (i_we) begin
      if(i_write_addr == 2**VALID_ADDR_WIDTH - 2) begin
        start_w = 1;
      end
    end
  end
 
  always_comb begin
    counter_w = counter_r;
    done_w = done_r;
    // for (p = 0; p < OUTPUT_POINT; p = p + 1) begin
    //   for (i = 0; i < GROUP_NUM; i++) begin
    //     first_stage_sum_w[p][i] = first_stage_sum_r[p][i];
    //   end
    // end
    if(start_r || counter_r) begin
      counter_w = counter_r + 1;
      if(counter_r == 5) begin
        done_w = 1;
        counter_w = 0;
        // for (p = 0; p < OUTPUT_POINT; p = p + 1) begin
        //   for (i = 0; i < GROUP_NUM; i++) begin 
        //     first_stage_sum_w[p][i] = cov_result[p][i];
        //   end
        // end
      end 
    end else if (i_re && i_read_addr == 2**VALID_ADDR_WIDTH - 1) begin
      done_w = 0;
    end
  end
  
  // Initialize memory
  // initial begin
  //   for (int i = 0; i < RAM_DEPTH; i++) begin
  //     ram[i] = '0;
  //   end
  // end

  
  
  // Write operation
  always_ff @(posedge i_clk) begin
    if (~i_rst_n) begin
      // Reset logic can be added here if needed
      counter_r <= 0;
      done_r <= 0;
      start_r <= 0;
      for (q = 0; q < OUTPUT_POINT; q++) begin
        for (k = 0; k < CHANNEL_SEC; k++) begin
          first_stage_sum_r[q][k] <= '0;
        end
        final_sum_r[q] <= '0;
      end
      for (int k = 0; k < RAM_DEPTH; k++) begin
        ram[k] = '0;
      end
    end else begin
      counter_r <= counter_w;
      done_r <= done_w;
      start_r <= start_w;
      for (p = 0; p < OUTPUT_POINT; p++) begin
        for (i = 0; i < CHANNEL_SEC; i++) begin
          first_stage_sum_r[p][i] <= first_stage_sum_w[p][i];
        end
        final_sum_r[p] <= final_sum_w[p];
      end
      if (i_we && i_write_addr < RAM_DEPTH) begin
        ram[i_write_addr] <= i_data;
      end
    end
  end

  
endmodule

module adder8 #(
  parameter DATA_WIDTH = 12
) (
  input logic [DATA_WIDTH-1:0] i_a [0:7],
  output logic [DATA_WIDTH+2:0] o_sum
);
  logic [DATA_WIDTH:0] first_stage_sum [0:3];
  logic [DATA_WIDTH+1:0] second_stage_sum [0:1];
  logic [DATA_WIDTH+2:0] final_sum;

  assign o_sum = final_sum;

  genvar gi;

  generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : gen_first_stage
      assign first_stage_sum[gi] = i_a[gi*2] + i_a[gi*2+1];
    end
    for (gi = 0; gi < 2; gi = gi + 1) begin : gen_second_stage
      assign second_stage_sum[gi] = first_stage_sum[gi*2] + first_stage_sum[gi*2+1];
    end
    assign final_sum = second_stage_sum[0] + second_stage_sum[1];
  endgenerate
  
endmodule