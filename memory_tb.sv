mailbox gen2drv = new();
mailbox mon2scb = new();
mailbox mon2cov = new();

parameter num =15;

class transaction;
  parameter DEPTH = 16;
  parameter WIDTH = 16;
  parameter ADDR_WIDTH = $clog2(DEPTH);
  
  rand bit wr_rd_i, valid_i;
  rand bit [ADDR_WIDTH-1 : 0]addr_i;
  rand bit [WIDTH-1 : 0]wdata_i;
  bit[WIDTH-1 : 0]rdata_o;
  bit ready_o;
endclass

class generator;
   bit [31 : 0]addr_t;
   transaction tx;
   task run();
     repeat(num)begin
       tx=new();
       assert(tx.randomize() with {	
	   		wr_rd_i == 1;
   			valid_i == 1;
			});
      		addr_t = tx.addr_i;
     	 	gen2drv.put(tx);
      		tx=new();
      		assert(tx.randomize() with {
   			wr_rd_i == 0;
   			addr_i == addr_t;
   			valid_i == 1;
			});
      		gen2drv.put(tx);
    	end
  	endtask
endclass

interface memory_if(input reg clk,rst);
  parameter DEPTH = 16;
  parameter WIDTH = 16;
  parameter ADDR_WIDTH = $clog2(DEPTH);
  
  logic wr_rd_i,valid_i,ready_o;
  logic [ADDR_WIDTH-1 : 0]addr_i;
  logic [WIDTH-1 : 0]wdata_i;
  logic [WIDTH-1 : 0]rdata_o;
  
  clocking drv_cb@(posedge clk);
    default input #0 output #1;
    output wr_rd_i,valid_i,addr_i,wdata_i;
    input ready_o,rdata_o;
  endclocking
  
  clocking mon_cb@(posedge clk);
    default input #0;
    input wr_rd_i,valid_i,addr_i,wdata_i,ready_o,rdata_o;
  endclocking  
endinterface

class driver;
  transaction tx;
  virtual memory_if vif;
  function new();
    vif = top.pif;
  endfunction

  task run();
    repeat(2*num)begin
      tx=new();
      gen2drv.get(tx);
      @(vif.drv_cb);

	  vif.drv_cb.valid_i <= 1;
  	  vif.drv_cb.wr_rd_i <= tx.wr_rd_i;
	  vif.drv_cb.addr_i  <= tx.addr_i;

	  if(tx.wr_rd_i==1)
      	vif.drv_cb.wdata_i <= tx.wdata_i;
      else
        vif.drv_cb.wdata_i <= 0;
      wait(vif.drv_cb.ready_o);

	  if(tx.wr_rd_i == 0) begin
  		tx.rdata_o = vif.drv_cb.rdata_o;
  		tx.wdata_i = 0;
	  end
	  else begin
   		tx.rdata_o = 0;
	  end
      @(vif.drv_cb);
	  vif.drv_cb.valid_i <= 0;
	  vif.drv_cb.wr_rd_i <= 0;
	  vif.drv_cb.addr_i  <= 0;
	  vif.drv_cb.wdata_i <= 0;
    end
  endtask
endclass
  
class monitor;
    transaction tx;
    virtual memory_if vif;
    function new();
      vif = top.pif;
    endfunction 

    task run();
    forever begin
      @(vif.mon_cb);
      if(vif.mon_cb.valid_i == 1 &&
         vif.mon_cb.ready_o == 1) begin
         tx = new();
         tx.wr_rd_i = vif.mon_cb.wr_rd_i;
         tx.addr_i  = vif.mon_cb.addr_i;
         if(vif.mon_cb.wr_rd_i == 1)
            tx.wdata_i = vif.mon_cb.wdata_i;
         else
            tx.wdata_i = 0;
         if(vif.mon_cb.wr_rd_i == 0)
            tx.rdata_o = vif.mon_cb.rdata_o;
         else
         	tx.rdata_o = 0;
         mon2scb.put(tx);
         mon2cov.put(tx);
         @(vif.mon_cb);
         end
   	  end
	endtask
endclass

class scoreboard;    
  parameter DEPTH = 16;
  parameter WIDTH = 16;

    transaction tx;
    bit [WIDTH-1 : 0]mem[DEPTH-1 : 0];
    task run();
      forever begin
        tx=new();
        mon2scb.get(tx);
        $display("SB -TX =%p",tx);
        if(tx.wr_rd_i) mem[tx.addr_i] = tx.wdata_i;
        else begin
        if(tx.rdata_o == mem[tx.addr_i])begin
        $display("**PASS**  addr_i = %0d wdata = %0d rdata = %0d %p",tx.addr_i,tx.wdata_i,tx.rdata_o,tx);
        $display("mem[%d] = %d",tx.addr_i, mem[tx.addr_i]);
        end 
		else begin
        $display("**FAIL**  addr_i = %0d wdata = %0d rdata = %0d %p",tx.addr_i,tx.wdata_i,tx.rdata_o,tx);
        $display("mem[%d] = %d",tx.addr_i, mem[tx.addr_i]);
        end
      end
	end
  endtask
endclass

class coverage;
  transaction tx;
  covergroup mem_cg;
    WR_RD_CP : coverpoint tx.wr_rd_i {
      bins WRITE = {1};
      bins READ  = {0};
    }

    ADDR_CP : coverpoint tx.addr_i {
      bins LOW_ADDR  = {[0:3]};
      bins MID_ADDR  = {[4:11]};
      bins HIGH_ADDR = {[12:15]};
    }

    VALID_CP : coverpoint tx.valid_i {
      bins VALID = {1};
    }

    //WR_RD_X_ADDR : cross WR_RD_CP, ADDR_CP;
  endgroup

  function new();
    mem_cg = new();
  endfunction

  task run();
    forever begin
      mon2cov.get(tx);
      tx.valid_i = 1;
      mem_cg.sample();
    end
  endtask
endclass
  
class agent;
    generator gen = new();
    driver    drv = new();
    monitor   mon = new();
    task run();
      fork
        gen.run();
        drv.run();
        mon.run();
      join
	endtask
endclass
  
class environment;
    agent      agn = new();
    scoreboard scb = new();
    coverage   cov = new();
    task run();
      fork
        agn.run();
        scb.run();
        cov.run();
      join
	endtask
endclass
  
module top;
    reg clk,rst;
    environment env;
    memory_if pif(clk,rst);
    
    memory dut(.clk(pif.clk),
               .rst(pif.rst),
               .wr_rd_i(pif.wr_rd_i),
               .addr_i(pif.addr_i),
               .wdata_i(pif.wdata_i),
               .valid_i(pif.valid_i),
               .rdata_o(pif.rdata_o),
               .ready_o(pif.ready_o));
    
    initial begin
      clk = 0;
      forever #5 clk = ~clk;
    end
    
    initial begin
      rst = 1;
      reset_signals();
      #10;
      rst = 0;
      env = new();
      env.run();
    end
    
    task reset_signals();
      pif.wr_rd_i = 0;
      pif.valid_i = 0;
      pif.addr_i = 0;
      pif.wdata_i = 0;
    endtask
    
    initial begin
      #10000;
      $display("Coverage = %0.2f %%", env.cov.mem_cg.get_coverage());
      $finish;
    end
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars();
    end
    
endmodule
            
        
        
        
        
        
        
    
  
  
      


