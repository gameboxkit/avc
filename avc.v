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

	output [8:0] MAP_X,
	output [7:0] MAP_Y,

	output [8:0] SPRITE_X,
	output [7:0] SPRITE_Y,

	output reg BLANK,
	output reg VBLANK
);

reg[8:0] XCNT, XCNT_1, XCNT_2, XCNT_3, XCNT_4;
reg[8:0] YCNT, YCNT_1, YCNT_2, YCNT_3, YCNT_4; 

assign MAP_X = XCNT_2;
assign MAP_Y = YCNT_2[8:1];

assign SPRITE_X = XCNT;
assign SPRITE_Y = YCNT[8:1];

always @ (posedge DOTCLK)
	begin
		XCNT_1 <= XCNT;
		XCNT_2 <= XCNT_1;
		XCNT_3 <= XCNT_2;
		XCNT_4 <= XCNT_3;
		
		YCNT_1 <= YCNT;
		YCNT_2 <= YCNT_1;
		YCNT_3 <= YCNT_2;
		YCNT_4 <= YCNT_3;
		
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
		
		if ((YCNT_4 >= 411) && (YCNT_4 <= 412)) VSYNC <= 1;  
		if ((XCNT_4 >= 327) && (XCNT_4 <= 374)) HSYNC <= 0;
		
		if (YCNT_4 < 400) 
			begin
				VBLANK <= 0;
				if (XCNT_4 < 320) BLANK <= 0;
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
	input [7:0] D,
	
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
	
	input VISIBLE0, 
	input [9:0] ADDR0,
	input VISIBLE1, 
	input [9:0] ADDR1,
	input VISIBLE2, 
	input [9:0] ADDR2,
	input VISIBLE3, 
	input [9:0] ADDR3,
	input VISIBLE4, 
	input [9:0] ADDR4,
	input VISIBLE5,
	input [9:0] ADDR5,
	input VISIBLE6,
	input [9:0] ADDR6,
	input VISIBLE7, 
	input [9:0] ADDR7,

	output reg VISIBLE,
	output reg [12:0] ADDR
);

always @ (posedge DOTCLK)
	begin
		VISIBLE <= 1'b0;
		ADDR <= 13'b0000000000000;
		
		if (VISIBLE7 == 1) begin VISIBLE <= 1; ADDR <= { 3'b111, ADDR7}; end
		if (VISIBLE6 == 1) begin VISIBLE <= 1; ADDR <= { 3'b110, ADDR6}; end
		if (VISIBLE5 == 1) begin VISIBLE <= 1; ADDR <= { 3'b101, ADDR5}; end
		if (VISIBLE4 == 1) begin VISIBLE <= 1; ADDR <= { 3'b100, ADDR4}; end
		if (VISIBLE3 == 1) begin VISIBLE <= 1; ADDR <= { 3'b011, ADDR3}; end
		if (VISIBLE2 == 1) begin VISIBLE <= 1; ADDR <= { 3'b010, ADDR2}; end
		if (VISIBLE1 == 1) begin VISIBLE <= 1; ADDR <= { 3'b001, ADDR1}; end
		if (VISIBLE0 == 1) begin VISIBLE <= 1; ADDR <= { 3'b000, ADDR0}; end

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
	input [11:0] A,
	input [7:0] D,

	input [12:0] ADDR,
	input IN_VISIBLE,
	
	output [10:0] COLOR,
	output reg VISIBLE
);

reg[5:0] COLOR_LATCH;

assign COLOR[10:4] = { 1'b1, COLOR_LATCH };

always @ (posedge DOTCLK) 
	begin
		VISIBLE <= IN_VISIBLE;
		COLOR_LATCH <= { ADDR[12:7] };
	end
	
RAMB16_S2_S4 ram0 (
   .WEB(W),       // Port B Write Enable Input
   .ADDRB(A),  	// Port B 12-bit Address Input
   .CLKB(CLK),    // Port B Clock
   .DIB(D[3:0]),  // Port B 4-bit Data Input
   .ENB(W),       // Port B RAM Enable Input
   .SSRB(0),      // Port B Synchronous Set/Reset Input

   .CLKA(DOTCLK),  
   .ENA(1),     
   .SSRA(0),    
   .DOA(COLOR[1:0]),
   .WEA(0),     
   .ADDRA(ADDR)
);

RAMB16_S2_S4 ram1 (
   .WEB(W),       // Port B Write Enable Input
   .ADDRB(A),  	// Port B 12-bit Address Input
   .CLKB(CLK),    // Port B Clock
   .DIB(D[7:4]),  // Port B 4-bit Data Input
   .ENB(W),       // Port B RAM Enable Input
   .SSRB(0),      // Port B Synchronous Set/Reset Input

   .CLKA(DOTCLK),  
   .ENA(1),     
   .SSRA(0),    
   .DOA(COLOR[3:2]),
   .WEA(0),     
   .ADDRA(ADDR)
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


reg[2:0] HITILE;
wire[7:0] OUT[0:7];
wire OUTF[0:7];

assign COLOR = { 1'b0, HITILE[2:1], OUT[HITILE] };
assign FOREGROUND = OUTF[HITILE];

wire W0 = W & (A[13:11] == 3'b000);
wire W1 = W & (A[13:11] == 3'b001);
wire W2 = W & (A[13:11] == 3'b010);
wire W3 = W & (A[13:11] == 3'b011);
wire W4 = W & (A[13:11] == 3'b100);
wire W5 = W & (A[13:11] == 3'b101);
wire W6 = W & (A[13:11] == 3'b110);
wire W7 = W & (A[13:11] == 3'b111);

always @ (posedge DOTCLK) HITILE <= { TILE[7:5] };

RAMB16_S9_S9 ram0 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W0),	.SSRA(0), .WEA(W0), 
	.DOB(OUT[0]), .DOPB(OUTF[0]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram1 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W1),	.SSRA(0), .WEA(W1), 
	.DOB(OUT[1]), .DOPB(OUTF[1]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram2 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W2),	.SSRA(0), .WEA(W2), 
	.DOB(OUT[2]), .DOPB(OUTF[2]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram3 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W3),	.SSRA(0), .WEA(W3), 
	.DOB(OUT[3]), .DOPB(OUTF[3]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram4 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W4),	.SSRA(0), .WEA(W4), 
	.DOB(OUT[4]), .DOPB(OUTF[4]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram5 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W5),	.SSRA(0), .WEA(W5), 
	.DOB(OUT[5]), .DOPB(OUTF[5]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram6 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W6),	.SSRA(0), .WEA(W6), 
	.DOB(OUT[6]), .DOPB(OUTF[6]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );
RAMB16_S9_S9 ram7 ( .CLKA(CLK), .ADDRA(A[10:0]), .DIA(D[7:0]), .DIPA(D[8]), .ENA(W7),	.SSRA(0), .WEA(W7), 
	.DOB(OUT[7]), .DOPB(OUTF[7]), .ADDRB( { TILE[4:0], TILE_Y, TILE_X }), .CLKB(DOTCLK), .ENB(1), .WEB(0), .SSRB(0) );

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
	
	output reg VISIBLE,
	output reg [9:0] ADDR
);

wire W_SPRITE0 = W & (A[7:5] == 3'b000);
wire W_SPRITE1 = W & (A[7:5] == 3'b001);
wire W_SPRITE2 = W & (A[7:5] == 3'b010);
wire W_SPRITE3 = W & (A[7:5] == 3'b011);
wire W_SPRITE4 = W & (A[7:5] == 3'b100);
wire W_SPRITE5 = W & (A[7:5] == 3'b101);
wire W_SPRITE6 = W & (A[7:5] == 3'b110);
wire W_SPRITE7 = W & (A[7:5] == 3'b111);

wire[6:0] ADDR0, ADDR1, ADDR2, ADDR3, ADDR4, ADDR5, ADDR6, ADDR7;

SPRITE sprite0 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE0), .A(A[4:0]), .D(D), .OUT(ADDR0), .VISIBLE(VISIBLE0) );
SPRITE sprite1 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE1), .A(A[4:0]), .D(D), .OUT(ADDR1), .VISIBLE(VISIBLE1) );
SPRITE sprite2 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE2), .A(A[4:0]), .D(D), .OUT(ADDR2), .VISIBLE(VISIBLE2) );
SPRITE sprite3 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE3), .A(A[4:0]), .D(D), .OUT(ADDR3), .VISIBLE(VISIBLE3) );
SPRITE sprite4 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE4), .A(A[4:0]), .D(D), .OUT(ADDR4), .VISIBLE(VISIBLE4) );
SPRITE sprite5 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE5), .A(A[4:0]), .D(D), .OUT(ADDR5), .VISIBLE(VISIBLE5) );
SPRITE sprite6 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE6), .A(A[4:0]), .D(D), .OUT(ADDR6), .VISIBLE(VISIBLE6) );
SPRITE sprite7 (.CLK(CLK), .DOTCLK(DOTCLK), .X(X), .Y(Y), .W(W_SPRITE7), .A(A[4:0]), .D(D), .OUT(ADDR7), .VISIBLE(VISIBLE7) );

always @ (posedge DOTCLK)
	begin
		VISIBLE <= 1'b0;
		ADDR <= 10'b0000000000;
		
		if (VISIBLE7 == 1) begin VISIBLE <= 1; ADDR <= { 3'b111, ADDR7}; end
		if (VISIBLE6 == 1) begin VISIBLE <= 1; ADDR <= { 3'b110, ADDR6}; end
		if (VISIBLE5 == 1) begin VISIBLE <= 1; ADDR <= { 3'b101, ADDR5}; end
		if (VISIBLE4 == 1) begin VISIBLE <= 1; ADDR <= { 3'b100, ADDR4}; end
		if (VISIBLE3 == 1) begin VISIBLE <= 1; ADDR <= { 3'b011, ADDR3}; end
		if (VISIBLE2 == 1) begin VISIBLE <= 1; ADDR <= { 3'b010, ADDR2}; end
		if (VISIBLE1 == 1) begin VISIBLE <= 1; ADDR <= { 3'b001, ADDR1}; end
		if (VISIBLE0 == 1) begin VISIBLE <= 1; ADDR <= { 3'b000, ADDR0}; end
	end

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

wire W_SPRITE = (A[15] == 0) & W;					/* sprite blocks = $0000-$7FFF */
wire W_TILE = (A[15:14] == 2'b10) & W;				/* tile RAM = $8000-$BFFF */
wire W_MAP = (A[15:12] == 4'b1100) & W;			/* map RAM = $C000-$CFFF */
wire W_PALETTE = (A[15:12] == 4'b1101) & W;		/* palette RAM = $D000-$DFFF */
wire W_SPRITERAM = (A[15:12] == 4'b1110) & W;	/* sprite RAM = $E000-$EFFF */
/* W_AUDIO = (A[15:12] == 4'b1111) & W; */		/* audio = $F000-FFFF */

wire W_SPRITEBLOCK0 = W_SPRITE & (A[13:11] == 3'b000);
wire W_SPRITEBLOCK1 = W_SPRITE & (A[13:11] == 3'b001);
wire W_SPRITEBLOCK2 = W_SPRITE & (A[13:11] == 3'b010);
wire W_SPRITEBLOCK3 = W_SPRITE & (A[13:11] == 3'b011);
wire W_SPRITEBLOCK4 = W_SPRITE & (A[13:11] == 3'b100);
wire W_SPRITEBLOCK5 = W_SPRITE & (A[13:11] == 3'b101);
wire W_SPRITEBLOCK6 = W_SPRITE & (A[13:11] == 3'b110);
wire W_SPRITEBLOCK7 = W_SPRITE & (A[13:11] == 3'b111);

wire[8:0] MAP_X, SPRITE_X;
wire[7:0] MAP_Y, SPRITE_Y;

VIDEO_TIMING video_timing (
	.DOTCLK(DOTCLK),
	.VSYNC(VSYNC),
	.HSYNC(HSYNC),
	.MAP_X(MAP_X),
	.MAP_Y(MAP_Y),
	.SPRITE_X(SPRITE_X),
	.SPRITE_Y(SPRITE_Y),
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
	.X(MAP_X),
	.Y(MAP_Y),
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
	.FOREGROUND(FOREGROUND)
);

wire[9:0] 	ADDR0, ADDR1, ADDR2, ADDR3, ADDR4, ADDR5, ADDR6, ADDR7;
				
SPRITEBLOCK spriteblock0 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK0), .A( { A[10:8], A[4:0] } ), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR0), .VISIBLE(VISIBLE0));
SPRITEBLOCK spriteblock1 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK1), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR1), .VISIBLE(VISIBLE1));
SPRITEBLOCK spriteblock2 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK2), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR2), .VISIBLE(VISIBLE2));
SPRITEBLOCK spriteblock3 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK3), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR3), .VISIBLE(VISIBLE3));
SPRITEBLOCK spriteblock4 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK4), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR4), .VISIBLE(VISIBLE4));
SPRITEBLOCK spriteblock5 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK5), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR5), .VISIBLE(VISIBLE5));
SPRITEBLOCK spriteblock6 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK6), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR6), .VISIBLE(VISIBLE6));
SPRITEBLOCK spriteblock7 (.DOTCLK(DOTCLK), .CLK(CLK),	.W(W_SPRITEBLOCK7), .A({ A[10:8], A[4:0] }), .D(D[8:0]), .X(SPRITE_X), .Y(SPRITE_Y),
	.ADDR(ADDR7), .VISIBLE(VISIBLE7));

wire[12:0] SPRITE_ADDR;

SPRITEMUX spritemux (
	.DOTCLK(DOTCLK),
	
	.ADDR0(ADDR0), .VISIBLE0(VISIBLE0), 
	.ADDR1(ADDR1), .VISIBLE1(VISIBLE1), 
	.ADDR2(ADDR2), .VISIBLE2(VISIBLE2), 
	.ADDR3(ADDR3), .VISIBLE3(VISIBLE3), 
	.ADDR4(ADDR4), .VISIBLE4(VISIBLE4), 
	.ADDR5(ADDR5), .VISIBLE5(VISIBLE5), 
	.ADDR6(ADDR6), .VISIBLE6(VISIBLE6), 
	.ADDR7(ADDR7), .VISIBLE7(VISIBLE7), 
	
	.ADDR(SPRITE_ADDR),
	.VISIBLE(SPRITE_VISIBLE)
);
	
wire[10:0] SPRITE_COLOR;

SPRITERAM spriteram (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	
	.W(W_SPRITERAM),
	.A(A[11:0]),
	.D(D[7:0]),

	.ADDR(SPRITE_ADDR),
	.IN_VISIBLE(SPRITE_VISIBLE),
	
	.COLOR(SPRITE_COLOR),
	.VISIBLE(VISIBLE)
); 

wire[8:0] PALETTE_OUT;

PALETTE palette (
	.CLK(CLK),
	.DOTCLK(DOTCLK),
	.W(W_PALETTE),
	.A(A[10:0]),
	.D(D[8:0]),
	.TILE_COLOR(TILE_COLOR),
	.FOREGROUND(FOREGROUND),
	.SPRITE_COLOR(SPRITE_COLOR),
	.VISIBLE(VISIBLE),
	.OUT(PALETTE_OUT)
);
 

assign RED = BLANK ? 0 : PALETTE_OUT[8:6];
assign GREEN = BLANK ? 0 : PALETTE_OUT[5:3];
assign BLUE = BLANK ? 0 : PALETTE_OUT[2:0];

endmodule
