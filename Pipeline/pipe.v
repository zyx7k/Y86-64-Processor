`include "fetch.v"
`include "decode.v"
`include "execute.v"   
`include "memory.v"
`include "control.v"

module processor();

reg clk;

// Fetch I/O
reg [63:0] F_predPC = 0;
reg [2:0] Stat;
reg [3:0] W_icode = 1;
reg M_cnd = 0;

// Fetch stage output
wire [3:0] f_icode, f_ifun, f_rA, f_rB;
wire [63:0] f_valC, f_valP;
wire [63:0] f_predPC;
wire [2:0] f_stat;

// Decode I/O
reg [2:0] D_stat = 1;
reg [3:0] D_icode = 1;
reg [3:0] D_ifun = 0; 
reg [3:0] D_rA = 0;
reg [3:0] D_rB = 0;
reg [63:0] D_valC = 0;
reg [63:0] D_valP = 0;

reg [3:0] W_dstM = 0;
reg [3:0] W_dstE = 0;
reg [63:0] W_valM = 0;
reg [63:0] W_valE = 0;

// Decode stage output
wire[2:0] d_stat;
wire[3:0] d_icode, d_ifun, d_srcA, d_srcB, d_dstE, d_dstM;
wire[63:0] d_valC, d_valA, d_valB;

// Execute I/O
reg [2:0] E_stat = 1;
reg [2:0] W_stat = 1;
reg [3:0] E_icode = 1;
reg [3:0] E_ifun = 0;
reg [3:0] E_dstE = 0;
reg [3:0] E_dstM = 0;
reg [3:0] E_srcA = 0;
reg [3:0] E_srcB = 0;
reg [63:0] E_valC = 0;
reg [63:0] E_valA = 0;
reg [63:0] E_valB = 0;

// Execute stage output
wire e_cnd, ZF, SF, OF;
wire [2:0] e_stat;
wire [3:0] e_icode, e_dstE, e_dstM;
wire [63:0] e_valE, e_valA;

// Memory I/O
reg [3:0] M_icode = 1;
reg [2:0] M_stat = 1;
reg [63:0] M_valA = 0; 
reg [63:0] M_valE = 0; 
reg [3:0] M_dstM = 0;
reg [3:0] M_dstE = 0; 

// Memory stage output
wire[3:0] m_icode;
wire[2:0] m_stat;
wire[63:0] m_valE; 
wire[63:0] m_valM; 
wire[3:0] m_dstM;
wire[3:0] m_dstE;


// ******** calling pipeline modules ********* //

fetch S1(
    F_predPC, M_icode, M_cnd, M_valA, W_icode, W_valM,
    f_icode, f_ifun, f_rA, f_rB, f_valC, f_valP, f_predPC, f_stat
);


decode S2(D_stat, D_icode, D_ifun, D_rA, D_rB, D_valC, D_valP, e_dstE, e_valE, M_dstE, M_valE, M_dstM, m_valM, W_dstM, W_valM, W_dstE, W_valE, clk, 
d_stat, d_icode, d_ifun, d_valC, d_valA, d_valB, d_dstE, d_dstM, d_srcA, d_srcB
);


execute S3(
    clk, E_stat, E_icode, E_ifun, E_valC, E_valA, E_valB, E_dstE, E_dstM, E_srcA, E_srcB, W_stat, m_stat,
    e_stat, e_icode, e_cnd, e_valE, e_valA, e_dstE, e_dstM, ZF, SF, OF
);


memory S4( clk, M_icode, M_stat, M_valA, M_valE, M_dstM, M_dstE, m_icode, m_stat, m_valE, m_valM, m_dstM, m_dstE 
);


// Code for Processor Status Code
// assign Stat = W_stat;


// Writing PipeLine Control Logic
wire W_stall, M_bubble, E_bubble, D_bubble, D_stall, F_stall;


control C1(W_stat, M_icode, m_stat, e_cnd, E_dstM, E_icode, d_srcA, d_srcB, D_icode, 
        W_stall, M_bubble, E_bubble, D_bubble, D_stall, F_stall    
        );

always @(W_stat)
begin
    Stat = W_stat;
end

// Updating F register at every positive edge of clock
always @(posedge clk)
begin 
    if(!F_stall)
    begin F_predPC <= f_predPC; end
end


// Updating D register at every positive edge of clock
always @(posedge clk)
begin
    if(!D_stall)
    begin
        if (!D_bubble)
        begin
            D_stat <= f_stat; 
            D_icode <= f_icode; 
            D_ifun <= f_ifun; 
            D_rA <= f_rA;
            D_rB <= f_rB;
            D_valC <= f_valC;
            D_valP <= f_valP; 
        end

        else
        begin
            D_stat <= 1; // AOK Normal Operation
            D_icode <= 1; //basically nop
            D_ifun <= 0; 
            D_rA <= 0;
            D_rB <= 0;
            D_valC <= 0;
            D_valP <= 0;
        end
    end
end

// Updating E register at every positive edge of clock
always @(posedge clk)
begin
    if(!E_bubble)
    begin
        E_stat <= d_stat; 
        E_icode <= d_icode; 
        E_ifun <= d_ifun; 
        E_valC <= d_valC;
        E_valA <= d_valA; 
        E_valB <= d_valB;
        E_dstE <= d_dstE;
        E_dstM <= d_dstM;
        E_srcA <= d_srcA;
        E_srcB <= d_srcB; 
    end
    else
    begin   
        E_stat <= 1; //AOK Normal Operation
        E_icode <= 1; // nop
        E_ifun <= 0;
        E_valC <= 0;
        E_valA <= 0; 
        E_valB <= 0;
        E_dstE <= 0;
        E_dstM <= 0;
        E_srcA <= 0;
        E_srcB <= 0; 
    end
end


// Updating M register at every positive edge of clock
always @(posedge clk)
begin
    if(!M_bubble)
    begin
        M_stat <= e_stat; 
        M_icode <= e_icode; 
        M_valA <= e_valA;
        M_valE <= e_valE; 
        M_cnd <= e_cnd; 
        M_dstE <= e_dstE;
        M_dstM <= e_dstM;
    end
    else
    begin
        M_stat <= 1; //AOK Normal Operation  
        M_icode <= 1; // nop
        M_valA <= 0;
        M_valE <= 0; 
        M_cnd <= 0; 
        M_dstE <= 0;
        M_dstM <= 0;
    end
end

// Updating W register at every positive edge of clock
always @(posedge clk)
begin
    if(!W_stall)
    begin
    
        W_stat <= m_stat; 
        W_icode <= m_icode;
        W_dstE <= m_dstE; 
        W_dstM <= m_dstM;
        W_valE <= m_valE;
        W_valM <= m_valM;
    end
end

initial 
    begin
        $dumpfile("processor_tb.vcd");
        $dumpvars(0, processor);  
    end

initial
begin
    clk = 0;    
end

always
    begin
    #10 clk = ~clk; 
    end


always@(*)
begin
    if(Stat != 1)
    begin
        $finish;
    end
end

endmodule
