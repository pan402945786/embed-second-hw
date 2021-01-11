`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:02:55 11/01/2016 
// Design Name: 
// Module Name:    fpga 
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
`define  DELAY            25'd24000000
module fpga(
	//--------------	Clock Input ----------------------------------------------//
//	input			      CLOCK_48,				 //	24 MHz
	//--------------	LED ------------------------------------------------------//
	output	[3:0]	   LED,					    //	LED [3:0]
	//--------------  SDRAM Interface ------------------------------------------//
//	inout	   [15:0]	SDRAM_DQ,				 //	SDRAM Data bus 16 Bits
//	output	[12:0]	SDRAM_ADDR,				 //	SDRAM Address bus 13 Bits
//	output	[1:0]	   SDRAM_DQM,				 //	SDRAM Data Mask 
//	output			   SDRAM_WE_N,				 //	SDRAM Write Enable
//	output			   SDRAM_CAS_N,			 //	SDRAM Column Address Strobe
//	output			   SDRAM_RAS_N,			 //	SDRAM Row Address Strobe
//	output	[1:0]	   SDRAM_BA,				 //	SDRAM Bank Address 
//	output			   SDRAM_CLK,				 //	SDRAM Clock	
//	output			   SDRAM_CS_N,				 //	SDRAM Chip Select
//	output			   SDRAM_CKE,				 //	SDRAM Clock Enable
	//-------------	USB Interface ------------------------------------------//
	inout	   [15:0]	USB_DATA,				 //	USB Data bus 16 Bits
	output	[1:0]	   USB_ADDR,				 //	USB Address bus 2 Bits
	output			   USB_SLRD,				 //	USB Read Enable
	output			   USB_SLWR,				 //	USB Write Enable
	output			   USB_SLOE,				 //	USB Output Enable
	input			      USB_FLAGA,				 //	USB Flag
	input			      USB_FLAGD,				 //	USB Flag
	output			   USB_PKEND,				 //	USB Packet end
	//output			   USB_WU2,				    //	USB Wake Up USB2
	output STATE,
	input			      USB_IFCLK				 //	USB Clock inout
//	input			      USB_CLK_OUT,			 //	USB Clock Output
//	input	   [1:0]	   USB_INT,				    //   USB Interrupt
	//------------    GPIO --------------------------------------------------//
//	inout	   [33:0]	GPIOA,					 //   GPIOA, Can Be Used as Differential Pairs
//	inout	   [33:0]	GPIOB					    //   GPIOB, Can Be Used as Differential Pairs
	);


localparam IDLE = 4'b0000;
localparam SELECT_READ_FIFO = 4'b0001;
localparam READ_FROM_USB = 4'b0010;
localparam SELECT_WRITE_SDRAM = 4'b0011;
localparam WRITE_TO_SDRAM = 4'b0100;
localparam SELECT_WRITE_FIFO = 4'b0111;
localparam WRITE_TO_USB = 4'b1000;

//localparam IDLE = 4'b0000,
//			  SELECT_READ_FIFO = 4'b0001,
//			  READ_FROM_USB = 4'b0010,
//			  CAL_CONV = 4'b0011,
//			  CAL_SUM = 4'b0100,
//			  SELECT_WRITE_FIFO = 4'b0101,
//			  WRITE_TO_USB = 4'b0110;

localparam DATA_WIDTH = 16; 

reg[31:0] data_read_from_sdram [`MAXPKG - 1 : 0];
reg [`LOGMAXPKG - 1 : 0] sdram_counter = 0;
reg [12:0] sdram_addr_temp = 0;

reg read_finish = 0;


reg [3 : 0]              state = 0;
reg [3 : 0]              state_nxt = 0;
//reg [DATA_WIDTH - 1 : 0] buff [`MAXPKG - 1 : 0];
reg [DATA_WIDTH - 1 : 0] buff [32768 - 1 : 0];
reg [`LOGMAXPKG - 1 : 0] counter = 0;
reg [`LOGMAXPKG - 1 : 0] number = 0;
reg                      usb_slrd = 1'b1;
reg                      usb_slwr = 1'b1;
reg                      usb_sloe = 1'b1;
reg                      usb_pkend = 1'b1;
reg [1 : 0]              usb_addr = 2'b00;
reg [DATA_WIDTH - 1 :  0]usb_data = 0;

reg [3:0] led = 4'b0;
reg [24 :0] delay_counter = 0;

assign USB_ADDR = usb_addr;
assign USB_SLRD = usb_slrd;
assign USB_SLWR = usb_slwr;
assign USB_SLOE = usb_sloe;
assign USB_PKEND= usb_pkend;
assign USB_DATA= (usb_sloe == 1'b1)? usb_data : 'bz;
assign LED = led;

wire[3:0] STATE;
assign STATE = state;

/*
×´Ì¬»ú
*/
always @(posedge USB_IFCLK) begin
   state <= state_nxt;
end
always @(*) begin
   case (state)
	    IDLE: begin
			  // EP2 not empty
		     if (USB_FLAGA == 1'b1) begin
			  // Transform to SELECT_READ_FIFO
			      state_nxt = SELECT_READ_FIFO;
			  end
			  else begin
			      state_nxt = IDLE;
			  end
			  $display("IDLE\n");
			  // led = IDLE;
		 end
		 SELECT_READ_FIFO: begin
		    state_nxt = READ_FROM_USB;
			 $display("SELECT_READ_FIFO\n");
			 // led = SELECT_READ_FIFO;
		 end
		 READ_FROM_USB: begin
		    if((counter == `MAXPKG - 1) || (USB_FLAGA == 1'b0))begin
			     state_nxt = SELECT_WRITE_FIFO;
          end
          else begin
			     state_nxt = READ_FROM_USB;
			 end
			 $display("READ_FROM_USB\n");
			 // led = READ_FROM_USB;
		 end
		 
		 SELECT_WRITE_FIFO: begin
		     if(USB_FLAGD == 1'b1) begin
		         state_nxt = WRITE_TO_USB;
			  end
			  else begin
			      state_nxt = SELECT_WRITE_FIFO;
			  end
			  $display("SELECT_WRITE_FIFO\n");
			  // led = SELECT_WRITE_FIFO;
		 end
		 WRITE_TO_USB: begin
		    if ((counter >= number) || (USB_FLAGD == 1'b0)) begin
			     state_nxt = IDLE;
			 end
			 else begin
			     state_nxt = WRITE_TO_USB;
			 end
			 $display("WRITE_TO_USB\n");
			 // led = WRITE_TO_USB;
		 end
		 default: begin
		     state_nxt = IDLE;
			  $display("default\n");
			  // led = 4'b1111;
		 end
	endcase
end

always @(posedge USB_IFCLK) begin
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
			 sdram_counter <= 0;
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
			 sdram_counter <= 0;
			 number <= 0;
			 usb_data <= 0;
		 end
		 READ_FROM_USB: begin
		    // If EP2 is not empty, to read
		    usb_slrd <= ~USB_FLAGA;
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
			 buff[counter] <= USB_DATA;
			 // To record the written number of words
			 number <= counter;
			 usb_data <= 0;
		 end
		 SELECT_WRITE_FIFO: begin
		    usb_slrd <= 1'b1;
			 usb_slwr <= 1'b1;
			 usb_sloe <= 1'b1;
			 if(USB_FLAGD == 1'b1) begin
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
			 usb_slwr <= ~USB_FLAGD;
			 usb_sloe <= 1'b1;
			 // If EP6 is full or written completely, submit data
			 if((USB_FLAGD == 1'b0) || (counter == number)) begin
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
