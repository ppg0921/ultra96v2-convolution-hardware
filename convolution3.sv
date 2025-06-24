module convolution3 #(
  parameter DATA_WIDTH = 4
) (
  input i_clk,
  input i_rst_n,
  input [DATA_WIDTH-1:0] i_data [0:3-1][0:3-1] ,
  input [DATA_WIDTH-1:0] i_kernel [0:3-1][0:3-1] ,
  output [2*DATA_WIDTH+3:0] o_result
);
  logic [DATA_WIDTH-1:0] o_result_r;
  integer i, j;
  genvar gi, gj;
  logic [2*DATA_WIDTH-1:0] product_w [0:3-1][0:3-1];
  logic [2*DATA_WIDTH-1:0] product_r [0:3-1][0:3-1];
  logic [2*DATA_WIDTH+1:0] first_stage_sum_r [0:2], first_stage_sum_w [0:2];
  logic [2*DATA_WIDTH+3:0] second_stage_sum_r, second_stage_sum_w;
  logic [2*DATA_WIDTH+3:0] partial_sum_w;

  assign second_stage_sum_w = partial_sum_w;
  assign o_result = second_stage_sum_r;
  
  generate 
    for(gi = 0; gi < 3; gi = gi + 1) begin : gen_kernel_rows
      for(gj = 0; gj < 3; gj = gj + 1) begin : gen_kernel_cols
        intMultiplier #(
          .DATA_WIDTH(DATA_WIDTH)
        ) u_multiplier (
          .i_a(i_data[gi][gj]),
          .i_b(i_kernel[gi][gj]),
          .o_product(product_w[gi][gj])
        );
      end
    end 
  endgenerate

  generate
    for(gi = 0; gi < 3; gi = gi + 1) begin : gen_first_stage_sum
      int3Adder #(
        .DATA_WIDTH(2*DATA_WIDTH)
      ) u_first_stage_adder (
        .i_a(product_w[gi][0]),
        .i_b(product_w[gi][1]),
        .i_c(product_w[gi][2]),
        .o_sum(first_stage_sum_w[gi])
      );
    end
  endgenerate

  int3Adder #(
    .DATA_WIDTH(2*DATA_WIDTH+2)
  ) u_second_stage_adder (
    .i_a(first_stage_sum_r[0]),
    .i_b(first_stage_sum_r[1]),
    .i_c(first_stage_sum_r[2]),
    .o_sum(partial_sum_w)
  );

  always_ff @(posedge i_clk) begin
    if(~i_rst_n) begin
      for(i = 0; i < 3; i = i + 1) begin
        for(j = 0; j < 3; j = j + 1) begin
          product_r[i][j] <= 0;
        end
        first_stage_sum_r[i] <= 0;
      end
      second_stage_sum_r <= 0;
    end else begin
      for(i = 0; i < 3; i = i + 1) begin
        for(j = 0; j < 3; j = j + 1) begin
          product_r[i][j] <= product_w[i][j];
        end
        first_stage_sum_r[i] <= first_stage_sum_w[i];
      end
      second_stage_sum_r <= second_stage_sum_w;
    end
  end



  
endmodule

module intMultiplier #(
  parameter DATA_WIDTH = 4
) (
  input [DATA_WIDTH-1:0] i_a,
  input [DATA_WIDTH-1:0] i_b,
  output [2*DATA_WIDTH-1:0] o_product
);
  assign o_product = i_a * i_b;
endmodule

module int3Adder #(
  parameter DATA_WIDTH = 4
) (
  input [DATA_WIDTH-1:0] i_a,
  input [DATA_WIDTH-1:0] i_b,
  input [DATA_WIDTH-1:0] i_c,
  output [DATA_WIDTH+1:0] o_sum
);
  assign o_sum = i_a + i_b + i_c;
endmodule
