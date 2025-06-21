module tb_convolution3;
  logic clk;
  logic rst_n;
  logic [3:0] data [0:2][0:2];
  logic [3:0] kernel [0:2][0:2];
  logic [11:0] cumulative_sum;
  logic [11:0] result;

  // Instantiate the convolution3 module
  convolution3 #(
    .DATA_WIDTH(4)
  ) uut (
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_data(data),
    .i_kernel(kernel),
    .i_cumulative_sum(cumulative_sum),
    .o_result(result)
  );

  initial begin
    // Generate clock signal
    forever #5 clk = ~clk;
  end

  initial begin
    $fsdbDumpfile("tb_convolution3.fsdb");          // Name of the FSDB file
    $fsdbDumpvars(0, tb_convolution3, "+mda");         // Dump variables recursively from "testbench"
    // $fsdbDumpMDA();                      // (Optional) Dump multi-dimensional arrays
  end

  initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    cumulative_sum = 12'h000;

    // Initialize data and kernel

    // localparm mydata = `{
    //   `{4'h1, 4'h2, 4'h3},
    //   `{4'h4, 4'h5, 4'h6},
    //   `{4'h7, 4'h8, 4'h9}
    // };
    data[0][0] = 4'h1; data[0][1] = 4'h2; data[0][2] = 4'h3;
    data[1][0] = 4'h4; data[1][1] = 4'h5; data[1][2] = 4'h6;
    data[2][0] = 4'h7; data[2][1] = 4'h8; data[2][2] = 4'h9;

    // localparm mykernel = `{
    //   `{4'h1, 4'h1, 4'h1},
    //   `{4'h1, 4'h1, 4'h1},
    //   `{4'h1, 4'h1, 4'h1}
    // };

    kernel[0][0] = 4'h1; kernel[0][1] = 4'h2; kernel[0][2] = 4'h3;
    kernel[1][0] = 4'h4; kernel[1][1] = 4'h1; kernel[1][2] = 4'h1;
    kernel[2][0] = 4'h1; kernel[2][1] = 4'h1; kernel[2][2] = 4'h1;

    // Release reset
    #15 rst_n = 1;

    @(posedge clk); // Wait for the first clock edge
    @(posedge clk); // Wait for the second clock edge
    @(posedge clk); // Wait for the third clock edge
    $display("-----------------Starting convolution-----------------");
    $display("Result: %d", result); // Display the result
    $display("------------------Convolution completed-----------------");

    #10;
    $finish; // End the simulation
  end

    // Run the simulation for a few clock cycles
  

endmodule