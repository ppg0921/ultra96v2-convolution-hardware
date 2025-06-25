module tb_convolution_direct_output();

    // Inputs to the Montgomery module
    reg clk;
    reg reset;
    reg start;
    reg web, reb;
    reg [13:0] write_addr, read_addr;
    reg [31:0] din;
    reg [31:0] dout;
    reg [31:0] read_data;

    // Output from the Montgomery module
    wire [255:0] result;
    wire ready;

    parameter PATLEN = 10;
    parameter MAX_CYCLES = 100000*PATLEN;

    logic [254:0] scalarmem [0:PATLEN-1];
    logic [254:0] goldenxmem [0:PATLEN-1];
    logic [254:0] goldenymem [0:PATLEN-1];
    reg read_mem_ready;
    reg [10:0] correct, error;

    convolution3_memory_interface #(.PRECISION_WIDTH(5), .VALID_ADDR_WIDTH(14), .DATA_WIDTH(32), .KERNEL_NUM(128)) 
    CMI0 (
      .i_clk(clk),
      .i_rst_n(reset),
      .i_we(web),
      .i_re(reb),
      .i_write_addr(write_addr),
      .i_read_addr(read_addr),
      .i_data(din),
      .o_data(dout)
    );

    // Clock generation
    always #5 clk = ~clk;

    task write_memory;
      input [13:0] i_write_addr;
      input [31:0] i_write_data;
      begin
        @(posedge clk);
        din = i_write_data;
        write_addr = i_write_addr;
        web = 1;
        reb = 0;
      end 
    endtask

    task read_memory;
      input [15:0] i_read_addr;
      output [31:0] o_read_data;
      begin
        @(posedge clk);
        read_addr = i_read_addr;
        reb = 1;
        web = 0;
        @(posedge clk);
        o_read_data = dout;
      end
    endtask

	initial begin
		$fsdbDumpfile("tb_convolution_direct_output.fsdb");
		$fsdbDumpvars(0, "tb_convolution_direct_output", "+mda");
		$dumpvars();
	end

    initial begin
        #(MAX_CYCLES * 10);
        $display("Test failed: Timeout");
        $finish;
    end
    integer i, j;
    // Initialize the simulation
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        start = 0;
        web = 0;
        reb = 0;
        write_addr = 14'b0;
        read_addr = 14'b0;
        din = 32'b0;

        // Apply reset
        #10 reset = 0;
        #15 reset = 1;

        @(posedge clk);
        // write_memory(14'h3F, 32'h12345678);
        // write_memory(14'h40, 32'h90000000);
        for(i=0; i<8; i=i+1) begin
          write_memory(9*i, 32'h12345678);
          write_memory(9*i+1, 32'h9ABCDEF0);
          write_memory(9*i+2, 32'h12345678);
          write_memory(9*i+3, 32'h9ABCDEF0);
          write_memory(9*i+4, 32'h12345678);
          write_memory(9*i+5, 32'h9ABCDEF0);
          write_memory(9*i+6, 32'h12345678);
          write_memory(9*i+7, 32'h9ABCDEF0);
          write_memory(9*i+8, 32'h12345678);
        end
        for(i=0; i<72; i=i+1) begin
          write_memory(72+i, 32'h22222222);
        end

        for(i=0; i<8; i=i+1) begin
          write_memory(9*i+144, 32'h12345678);
          write_memory(9*i+1+144, 32'h9ABCDEF0);
          write_memory(9*i+2+144, 32'h12345678);
          write_memory(9*i+3+144, 32'h9ABCDEF0);
          write_memory(9*i+4+144, 32'h12345678);
          write_memory(9*i+5+144, 32'h9ABCDEF0);
          write_memory(9*i+6+144, 32'h12345678);
          write_memory(9*i+7+144, 32'h9ABCDEF0);
          write_memory(9*i+8+144, 32'h12345678);
        end
        for(i=0; i<72; i=i+1) begin
          write_memory(72+i+144, 32'h22222222);
        end
        write_memory(14'h3FFD, 0);  // clear = 0
        write_memory(14'h3FFE, 1);  // start = 1
        #(10);  
        @(posedge clk);

        web = 0;
        reb = 1;
        read_addr = 14'h3FFF;   // read done signal

        wait(dout == 1);

        @(posedge clk);
        for(i=0; i<2; i=i+1) begin
          @(posedge clk);
          read_addr = 14'hD8 + i;
          read_memory(read_addr, read_data);
          $display("Read data from address %h: %h", read_addr, read_data);
        end


        
        
        

        

        // Wait for the computation to complete
        

        // End simulation
        
        #100;
        
        $finish;
    end
    

endmodule