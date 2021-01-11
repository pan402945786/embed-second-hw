`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:17:44 11/01/2016 
// Design Name: 
// Module Name:    usb 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "register.v"
module usb #(
  parameter DATA_WIDTH = 16
)(
   input			                     i_usb_ifclk,			 //   USB Clock inout
	input			                     i_usb_flaga,			 //	USB Flag  //CY68013 EP2 FIFO empty indication; 1:not empty; 0: empty
	input			                     i_usb_flagd,			 //	USB Flag  //CY68013 EP6 FIFO full indication; 1:not full; 0: full
	
   inout	   [DATA_WIDTH - 1 : 0]	   io_usb_data,			 //   USB Data bus 16 Bits
	inout 	[DATA_WIDTH - 1 : 0]	   io_fpga_data,			 //   FPGA Data bus 16 Bits
	output	[1:0]	                  o_usb_addr,				 //   USB Address bus 2 Bits
	output			                  o_usb_slrd,				 //   USB Read Enable
	output			                  o_usb_slwr,				 //	USB Write Enable
	output			                  o_usb_sloe,				 //	USB Output Enable
	output			                  o_usb_pkend, 			 //	USB Packet end

//	output o_counter_0,
	output o_counter_1,
	output o_counter_2,
	output o_counter_3,
	output o_buffer,
	output o_usb_we,
	output o_usb_re,
	output o_flag_full
);

localparam IDLE = 4'b0000;
localparam SELECT_READ_FIFO = 4'b0001;
localparam READ_FROM_USB = 4'b0010;
localparam SELECT_WRITE_FIFO = 4'b0011;
localparam WRITE_TO_USB = 4'b0100;
/*新增*/
localparam SELECT_WRITE_TO_FPGA = 4'b0101;
localparam WRITE_TO_FPGA = 4'b0110;
localparam SELECT_READ_FROM_FPGA = 4'b0111;
localparam READ_FROM_FPGA = 4'b1000;
/*新增END*/

reg [3 : 0]              state = 0;
reg [3 : 0]              state_nxt = 0;
reg [DATA_WIDTH - 1 : 0] buff [`MAXPKG - 1 : 0];
reg [`LOGMAXPKG - 1 : 0] counter = 0;
reg [`LOGMAXPKG - 1 : 0] number = 0;
reg                      usb_slrd = 1'b1;
reg                      usb_slwr = 1'b1;
reg                      usb_sloe = 1'b1;
reg                      usb_pkend = 1'b1;
reg [1 : 0]              usb_addr = 2'b00;
reg [DATA_WIDTH - 1 :  0]usb_data = 0;
reg usb_we = 0;
reg usb_re = 0;
reg flag_full = 1'b0;

assign o_usb_addr = usb_addr;
assign o_usb_slrd = usb_slrd;
assign o_usb_slwr = usb_slwr;
assign o_usb_sloe = usb_sloe;
assign o_usb_pkend= usb_pkend;
assign io_usb_data= (usb_sloe == 1'b1)? usb_data : 'bz;

//assign o_counter_0 = counter[0];
assign o_counter_1 = counter[1];
assign o_counter_2 = counter[2];
assign o_counter_3 = counter[3];
assign o_usb_we = usb_we;
assign o_usb_re = usb_re;
assign o_flag_full = flag_full;
assign o_buffer = buff[0];

/*
状态机
*/
always @(posedge i_usb_ifclk) begin
   state <= state_nxt;
end
always @(*) begin
   case (state)
	    IDLE: begin
			  // EP2 not empty
		     if (i_usb_flaga == 1'b1) begin
			  // Transform to SELECT_READ_FIFO
			      state_nxt = SELECT_READ_FIFO;
			  end
			  else begin
			      state_nxt = IDLE;
			  end
		 end
		 SELECT_READ_FIFO: begin
		    state_nxt = READ_FROM_USB;
		 end
		 READ_FROM_USB: begin
		    if((counter == `MAXPKG - 1) || (i_usb_flaga == 1'b0))begin
			     state_nxt = SELECT_WRITE_TO_FPGA;
          end
          else begin
			     state_nxt = READ_FROM_USB;
			 end
		 end
		 
		 /*新增*/
		 SELECT_WRITE_TO_FPGA: begin
		    state_nxt = WRITE_TO_FPGA;
		 end
		 WRITE_TO_FPGA: begin
			if (usb_we == 0) begin
				state_nxt = SELECT_READ_FROM_FPGA;
			end
			else begin
			state_nxt = WRITE_TO_FPGA;
			end
		 end
		 SELECT_READ_FROM_FPGA: begin
		    state_nxt = READ_FROM_FPGA;
		 end
		 READ_FROM_FPGA: begin
			if (usb_re == 0) begin
				state_nxt = SELECT_WRITE_FIFO;
			end
			else begin
				state_nxt = READ_FROM_FPGA;
			end
		 end	 
		 /*新增END*/
		 
		 SELECT_WRITE_FIFO: begin
		     if(i_usb_flagd == 1'b1) begin
		         state_nxt = WRITE_TO_USB;
			  end
			  else begin
			      state_nxt = SELECT_WRITE_FIFO;
			  end
		 end
		 WRITE_TO_USB: begin
		    if ((counter >= number) || (i_usb_flagd == 1'b0)) begin
			     state_nxt = IDLE;
			 end
			 else begin
			     state_nxt = WRITE_TO_USB;
			 end
		 end
		 default: begin
		     state_nxt = IDLE;
		 end
	endcase
end

always @(posedge i_usb_ifclk) begin
    case (state)
	    IDLE: begin
		    usb_slrd <= 1'b1;
			 usb_slwr <= 1'b1;
			 usb_sloe <= 1'b1;
			 usb_pkend <= 1'b1;
			 usb_addr <= 2'b00;
			 counter <= 0;
			 number <= 0;
			 usb_data <= 0;
			 flag_full = 1'b1;
		 end
		 SELECT_READ_FIFO: begin
		    usb_slrd <= 1'b1;
			 usb_slwr <= 1'b1;
			 // sloe low
			 usb_sloe <= 1'b0;
			 usb_pkend <= 1'b1;
			 // select EP2
			 usb_addr <= 2'b00;
			 counter <= 0;
			 number <= 0;
			 usb_data <= 0;
		 end
		 READ_FROM_USB: begin
		    // If EP2 is not empty, to read
		    usb_slrd <= ~i_usb_flaga;
			 usb_slwr <= 1'b1;
			 // sloe low
			 usb_sloe <= 1'b0;
			 usb_pkend <= 1'b1;
			 // select EP2
			 usb_addr <= 2'b00;
			 // If EP2 is not empty
			 if(~usb_slrd) begin
			     counter <= counter + 1'b1;
			 end
			 // To store into buffer
			 buff[counter] <= io_usb_data;
			 // To record the written number of words
			 number <= counter;
			 usb_data <= 0;
		 end
		 
		 /*新增*/
		 SELECT_WRITE_TO_FPGA: begin
			usb_we=1'b1;
		 end
		 
		 WRITE_TO_FPGA: begin
			
		 end
		 
		 SELECT_READ_FROM_FPGA: begin
		 
		 end
		 
		 READ_FROM_FPGA: begin
		 
		 end
		 
		 
		 /*新增END*/
		 
		 SELECT_WRITE_FIFO: begin
		    usb_slrd <= 1'b1;
			 usb_slwr <= 1'b1;
			 usb_sloe <= 1'b1;
			 if(i_usb_flagd == 1'b1) begin
			      usb_pkend <= 1'b1;
			 end
			 else begin
			      usb_pkend <= 1'b0;
			 end
			 // select EP6
			 usb_addr <= 2'b10;
			 counter <= 0;
			 usb_data <= 0;
		 end
		 WRITE_TO_USB: begin
		    usb_slrd <= 1'b1;
			 // If EP6 is not full, to write
			 usb_slwr <= ~i_usb_flagd;
			 usb_sloe <= 1'b1;
			 // If EP6 is full or written completely, submit data
			 if((i_usb_flagd == 1'b0) || (counter == number)) begin
			     usb_pkend <= 1'b0; 
			 end
			 else begin
			     usb_pkend <= 1'b1;
			 end
			 // select EP6
			 usb_addr <= 2'b10;
			 counter <= counter + 1'b1;
			 usb_data <= buff[counter];
		 end
		 default: begin
		    usb_slrd <= 1'b1;
			 usb_slwr <= 1'b1;
			 usb_sloe <= 1'b1;
			 usb_pkend <= 1'b1;
			 usb_addr <= 2'b00;
			 counter <= 0;
			 number <= 0;
			 usb_data <= 0;
		 end
	 endcase
end
endmodule
