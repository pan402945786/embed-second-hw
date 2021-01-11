`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:59:47 12/13/2020
// Design Name:   fpga
// Module Name:   D:/ISE_Proj/usb_demo/fpga_tb.v
// Project Name:  usb_demo
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: fpga
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
`include "register.v"
module fpga_tb;

	// Inputs
	reg USB_FLAGA;
	reg USB_FLAGB;
	reg USB_FLAGC;
	reg USB_FLAGD;
	reg USB_IFCLK;

	// Outputs
	wire [3:0] LED;
	wire [1:0] USB_ADDR;
	wire USB_SLRD;
	wire USB_SLWR;
	wire USB_SLOE;
	wire USB_PKEND;
	wire [3:0] STATE;

	// Bidirs
	wire [15:0] USB_DATA;
	
	// Instantiate the Unit Under Test (UUT)
	fpga uut (
		.LED(LED), 
		.USB_DATA(USB_DATA), 
		.USB_ADDR(USB_ADDR), 
		.USB_SLRD(USB_SLRD), 
		.USB_SLWR(USB_SLWR), 
		.USB_SLOE(USB_SLOE), 
		.USB_FLAGA(USB_FLAGA),  
		.USB_FLAGD(USB_FLAGD), 
		.USB_PKEND(USB_PKEND),		
		.USB_IFCLK(USB_IFCLK),
		.STATE(STATE)
	);
	reg [15:0] in_fifo[0:255];
	reg [8:0] in_fifo_addr;
	reg [15:0] out_fifo[0:255];
	reg [8:0] out_fifo_addr;
	integer i;
	initial begin
		// Initialize Inputs
		USB_FLAGA = 0;
		USB_FLAGB = 0;
		USB_FLAGC = 0;
		USB_FLAGD = 0;
		USB_IFCLK = 0;
		in_fifo_addr = 0;
		out_fifo_addr = 0;
		
		//for (i = 0; i < 256; i = i + 1) begin
		for (i = 0; i < 5; i = i + 1) begin
			out_fifo[i] = i;
		end
		// Wait 100 ns for global reset to finish

		// Add stimulus here
		
	end
   initial begin
		forever #10 USB_IFCLK = ~USB_IFCLK;
	end

	always @(posedge USB_IFCLK) 
	begin
		if (out_fifo_addr >= 9'b00000_0100) 
			USB_FLAGA <= 0;
		else
			USB_FLAGA <= 1;
	end
	
	always @(posedge USB_IFCLK)
	begin
		if (~USB_SLOE & ~USB_SLRD & USB_FLAGA)
			out_fifo_addr <= out_fifo_addr + 1;
		else
			out_fifo_addr <= out_fifo_addr;
	end 
	
	always @(posedge USB_IFCLK) 
	begin
		if (in_fifo_addr == 9'b10000_0000) 
			USB_FLAGD <= 0;
		else
			USB_FLAGD <= 1;
	end
	
	always @(posedge USB_IFCLK)
	begin
		if (~USB_SLWR & USB_FLAGD)
			in_fifo_addr <= in_fifo_addr + 1;
		else
			in_fifo_addr <= in_fifo_addr;
	end 
	
	always @(posedge USB_IFCLK)
	begin
		if (~USB_SLWR & USB_FLAGD)
			in_fifo[in_fifo_addr] <= USB_DATA;
		else
			in_fifo[in_fifo_addr] <= in_fifo[in_fifo_addr];
	end 
	reg USB_SLOE_R;
	always @(posedge USB_IFCLK)
	begin
		USB_SLOE_R <= USB_SLOE;
	end
	assign USB_DATA = ~USB_SLOE ? out_fifo[out_fifo_addr] : 16'bz;
	
endmodule

