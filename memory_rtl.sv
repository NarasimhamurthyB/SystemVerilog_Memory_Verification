module memory(clk,rst,wr_rd_i,addr_i,wdata_i,rdata_o,valid_i,ready_o);
  parameter DEPTH = 16;
  parameter WIDTH = 16;
  parameter ADDR_WIDTH = $clog2(DEPTH);  
  input clk,rst, wr_rd_i, valid_i;
  input [ADDR_WIDTH-1 : 0]addr_i;
  input [WIDTH-1 : 0]wdata_i;
  output reg[WIDTH-1 : 0]rdata_o;
  output reg ready_o;
  
  reg[WIDTH-1 : 0]mem[DEPTH-1 : 0];
  integer i;

  always@(posedge clk)begin
    if(rst)begin
      rdata_o <= 0;
      ready_o <= 0;
      for(i=0;i<DEPTH;i++)
        mem[i] <= 0;
    end
    else begin
      if(valid_i)begin
        ready_o <= 1;
        if(wr_rd_i) mem[addr_i] <= wdata_i;
        else rdata_o <= mem[addr_i];
      end
      else
        ready_o <= 0;
    end
  end
endmodule

