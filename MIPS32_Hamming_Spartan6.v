`timescale 1ns / 1ps
// ==========================================================
// TOP-LEVEL MODULE: MIPS + HAMMING(7,4) GENERATION & DETECTION + LCD
// ==========================================================
module top_mips_hamming (
    input  board_clk,     
    input  board_rst,     // Logic 1 = Reset, Logic 0 = Run
    
    // sw_in[3:0]  -> 4-bit Data
    // sw_in[10:4] -> 7-bit Error Mask
    input  [10:0] sw_in,   
    
    // Expanded to 10 bits to show both Syndrome and Hamming
    // led_out[9:7] = Syndrome
    // led_out[6:0] = Corrupted Hamming Code
    output [9:0] led_out, 
    
    output led_halted,    
	 
	 // LCD Pins for RNFDB SP6-V1
    output [2:0] lcd_cntrl, // P11, P10, P9
    output [3:0] lcd_data   // P16, P15, P14, P12
);
    wire clk1, clk2;
    reg [5:0] count = 0;
    reg r_clk1 = 0, r_clk2 = 0;
    
    wire [6:0] w_hamming;  // Internal wire for R28 (Hamming)
    wire [2:0] w_syndrome; // Internal wire for R29 (Syndrome)

    // Combine both wires to the physical LED output pins
    assign led_out = {w_syndrome, w_hamming}; 

	 // Clock divider for MIPS core
    always @(posedge board_clk) begin
        count <= count + 1;
        r_clk1 <= (count == 1); 
        r_clk2 <= (count == 32); 
    end
    assign clk1 = r_clk1;
    assign clk2 = r_clk2;

	 // Instantiate MIPS Processor
    pipe_MIPS32 processor (
        .clk1(clk1), .clk2(clk2),
        .rst(board_rst), 
        .num1(sw_in),
        .result_led(w_hamming),   
        .result_syn(w_syndrome),  
        .halted(led_halted)
    );

	 // Instantiate LCD Controller (Unchanged)
    lcd_controller display_unit (
        .clk(board_clk),
        .rst(board_rst),
        .syndrome(w_syndrome),
        .processor_halted(led_halted),
        .cntrl(lcd_cntrl),
        .data(lcd_data)
    );
endmodule

// ==========================================================
// LCD CONTROLLER (Wait for Halt, 7-pin Interface)
// ==========================================================
module lcd_controller(
    input clk,
    input rst,
    input [2:0] syndrome,
    input processor_halted,
    output reg [3:0] data,
    output reg [2:0] cntrl
);
    reg [6:0] lcdheader;
    reg [6:0] state;
    reg [22:0] clkdiv = 23'd0;
    reg [6:0] clkstate;
    reg [2:0] syn_latched;

    always @ (posedge clk) begin
        clkdiv <= clkdiv + 1'b1;
    end

    always @ (posedge clkdiv[17] or posedge rst) begin
        if (rst) begin
            clkstate <= 7'd0;
            syn_latched <= 3'b000;
        end else begin
            case (clkstate)
                7'd21: if (processor_halted) begin
                           syn_latched <= syndrome;
                           clkstate <= (syndrome == 3'b000) ? 7'd40 : 7'd22;
                       end else begin
                           clkstate <= 7'd21;
                       end
                7'd33: clkstate <= 7'd70; 
                7'd63: clkstate <= 7'd70; 
                7'd70: clkstate <= 7'd70; 
                default: clkstate <= clkstate + 1'b1;
            endcase
        end
    end

    always @ (*) begin
        state = clkstate;
        case(state)
            // INITIALIZATION (0-21)
            7'd0:lcdheader=7'b1000011; 7'd1:lcdheader=7'b0000011; 
            7'd2:lcdheader=7'b1000011; 7'd3:lcdheader=7'b0000011; 
            7'd4:lcdheader=7'b1000010; 7'd5:lcdheader=7'b0000010; 
            7'd6:lcdheader=7'b1000010; 7'd7:lcdheader=7'b0000010; 
            7'd8:lcdheader=7'b1001000; 7'd9:lcdheader=7'b0001000; 
            7'd10:lcdheader=7'b1000000; 7'd11:lcdheader=7'b0000000; 
            7'd12:lcdheader=7'b1000110; 7'd13:lcdheader=7'b0000110; 
            7'd14:lcdheader=7'h40;      7'd15:lcdheader=7'h00;      
            7'd16:lcdheader=7'h4F;      7'd17:lcdheader=7'h0F;      
            7'd18:lcdheader=7'h40;      7'd19:lcdheader=7'h00;      
            7'd20:lcdheader=7'h41;      7'd21:lcdheader=7'h01;      

            // "Err:X" SEQUENCE (22-33)
            7'd22:lcdheader=7'h54; 7'd23:lcdheader=7'h14; 
            7'd24:lcdheader=7'h55; 7'd25:lcdheader=7'h15; 
            7'd26:lcdheader=7'h53; 7'd27:lcdheader=7'h13; 
            7'd28:lcdheader=7'h5A; 7'd29:lcdheader=7'h1A; 
            7'd30:lcdheader=7'b1010011; 
            7'd31:lcdheader=7'b0010011; 
            7'd32:lcdheader={3'b101, 1'b0, syn_latched}; 
            7'd33:lcdheader={3'b001, 1'b0, syn_latched}; 

            // "No Error" SEQUENCE (40-63)
            7'd40:lcdheader=7'h54; 7'd41:lcdheader=7'h14;
            7'd42:lcdheader=7'h5E; 7'd43:lcdheader=7'h1E;
            7'd44:lcdheader=7'h56; 7'd45:lcdheader=7'h16;
            7'd46:lcdheader=7'h5F; 7'd47:lcdheader=7'h1F;
            7'd48:lcdheader=7'h52; 7'd49:lcdheader=7'h12;
            7'd50:lcdheader=7'h50; 7'd51:lcdheader=7'h10;
            7'd52:lcdheader=7'h54; 7'd53:lcdheader=7'h14;
            7'd54:lcdheader=7'h55; 7'd55:lcdheader=7'h15;
            7'd56:lcdheader=7'h57; 7'd57:lcdheader=7'h17;
            7'd58:lcdheader=7'h52; 7'd59:lcdheader=7'h12;
            7'd60:lcdheader=7'h57; 7'd61:lcdheader=7'h17;
            7'd62:lcdheader=7'h52; 7'd63:lcdheader=7'h12;

            default: lcdheader = 7'b1111111;
        endcase

        data[3:0]  = lcdheader[3:0]; 
        cntrl[2:0] = lcdheader[6:4]; 
    end
endmodule

// ==========================================================
// MIPS32 PROCESSOR
// ==========================================================
module pipe_MIPS32 (
    input clk1, clk2, rst,
    input [10:0] num1,
    output [6:0] result_led,
    output [2:0] result_syn,
    output halted
);
    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;
    reg [31:0] EX_MEM_IR, EX_MEM_ALUOut;
    reg [31:0] MEM_WB_IR, MEM_WB_ALUOut;

    reg [31:0] Reg [0:31];   
    reg [31:0] Mem [0:1023]; 

    parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011,
              XOR=6'b000110, SLL=6'b000111, SRL=6'b001000, HLT=6'b111111;
    parameter RR_ALU=3'b000, RM_ALU=3'b001, HALT=3'b101;

    reg HALTED;
    
    // Connect mapping requested for distinct displays
    assign result_led = Reg[28][6:0]; // R28: Corrupted Hamming
    assign result_syn = Reg[29][2:0]; // R29: Syndrome
    assign halted = HALTED;

    integer k;
    initial begin
        for (k = 0; k < 1024; k = k + 1) Mem[k] = 32'h0;
        
        Mem[0] = 32'h281b0001; // R27 = 1 (Mask)
        Mem[1] = 32'h28150001; // R21 = 1
        Mem[2] = 32'h28160002; // R22 = 2
        Mem[3] = 32'h28170003; // R23 = 3
        Mem[4] = 32'h28180004; // R24 = 4
        Mem[5] = 32'h28190005; // R25 = 5
        Mem[6] = 32'h281a0006; // R26 = 6

        // Extract Generation Bits
        Mem[7] = 32'h083b2800; // AND R5, R1, R27
        Mem[8] = 32'h20354800; // SRL R9, R1, R21
        Mem[9] = 32'h0ffff800; Mem[10] = 32'h0ffff800; Mem[11] = 32'h0ffff800;
        Mem[12]= 32'h093b2000; // AND R4, R9, R27
        Mem[13]= 32'h20364800; // SRL R9, R1, R22
        Mem[14]= 32'h0ffff800; Mem[15]= 32'h0ffff800; Mem[16]= 32'h0ffff800;
        Mem[17]= 32'h093b1800; // AND R3, R9, R27
        Mem[18]= 32'h20374800; // SRL R9, R1, R23
        Mem[19]= 32'h0ffff800; Mem[20]= 32'h0ffff800; Mem[21]= 32'h0ffff800;
        Mem[22]= 32'h093b1000; // AND R2, R9, R27
        
        // --- FIX 1: NOPs ADDED HERE ---
        Mem[23]= 32'h0ffff800; Mem[24]= 32'h0ffff800; Mem[25]= 32'h0ffff800;

        // Calculate Parities
        Mem[26]= 32'h18435000; // XOR R10, R2, R3
        Mem[27]= 32'h0ffff800; Mem[28]= 32'h0ffff800; Mem[29]= 32'h0ffff800;
        Mem[30]= 32'h19455800; // XOR R11, R10, R5 (p1)
        Mem[31]= 32'h18446000; // XOR R12, R2, R4
        Mem[32]= 32'h0ffff800; Mem[33]= 32'h0ffff800; Mem[34]= 32'h0ffff800;
        Mem[35]= 32'h19856800; // XOR R13, R12, R5 (p2)
        Mem[36]= 32'h18647000; // XOR R14, R3, R4
        Mem[37]= 32'h0ffff800; Mem[38]= 32'h0ffff800; Mem[39]= 32'h0ffff800;
        Mem[40]= 32'h19c57800; // XOR R15, R14, R5 (p3)

        // Shifting and Formatting
        Mem[41]= 32'h1CBA8000; // SLL R16, R5, R26 (d4 << 6)
        Mem[42]= 32'h1C998800; // SLL R17, R4, R25 (d3 << 5)
        Mem[43]= 32'h1C789000; // SLL R18, R3, R24 (d2 << 4)
        Mem[44]= 32'h1DF79800; // SLL R19, R15, R23 (p3 << 3)
        Mem[45]= 32'h1C56A000; // SLL R20, R2, R22 (d1 << 2)
        Mem[46]= 32'h1DB55000; // SLL R10, R13, R21 (p2 << 1)
        Mem[47]= 32'h0ffff800; Mem[48]= 32'h0ffff800; Mem[49]= 32'h0ffff800;

        // Clean Hamming Code Assembly inside R28
        Mem[50]= 32'h0E11E000; // OR R28, R16, R17
        Mem[51]= 32'h0ffff800; Mem[52]= 32'h0ffff800; Mem[53]= 32'h0ffff800;
        Mem[54]= 32'h0F92E000; // OR R28, R28, R18
        Mem[55]= 32'h0ffff800; Mem[56]= 32'h0ffff800; Mem[57]= 32'h0ffff800;
        Mem[58]= 32'h0F93E000; // OR R28, R28, R19
        Mem[59]= 32'h0ffff800; Mem[60]= 32'h0ffff800; Mem[61]= 32'h0ffff800;
        Mem[62]= 32'h0F94E000; // OR R28, R28, R20
        Mem[63]= 32'h0ffff800; Mem[64]= 32'h0ffff800; Mem[65]= 32'h0ffff800;
        Mem[66]= 32'h0F8AE000; // OR R28, R28, R10
        Mem[67]= 32'h0ffff800; Mem[68]= 32'h0ffff800; Mem[69]= 32'h0ffff800;
        Mem[70]= 32'h0F8BE000; // OR R28, R28, R11

        // Inject Error using Error Mask (R30)
        Mem[71]= 32'h0ffff800; Mem[72]= 32'h0ffff800; Mem[73]= 32'h0ffff800;
        Mem[74]= 32'h1B9EE000; // XOR R28, R28, R30

        // Copy corrupted sequence back to R1
        Mem[75]= 32'h0ffff800; Mem[76]= 32'h0ffff800; Mem[77]= 32'h0ffff800;
        Mem[78]= 32'h0F800800; // OR R1, R28, R0

        // Extract and process for Syndrome Logic
        Mem[79]= 32'h0ffff800; Mem[80]= 32'h0ffff800; Mem[81]= 32'h0ffff800;
        Mem[82]= 32'h083b1000; // AND R2, R1, R27
        Mem[83]= 32'h20354800; // SRL R9, R1, R21
        Mem[84]= 32'h0ffff800; Mem[85]= 32'h0ffff800; Mem[86]= 32'h0ffff800;
        Mem[87]= 32'h093b1800; // AND R3, R9, R27
        Mem[88]= 32'h20364800; // SRL R9, R1, R22
        Mem[89]= 32'h0ffff800; Mem[90]= 32'h0ffff800; Mem[91]= 32'h0ffff800;
        Mem[92]= 32'h093b2000; // AND R4, R9, R27
        Mem[93]= 32'h20374800; // SRL R9, R1, R23
        Mem[94]= 32'h0ffff800; Mem[95]= 32'h0ffff800; Mem[96]= 32'h0ffff800;
        Mem[97]= 32'h093b2800; // AND R5, R9, R27
        Mem[98]= 32'h20384800; // SRL R9, R1, R24
        Mem[99]= 32'h0ffff800; Mem[100]=32'h0ffff800; Mem[101]=32'h0ffff800;
        Mem[102]=32'h093b3000; // AND R6, R9, R27
        Mem[103]=32'h20394800; // SRL R9, R1, R25
        Mem[104]=32'h0ffff800; Mem[105]=32'h0ffff800; Mem[106]=32'h0ffff800;
        Mem[107]=32'h093b3800; // AND R7, R9, R27
        Mem[108]=32'h203a4800; // SRL R9, R1, R26
        Mem[109]=32'h0ffff800; Mem[110]=32'h0ffff800; Mem[111]=32'h0ffff800;
        Mem[112]=32'h093b4000; // AND R8, R9, R27

        // Syndrome Generation (S1, S2, S3)
        Mem[113]=32'h18445000; // XOR R10, R2, R4
        Mem[114]=32'h0ffff800; Mem[115]=32'h0ffff800; Mem[116]=32'h0ffff800;
        Mem[117]=32'h19465800; // XOR R11, R10, R6
        Mem[118]=32'h0ffff800; Mem[119]=32'h0ffff800; Mem[120]=32'h0ffff800;
        Mem[121]=32'h19686000; // XOR R12, R11, R8  (S1)

        Mem[122]=32'h18646800; // XOR R13, R3, R4
        Mem[123]=32'h0ffff800; Mem[124]=32'h0ffff800; Mem[125]=32'h0ffff800;
        Mem[126]=32'h19A77000; // XOR R14, R13, R7
        Mem[127]=32'h0ffff800; Mem[128]=32'h0ffff800; Mem[129]=32'h0ffff800;
        Mem[130]=32'h19C87800; // XOR R15, R14, R8  (S2)

        Mem[131]=32'h18A68000; // XOR R16, R5, R6
        Mem[132]=32'h0ffff800; Mem[133]=32'h0ffff800; Mem[134]=32'h0ffff800;
        Mem[135]=32'h1A078800; // XOR R17, R16, R7
        Mem[136]=32'h0ffff800; Mem[137]=32'h0ffff800; Mem[138]=32'h0ffff800;
        Mem[139]=32'h1A289000; // XOR R18, R17, R8  (S3)

        // --- FIX 2: NOPs ADDED HERE ---
        Mem[140]=32'h0ffff800; Mem[141]=32'h0ffff800; Mem[142]=32'h0ffff800; 
        
        // Store Syndrome cleanly in R29
        Mem[143]=32'h1E569800; // SLL R19, R18, R22 (S3 << 2)
        Mem[144]=32'h1DF5A000; // SLL R20, R15, R21 (S2 << 1)
        Mem[145]=32'h0ffff800; Mem[146]=32'h0ffff800; Mem[147]=32'h0ffff800;
        Mem[148]=32'h0E74E800; // OR R29, R19, R20
        Mem[149]=32'h0ffff800; Mem[150]=32'h0ffff800; Mem[151]=32'h0ffff800;
        
        // ---> THE FIX: Changed 0FACC800 (R25) to 0FACE800 (R29) <---
        Mem[152]=32'h0FACE800; // OR R29, R29, R12

        // System Halt 
        Mem[153]=32'hfc000000; // HLT
    end

    // PHASE 1: Reset check and Forward Logic
    always @(posedge clk1) begin
        if (rst) begin
            PC <= 0;
            HALTED <= 0;
            IF_ID_IR <= 0;
            EX_MEM_IR <= 0;
            EX_MEM_type <= 0;
            EX_MEM_ALUOut <= 0;
            for (k=0; k<32; k=k+1) Reg[k] <= 0;
            
            // Fulfilling: "Clear ALL, Load 4-bit into R1, Load mask into R30"
            Reg[1]  <= {28'b0, num1[3:0]}; 
            Reg[30] <= {25'b0, num1[10:4]}; 
        end 
        else if (!HALTED) begin
            IF_ID_IR <= Mem[PC];
            IF_ID_NPC <= PC + 1;
            PC <= PC + 1;

            EX_MEM_type <= ID_EX_type; 
            EX_MEM_IR   <= ID_EX_IR;
            case (ID_EX_type)
                RR_ALU: begin
                    case (IF_ID_IR[31:26])
                        ADD: EX_MEM_ALUOut <= ID_EX_A + ID_EX_B;
                        SUB: EX_MEM_ALUOut <= ID_EX_A - ID_EX_B;
                        AND: EX_MEM_ALUOut <= ID_EX_A & ID_EX_B;
                        OR:  EX_MEM_ALUOut <= ID_EX_A | ID_EX_B;
                        XOR: EX_MEM_ALUOut <= ID_EX_A ^ ID_EX_B;
                        SLL: EX_MEM_ALUOut <= ID_EX_A << ID_EX_B;
                        SRL: EX_MEM_ALUOut <= ID_EX_A >> ID_EX_B;
                        default: EX_MEM_ALUOut <= 0;
                    endcase
                end
                RM_ALU: EX_MEM_ALUOut <= ID_EX_A + ID_EX_Imm;
            endcase

            if (MEM_WB_type == RR_ALU) Reg[MEM_WB_IR[15:11]] <= MEM_WB_ALUOut;
            if (MEM_WB_type == RM_ALU) Reg[MEM_WB_IR[20:16]] <= MEM_WB_ALUOut;
            if (MEM_WB_type == HALT)   HALTED <= 1'b1;
        end
    end

    // PHASE 2: Decode and Pipe Transfer
    always @(posedge clk2) begin
        if (rst) begin
            ID_EX_IR <= 0;
            ID_EX_A <= 0;
            ID_EX_B <= 0;
            ID_EX_Imm <= 0;
            ID_EX_type <= 0;
            MEM_WB_IR <= 0;
            MEM_WB_type <= 0;
            MEM_WB_ALUOut <= 0;
        end 
        else if (!HALTED) begin
            ID_EX_A <= (IF_ID_IR[25:21] == 0) ? 0 : Reg[IF_ID_IR[25:21]];
            ID_EX_B <= (IF_ID_IR[20:16] == 0) ? 0 : Reg[IF_ID_IR[20:16]];
            ID_EX_IR <= IF_ID_IR;
            ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};
            
            case (IF_ID_IR[31:26])
                ADD, SUB, AND, OR, XOR, SLL, SRL: ID_EX_type <= RR_ALU;
                6'h0a, 6'h0b: ID_EX_type <= RM_ALU; 
                HLT: ID_EX_type <= HALT;
                default: ID_EX_type <= RR_ALU;
            endcase

            MEM_WB_type <= EX_MEM_type; 
            MEM_WB_ALUOut <= EX_MEM_ALUOut;
            MEM_WB_IR <= EX_MEM_IR;
        end
    end
endmodule