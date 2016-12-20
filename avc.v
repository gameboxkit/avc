/****************************************************************************/

module CPU_INTERFACE (
	input CLK,
	input PHI2,
	input CSn,
	input [8:0] CPU_D,
   input [15:0] CPU_A,
	
	output reg [8:0] D,
	output reg [15:0] A,
	output reg W
);

reg SET;
reg[4:0] PHI2_sample;

always @ (posedge CLK)
	begin
		PHI2_sample <= { PHI2_sample[3:0], PHI2 };
		
		if ((PHI2_sample == 5'b00011) && (PHI2 == 1) && (CSn == 0)) 
			begin
				W <= 1;
				D <= CPU_D;
				A <= CPU_A;
			end
		else 
			W <= 0;
	end

endmodule

/****************************************************************************/

module VIDEO_TIMING (
	input DOTCLK,
	output reg VSYNC,
	output reg HSYNC,

	output [8:0] X,
	output [7:0] Y,

	output reg BLANK,
	output reg VBLANK
);

reg[8:0] XCNT, XCNT_1, XCNT_2, XCNT_3;
reg[8:0] YCNT, YCNT_1, YCNT_2, YCNT_3;

assign X = XCNT;
assign Y = YCNT[8:1];

always @ (posedge DOTCLK)
	begin
		XCNT_1 <= XCNT;
		XCNT_2 <= XCNT_1;
		XCNT_3 <= XCNT_2;
		YCNT_1 <= YCNT;
		YCNT_2 <= YCNT_1;
		YCNT_3 <= YCNT_2;
		
		XCNT <= XCNT + 1;
		if (XCNT == 399) 
			begin
				XCNT <= 0;
				YCNT <= YCNT + 1;
				if (YCNT == 448) YCNT <= 0;
			end
	
		HSYNC <= 1;
		VSYNC <= 0;
		BLANK <= 1;
		VBLANK <= 1;
		
		if ((YCNT_2 >= 411) && (YCNT_2 <= 412)) VSYNC <= 1;
		if ((XCNT_2 >= 327) && (XCNT_2 <= 374)) HSYNC <= 0;
		
		if (YCNT_2 < 400) 
			begin
				VBLANK <= 0;
				if (XCNT_2 < 320) BLANK <= 0;
			end
		
	end

endmodule

/****************************************************************************/

module PALETTE (
	input CLK,
	input DOTCLK,

	input W,
	input [10:0] A,
	input [8:0] D,

	input [10:0] TILE_COLOR,
	input FOREGROUND,
	input [10:0] SPRITE_COLOR,
	input VISIBLE,
	output [8:0] OUT
);

wire[10:0] COLOR = ((FOREGROUND == 0) && (VISIBLE == 1)) ? SPRITE_COLOR : TILE_COLOR;

RAMB16_S9_S9 paletteram (
	.ADDRA(A[10:0]),		// port A = CPU access.
	.CLKA(CLK),
   .DIA(D[7:0]),   
	.DIPA(D[8]),
   .ENA(W),       
   .WEA(W),
	.SSRA(0),
	
	.ADDRB(COLOR),			// port B = color lookup
	.CLKB(DOTCLK),
	.DOB(OUT[8:1]),
	.DOPB(OUT[0]),
	.ENB(1),
	.WEB(0),
	.SSRB(0)
);

endmodule

/****************************************************************************/

module MAP (
	input CLK,
	input DOTCLK,
	
	input[8:0] X,
	input[7:0] Y,
		
	input W,
	input [11:0] A,
	input [8:0] D,
	
	output[7:0] TILE,
	output reg[2:0] TILE_X,
	output reg[2:0] TILE_Y
);

wire W_RAM = W & ~A[11];
wire W_XOFS = W & A[11] & ~A[0];
wire W_YOFS = W & A[11] & A[0];

wire[10:0] MAP_A;

RAMB16_S9_S9 mapram (
	.ADDRA(A[10:0]),		// port A = CPU access.
	.CLKA(CLK),
   .DIA(D[7:0]),   
	.DIPA(0),
   .ENA(1),       
   .WEA(W_RAM),
	.SSRA(0),
	
	.ADDRB(MAP_A),			// port B = map lookup
	.CLKB(DOTCLK),
	.DOB(TILE),
	.ENB(1),
	.WEB(0),
	.SSRB(0)
);

reg[7:0] XOFS;
reg[5:0] YOFS;

wire[8:0] XADJ = X + XOFS;
wire[7:0] YADJ = Y + YOFS;

assign MAP_A = { YADJ[7:3], XADJ[8:3] };

always @ (posedge CLK) 
	begin
		if (W_XOFS) XOFS <= D[7:0];
		if (W_YOFS) YOFS <= D[5:0];
	end

always @ (posedge DOTCLK)
	begin
		TILE_X <= XADJ[2:0];
		TILE_Y <= YADJ[2:0];
	end

endmodule

/****************************************************************************/

module SPRITEMUX (
	input DOTCLK,
	
	input IN_VISIBLE0, 
	input [6:0] IN0,
	input [2:0] IN_SPRITENO0,
	input IN_VISIBLE1, 
	input [6:0] IN1,
	input [2:0] IN_SPRITENO1,
	input IN_VISIBLE2, 
	input [6:0] IN2,
	input [2:0] IN_SPRITENO2,
	input IN_VISIBLE3, 
	input [6:0] IN3,
	input [2:0] IN_SPRITENO3,
	input IN_VISIBLE4, 
	input [6:0] IN4,
	input [2:0] IN_SPRITENO4,
	input IN_VISIBLE5,
	input [6:0] IN5,
	input [2:0] IN_SPRITENO5,
	input IN_VISIBLE6,
	input [6:0] IN6,
	input [2:0] IN_SPRITENO6,
	input IN_VISIBLE7, 
	input [6:0] IN7,
	input [2:0] IN_SPRITENO7,

	output reg VISIBLE,
	output reg [6:0] OUT,
	output reg [2:0] SPRITENO,
	output reg [2:0] LSPRITENO
);

always @ (posedge DOTCLK)
	begin
		VISIBLE <= 1'b0;
		OUT <= 7'b0000000;
		SPRITENO <= 3'b000;
		LSPRITENO <= 3'b000;
		
		if (IN_VISIBLE7 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO7; SPRITENO <= 3'b111; OUT <= IN7; end
		if (IN_VISIBLE6 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO6; SPRITENO <= 3'b110; OUT <= IN6; end
		if (IN_VISIBLE5 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO5; SPRITENO <= 3'b101; OUT <= IN5; end
		if (IN_VISIBLE4 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO4; SPRITENO <= 3'b100; OUT <= IN4; end
		if (IN_VISIBLE3 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO3; SPRITENO <= 3'b011; OUT <= IN3; end
		if (IN_VISIBLE2 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO2; SPRITENO <= 3'b010; OUT <= IN2; end
		if (IN_VISIBLE1 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO1; SPRITENO <= 3'b001; OUT <= IN1; end
		if (IN_VISIBLE0 == 1) begin VISIBLE <= 1; LSPRITENO <= IN_SPRITENO0; SPRITENO <= 3'b000; OUT <= IN0; end

	end
endmodule

/****************************************************************************/


module SPRITE (
	input CLK,
	input DOTCLK,
	
	input [8:0] X,
	input [7:0] Y,
	
	input W,
	input [4:0] A,
	input [8:0] D,
	
	output reg[6:0] OUT,
	output reg VISIBLE
);

wire W_X = W & ~A[4] & ~A[0];
wire W_Y = W & ~A[4] & A[0];
wire W_VISIBLE = W & A[4];

reg[8:0] POS_X;
reg[7:0] POS_Y;

wire[8:0] SPRITE_X = X - POS_X;
wire[7:0] SPRITE_Y = Y - POS_Y;
wire[7:0] MASK;

RAM16X1D mask0 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[0]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[0]));
RAM16X1D mask1 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[1]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[1]));
RAM16X1D mask2 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[2]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[2]));
RAM16X1D mask3 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[3]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[3]));
RAM16X1D mask4 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[4]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[4]));
RAM16X1D mask5 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[5]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[5]));
RAM16X1D mask6 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[6]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[6]));
RAM16X1D mask7 (.WCLK(CLK), .WE(W_VISIBLE), .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .D(D[7]),   
      .DPRA0(SPRITE_Y[0]), .DPRA1(SPRITE_Y[1]), .DPRA2(SPRITE_Y[2]), .DPRA3(SPRITE_Y[3]), .DPO(MASK[7]));

always @ (posedge CLK)
	begin
		if (W_X) POS_X <= D[8:0];
		if (W_Y) POS_Y <= D[7:0];
	end
	
always @ (posedge DOTCLK)
	begin
		OUT <= { SPRITE_Y[3:0], SPRITE_X[2:0] };
		VISIBLE <= 0;
		if ((SPRITE_Y < 16) && (SPRITE_X < 8))	VISIBLE <= MASK[SPRITE_X[2:0]];
	end

endmodule

/****************************************************************************/

module SPRITERAM (
	input CLK,
	input DOTCLK,
	
	input W,
	input [12:0] A,
	input [3:0] D,

	input [5:0] SPRITENO,
	input [6:0] ADDR,
	input IN_VISIBLE,
	
	output [10:0] COLOR,
	output reg VISIBLE
);

reg[6:0] COLOR_LATCH;

assign COLOR[10:4] = COLOR_LATCH;

always @ (posedge DOTCLK) 
	begin
		VISIBLE <= IN_VISIBLE;
		COLOR_LATCH <= { 1'b1, SPRITENO };
	end

RAMB16_S2_S2 bits10 (
      .DOB(COLOR[1:0]),      	
      .ADDRB( { SPRITENO, ADDR } ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[1:0]),
      .SSRA(0)   
);

RAMB16_S2_S2 bits32 (
      .DOB(COLOR[3:2]),      	
      .ADDRB( { SPRITENO, ADDR } ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[3:2]),
      .SSRA(0)   
);

endmodule

/****************************************************************************/

module TILERAM (
	input CLK,

	input W,
	input [13:0] A,
	input [8:0] D,
	
   input DOTCLK,
   input [7:0] TILE,
   input [2:0] TILE_X,
	input [2:0] TILE_Y,
	
	output [10:0] COLOR,
	output FOREGROUND
);

assign COLOR[10] = 1'b0;

reg[1:0] HICOLOR;

assign COLOR[9:8] = HICOLOR;

always @ (posedge DOTCLK) HICOLOR <= { TILE[7:6] };

RAMB16_S1_S1 bit0 (
      .DOB(COLOR[0]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[0]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit1 (
      .DOB(COLOR[1]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[1]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit2 (
      .DOB(COLOR[2]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[2]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit3 (
      .DOB(COLOR[3]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[3]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit4 (
      .DOB(COLOR[4]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[4]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit5 (
      .DOB(COLOR[5]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[5]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit6 (
      .DOB(COLOR[6]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[6]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit7 (
      .DOB(COLOR[7]),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[7]),
      .SSRA(0)   
);

RAMB16_S1_S1 bit8 (
      .DOB(FOREGROUND),      	
      .ADDRB( { TILE, TILE_Y, TILE_X} ),  	
      .CLKB(DOTCLK),    		
      .ENB(1),      				
      .SSRB(0),    			
      .WEB(0),       	

		.ENA(W),				
		.CLKA(CLK),
		.WEA(W),
		.ADDRA(A),
		.DIA(D[8]),
      .SSRA(0)   
);

endmodule

/****************************************************************************/

module SPRITEBLOCK (
	input CLK,
	input DOTCLK,

	input [8:0] X,
	input [7:0] Y,

	input W,
	input [7:0] A,
	input [8:0] D,
	
	output VISIBLE,
	output[6:0] ADDR,
	output[2:0] SPRITENO
);

wire W_SPRITE0 = W & (A[7:5] == 3'b000);
wire W_SPRITE1 = W & (A[7:5] == 3'b001);
wire W_SPRITE2 = W & (A[7:5] == 3'b010);
wire W_SPRITE3 = W & (A[7:5] == 3'b011);
wire W_SPRITE4 = W & (A[7:5] == 3'b100);
wire W_SPRITE5 = W & (A[7:5] == 3'b101);
wire W_SPRITE6 = W & (A[7:5] == 3'b110);
wire W_SPRITE7 = W & (A[7:5] == 3'b111);

wire[6:0] SPRITE0_ADDR, SPRITE1_ADDR, SPRITE2_ADDR, SPRITE3_ADDR, SPRITE4_ADDR, SPRITE5_ADDR, SPRITE6_ADDR, SPRITE7_ADDR;

SPRITEMUX spritemux (
	.DOTCLK(DOTCLK),
	
	.IN0(SPRITE0_ADDR), .IN_VISIBLE0(SPRITE0_VISIBLE), .IN_SPRITENO0(3'b000),
	.IN1(SPRITE1_ADDR), .IN_VISIBLE1(SPRITE1_VISIBLE), .IN_SPRITENO1(3'b000),
	.IN2(SPRITE2_ADDR), .IN_VISIBLE2(SPRITE2_VISIBLE), .IN_SPRITENO2(3'b000),
	.IN3(SPRITE3_ADDR), .IN_VISIBLE3(SPRITE3_VISIBLE), .IN_SPRITENO3(3'b000),
	.IN4(SPRITE4_ADDR), .IN_VISIBLE4(SPRITE4_VISIBLE), .IN_SPRITENO4(3'b000),
	.IN5(SPRITE5_ADDR), .IN_VISIBLE5(SPRITE5_VISIBLE), .IN_SPRITENO5(3'b000),
	.IN6(SPRITE6_ADDR), .IN_VISIBLE6(SPRITE6_VISIBLE), .IN_SPRITENO6(3'b000),
	.IN7(SPRITE7_ADDR), .IN_VISIBLE7(SPRITE7_VISIBLE), .IN_SPRITENO7(3'b000),
	
	.OUT(ADDR),
	.SPRITENO(SPRITENO),
	.VISIBLE(VISIBLE)
);

SPRITE sprite0 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE0), .A(A[4:0]), .D(D), .OUT(SPRITE0_ADDR), .VISIBLE(SPRITE0_VISIBLE) );
SPRITE sprite1 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE1), .A(A[4:0]), .D(D), .OUT(SPRITE1_ADDR), .VISIBLE(SPRITE1_VISIBLE) );
SPRITE sprite2 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE2), .A(A[4:0]), .D(D), .OUT(SPRITE2_ADDR), .VISIBLE(SPRITE2_VISIBLE) );
SPRITE sprite3 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE3), .A(A[4:0]), .D(D), .OUT(SPRITE3_ADDR), .VISIBLE(SPRITE3_VISIBLE) );
SPRITE sprite4 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE4), .A(A[4:0]), .D(D), .OUT(SPRITE4_ADDR), .VISIBLE(SPRITE4_VISIBLE) );
SPRITE sprite5 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE5), .A(A[4:0]), .D(D), .OUT(SPRITE5_ADDR), .VISIBLE(SPRITE5_VISIBLE) );
SPRITE sprite6 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE6), .A(A[4:0]), .D(D), .OUT(SPRITE6_ADDR), .VISIBLE(SPRITE6_VISIBLE) );
SPRITE sprite7 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE7), .A(A[4:0]), .D(D), .OUT(SPRITE7_ADDR), .VISIBLE(SPRITE7_VISIBLE) );

endmodule

/****************************************************************************/

module AVC (
	input CLK,
	input PHI2,

   input CSn,
   input [8:0] CPU_D,
   input [15:0] CPU_A,
	
   output VBLK,
	
	output VSYNC,
	output HSYNC,
	
	output [2:0] RED,
	output [2:0] GREEN,
	output [2:0] BLUE
);

DCM_SP # (.CLK_FEEDBACK("2X"),.CLKDV_DIVIDE(4.0)) clock (.CLKIN(CLK), .CLK2X(CLKFB), .CLKDV(DOTCLK), .CLKFB(CLKFB));

wire[8:0] D;
wire[15:0] A;
 
CPU_INTERFACE cpu_interface (
	.CLK(CLK),
	.PHI2(PHI2),
	.CSn(CSn),
	.D(D),
   .A(A),
	.CPU_D(CPU_D),
	.CPU_A(CPU_A),
	.W(W)
);

wire W_MAP = (A[15:12] == 4'b0100) & W;
wire W_TILE = (A[15:14] == 2'b00) & W;
wire W_PALETTE = (A[15:12] == 4'b1111) & W;
wire W_SPRITERAM = (A[15:13] == 3'b100) & W;
wire W_SPRITE = (A[15:12] == 4'b1100) & W;

wire W_SPRITEBLOCK0 = W_SPRITE & (A[10:8] == 3'b000);
wire W_SPRITEBLOCK1 = W_SPRITE & (A[10:8] == 3'b001);
wire W_SPRITEBLOCK2 = W_SPRITE & (A[10:8] == 3'b010);
wire W_SPRITEBLOCK3 = W_SPRITE & (A[10:8] == 3'b011);
wire W_SPRITEBLOCK4 = W_SPRITE & (A[10:8] == 3'b100);
wire W_SPRITEBLOCK5 = W_SPRITE & (A[10:8] == 3'b101);
wire W_SPRITEBLOCK6 = W_SPRITE & (A[10:8] == 3'b110);
wire W_SPRITEBLOCK7 = W_SPRITE & (A[10:8] == 3'b111);


wire[8:0] X;
wire[7:0] Y;

VIDEO_TIMING video_timing (
	.DOTCLK(DOTCLK),
	.VSYNC(VSYNC),
	.HSYNC(HSYNC),
	.X(X),
	.Y(Y),
	.BLANK(BLANK),
	.VBLANK(VBLK)
);

wire[7:0] TILE;
wire[2:0] TILE_X;
wire[2:0] TILE_Y;

MAP map (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	.W(W_MAP),
	.A(A[11:0]),
	.D(D[7:0]),
	.X(X),
	.Y(Y),
	.TILE(TILE),
	.TILE_X(TILE_X),
	.TILE_Y(TILE_Y)
);

wire[10:0] TILE_COLOR;

TILERAM tileram (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	.W(W_TILE),
	.A(A[13:0]),
	.D(D[8:0]),
	.TILE(TILE),
	.TILE_X(TILE_X),
	.TILE_Y(TILE_Y),
	.COLOR(TILE_COLOR),
	.FOREGROUND(TILE_FOREGROUND)
);

wire[6:0] 	SPRITEBLOCK0_ADDR, SPRITEBLOCK1_ADDR, SPRITEBLOCK2_ADDR, SPRITEBLOCK3_ADDR,
				SPRITEBLOCK4_ADDR, SPRITEBLOCK5_ADDR, SPRITEBLOCK6_ADDR, SPRITEBLOCK7_ADDR;
				
wire[2:0] 	SPRITEBLOCK0_SPRITENO, SPRITEBLOCK1_SPRITENO, SPRITEBLOCK2_SPRITENO, SPRITEBLOCK3_SPRITENO,
				SPRITEBLOCK4_SPRITENO, SPRITEBLOCK5_SPRITENO, SPRITEBLOCK6_SPRITENO, SPRITEBLOCK7_SPRITENO;

SPRITEBLOCK spriteblock0 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK0), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK0_ADDR), .SPRITENO(SPRITEBLOCK0_SPRITENO), .VISIBLE(SPRITEBLOCK0_VISIBLE));
SPRITEBLOCK spriteblock1 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK1), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK1_ADDR), .SPRITENO(SPRITEBLOCK1_SPRITENO), .VISIBLE(SPRITEBLOCK1_VISIBLE));
SPRITEBLOCK spriteblock2 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK2), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK2_ADDR), .SPRITENO(SPRITEBLOCK2_SPRITENO), .VISIBLE(SPRITEBLOCK2_VISIBLE));
SPRITEBLOCK spriteblock3 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK3), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK3_ADDR), .SPRITENO(SPRITEBLOCK3_SPRITENO), .VISIBLE(SPRITEBLOCK3_VISIBLE));
SPRITEBLOCK spriteblock4 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK4), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK4_ADDR), .SPRITENO(SPRITEBLOCK4_SPRITENO), .VISIBLE(SPRITEBLOCK4_VISIBLE));
SPRITEBLOCK spriteblock5 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK5), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK5_ADDR), .SPRITENO(SPRITEBLOCK5_SPRITENO), .VISIBLE(SPRITEBLOCK5_VISIBLE));
SPRITEBLOCK spriteblock6 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK6), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK6_ADDR), .SPRITENO(SPRITEBLOCK6_SPRITENO), .VISIBLE(SPRITEBLOCK6_VISIBLE));
SPRITEBLOCK spriteblock7 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK7), .A(A[7:0]), .D(D[8:0]), .X(X), .Y(Y),
	.ADDR(SPRITEBLOCK7_ADDR), .SPRITENO(SPRITEBLOCK7_SPRITENO), .VISIBLE(SPRITEBLOCK7_VISIBLE));

wire[6:0] SPRITEMUX_ADDR;
wire[2:0] SPRITEMUX_SPRITENO;
wire[2:0] SPRITEMUX_LSPRITENO;

SPRITEMUX spritemux (
	.DOTCLK(DOTCLK),
	
	.IN0(SPRITEBLOCK0_ADDR), .IN_VISIBLE0(SPRITEBLOCK0_VISIBLE), .IN_SPRITENO0(SPRITEBLOCK0_SPRITENO),
	.IN1(SPRITEBLOCK1_ADDR), .IN_VISIBLE1(SPRITEBLOCK1_VISIBLE), .IN_SPRITENO1(SPRITEBLOCK1_SPRITENO),
	.IN2(SPRITEBLOCK2_ADDR), .IN_VISIBLE2(SPRITEBLOCK2_VISIBLE), .IN_SPRITENO2(SPRITEBLOCK2_SPRITENO),
	.IN3(SPRITEBLOCK3_ADDR), .IN_VISIBLE3(SPRITEBLOCK3_VISIBLE), .IN_SPRITENO3(SPRITEBLOCK3_SPRITENO),
	.IN4(SPRITEBLOCK4_ADDR), .IN_VISIBLE4(SPRITEBLOCK4_VISIBLE), .IN_SPRITENO4(SPRITEBLOCK4_SPRITENO),
	.IN5(SPRITEBLOCK5_ADDR), .IN_VISIBLE5(SPRITEBLOCK5_VISIBLE), .IN_SPRITENO5(SPRITEBLOCK5_SPRITENO),
	.IN6(SPRITEBLOCK6_ADDR), .IN_VISIBLE6(SPRITEBLOCK6_VISIBLE), .IN_SPRITENO6(SPRITEBLOCK6_SPRITENO),
	.IN7(SPRITEBLOCK7_ADDR), .IN_VISIBLE7(SPRITEBLOCK7_VISIBLE), .IN_SPRITENO7(SPRITEBLOCK7_SPRITENO),
	
	.OUT(SPRITEMUX_ADDR),
	.SPRITENO(SPRITEMUX_SPRITENO),
	.LSPRITENO(SPRITEMUX_LSPRITENO),
	.VISIBLE(SPRITEMUX_VISIBLE)
);
	
wire[10:0] SPRITE_COLOR;

SPRITERAM spriteram (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	
	.W(W_SPRITERAM),
	.A(A[12:0]),
	.D(D[3:0]),

	.SPRITENO({ SPRITEMUX_SPRITENO, SPRITEMUX_LSPRITENO }),
	.ADDR(SPRITEMUX_ADDR),
	.IN_VISIBLE(SPRITEMUX_VISIBLE),
	
	.COLOR(SPRITE_COLOR),
	.VISIBLE(SPRITE_VISIBLE)
);

wire[8:0] PALETTE_OUT;

PALETTE palette (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	.W(W_PALETTE),
	.A(A[10:0]),
	.D(D[8:0]),
	.TILE_COLOR(TILE_COLOR),
	.FOREGROUND(TILE_FOREGROUND),
	.SPRITE_COLOR(SPRITE_COLOR),
	.VISIBLE(SPRITE_VISIBLE),
	.OUT(PALETTE_OUT)
);


assign RED = BLANK ? 0 : PALETTE_OUT[8:6];
assign GREEN = BLANK ? 0 : PALETTE_OUT[5:3];
assign BLUE = BLANK ? 0 : PALETTE_OUT[2:0];

endmodule
