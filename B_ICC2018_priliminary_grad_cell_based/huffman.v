module huffman(clk, reset, gray_valid, CNT_valid, CNT1, CNT2, CNT3, CNT4, CNT5, CNT6,
code_valid,gray_data, HC1, HC2, HC3, HC4, HC5, HC6,M1, M2, M3, M4, M5, M6);

input clk;
input reset;
input gray_valid;
input [7:0] gray_data;
output reg CNT_valid;
output reg [7:0] CNT1, CNT2, CNT3, CNT4, CNT5, CNT6;
output reg code_valid;
output reg[7:0] HC1, HC2, HC3, HC4, HC5, HC6;
output reg[7:0] M1, M2, M3, M4, M5, M6;

//==================
//  Integers
//==================
integer i;
genvar idx;

//==================
//  PARAMETERS
//==================
parameter BYTE          = 8 ;
parameter DATA_WIDTH    = 4 ;
parameter TABLE_SIZE    = 12;
parameter CNT_WIDTH     = 8 ;

//==================
//  stateS
//==================
//L1 FSM
localparam RD_DATA           = 5'b00001 ;
localparam SORT_FIND_ORDER   = 5'b00010 ;
localparam COMBINE           = 5'b00100 ;
localparam BACKTRACK         = 5'b01000 ;
localparam DONE              = 5'b10000 ;

//================================
//  MAIN CTR
//================================
reg [4:0] l1_curState,l1_nxtState;

wire state_RD_DATA          = l1_curState[0];
wire state_SORT_FIND_ORDER  = l1_curState[1];
wire state_COMBINE          = l1_curState[2];
wire state_BACKTRACK        = l1_curState[3];
wire state_DONE             = l1_curState[4];

//================================
//  TABLES
//================================
reg  [TABLE_SIZE-1:0] a_sequence[0:5];
reg  [TABLE_SIZE-1:0] c_sequence[0:4];
reg  [BYTE-1:0] code [0:10];
reg  [BYTE-1:0] mask [0:5];

//================================
//  COUNTERS
//================================
reg [CNT_WIDTH-1:0] global_cnt;
reg [CNT_WIDTH-1:0] sort_cnt;
reg [CNT_WIDTH-1:0] c_cnt;
reg [CNT_WIDTH-1:0] mask_ptr;

//================================
//        wire observation
//================================
wire [DATA_WIDTH-1:0] a_symbol[0:5];
wire [DATA_WIDTH-1:0] c_idx0[0:4];
wire [DATA_WIDTH-1:0] c_idx1[0:4];
wire [DATA_WIDTH-1:0] c_symbol[0:4];
wire [BYTE-1:0] a_probalility[0:5];

generate
    for (idx = 0; idx < 6; idx=idx+1) begin
        assign a_symbol[idx]      = a_sequence[idx][11:8];
        assign a_probalility[idx] = a_sequence[idx][7:0];
    end
endgenerate

generate
    for (idx = 0; idx < 5; idx=idx+1) begin
        assign c_idx0[idx]        = c_sequence[idx][7:4];
        assign c_idx1[idx]        = c_sequence[idx][3:0];
        assign c_symbol[idx]      = c_sequence[idx][11:8 ];
    end
endgenerate

//================================
//  CONTROL FLAGS
//================================
wire rd_data_done_f     = global_cnt == 100;
wire sort_done_f        = sort_cnt == 5;
wire allTableCombined_f = c_cnt == 4;
wire backTrackDone_f    = c_cnt == 0 && state_BACKTRACK;
reg  bubble_sort_st;

//operator
wire [7:0] ls_c_symbol  = code[c_symbol[c_cnt]] << 1;//left shift
wire c_larger_index_lt  = c_idx0[c_cnt] > 5;
wire c_smaller_index_lt = c_idx1[c_cnt] > 5;

//================================================================
//  MAIN DESIGN
//================================================================

//================================
//  level 1 FSM
//================================
always @(posedge clk or posedge reset)
begin:L1_FSM
    if(reset)
    begin
        l1_curState <=  RD_DATA;
    end
    else
    begin
        l1_curState <=  l1_nxtState;
    end
end

always @(*)
begin:L1_FSM_NXT
    case(l1_curState)
        RD_DATA:
        begin
            l1_nxtState = rd_data_done_f ? SORT_FIND_ORDER : RD_DATA;
        end
        SORT_FIND_ORDER:
        begin
            l1_nxtState = sort_done_f ? COMBINE : SORT_FIND_ORDER;
        end
        COMBINE:
        begin
            l1_nxtState = allTableCombined_f ? BACKTRACK : SORT_FIND_ORDER;
        end
        BACKTRACK:
        begin
            l1_nxtState = backTrackDone_f ? DONE : BACKTRACK;
        end
        default:
        begin
            l1_nxtState = RD_DATA;
        end
    endcase
end

//================================
//        SORT
//================================

always @(posedge clk or posedge reset) begin
    if(reset) bubble_sort_st <= 0;
    else if(l1_curState == SORT_FIND_ORDER) bubble_sort_st <= ~bubble_sort_st;
    else bubble_sort_st <= 0;
end


//================================
//        cnt
//================================
always@(posedge clk or posedge reset)
begin
    if(reset) sort_cnt <= 0;
    else if(l1_curState == SORT_FIND_ORDER) sort_cnt<=sort_cnt+1;
    else sort_cnt <= 0;
end

always@(posedge clk or posedge reset)
begin
    if(reset) c_cnt <= 0;
    else if(backTrackDone_f) c_cnt <= 0;
    else if(state_COMBINE)   c_cnt<= allTableCombined_f ?  c_cnt : c_cnt+1;
    else if(state_BACKTRACK) c_cnt<= c_cnt-1;
    else c_cnt <= c_cnt ;
end

always@(posedge clk or posedge reset)
begin
    if(reset) global_cnt <= 0;
    else if(rd_data_done_f) global_cnt <= 0;
    else if(l1_curState == RD_DATA && gray_valid) global_cnt<=global_cnt+1;
    else global_cnt <= global_cnt;
end

//================================
//        TABLES
//================================

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(i=0;i<6;i=i+1)
        begin
            a_sequence[i][11:8] <= i; 
            a_sequence[i][7:0] <= {8{1'b0}};
        end
    end
    else if(state_RD_DATA && gray_valid)
    begin
        a_sequence[0][7:0]<=  gray_data == 1 ?  a_probalility[0] + 1 : a_probalility[0];
        a_sequence[1][7:0]<=  gray_data == 2 ?  a_probalility[1] + 1 : a_probalility[1];
        a_sequence[2][7:0]<=  gray_data == 3 ?  a_probalility[2] + 1 : a_probalility[2];
        a_sequence[3][7:0]<=  gray_data == 4 ?  a_probalility[3] + 1 : a_probalility[3];
        a_sequence[4][7:0]<=  gray_data == 5 ?  a_probalility[4] + 1 : a_probalility[4];
        a_sequence[5][7:0]<=  gray_data == 6 ?  a_probalility[5] + 1 : a_probalility[5];
    end
    else if(state_SORT_FIND_ORDER) // Bubble sort
    begin
        if(bubble_sort_st) begin
            for(i=0;i<6;i=i+2) begin
                if(a_probalility[i] < a_probalility[i+1]) begin
                    a_sequence[i+1] <= a_sequence[i];
                    a_sequence[i]   <= a_sequence[i+1];
                end
                else if(a_probalility[i] == a_probalility[i+1]) begin
                    a_sequence[i]   <= a_symbol[i] > a_symbol[i+1] ? a_sequence[i+1] : a_sequence[i];
                    a_sequence[i+1] <= a_symbol[i] > a_symbol[i+1] ? a_sequence[i] : a_sequence[i+1];
                end
            end
        end
        else begin
            for(i=1;i<5;i=i+2) begin
                if(a_probalility[i] < a_probalility[i+1]) begin
                    a_sequence[i+1] <= a_sequence[i];
                    a_sequence[i]   <= a_sequence[i+1];
                end
                else if(a_probalility[i] == a_probalility[i+1]) begin
                    a_sequence[i]   <= a_symbol[i] > a_symbol[i+1] ? a_sequence[i+1] : a_sequence[i];
                    a_sequence[i+1] <= a_symbol[i] > a_symbol[i+1] ? a_sequence[i] : a_sequence[i+1];
                end
            end
        end
    end
    else if(state_COMBINE)
    begin
        a_sequence[4][11:8] <= c_cnt + 6;
        a_sequence[4][7:0]  <= a_probalility[4] + a_probalility[5];
        a_sequence[5]       <= {TABLE_SIZE{1'b1}};//MAX
    end
end

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        c_sequence[4] <= 'd0;
        for(i=0;i<4;i=i+1)
        begin
            c_sequence[i][11:8]  <= i+6;
            c_sequence[i][7:0]   <= 'd0;
        end
    end
    else if(state_COMBINE)
    begin
        //larger in index 0 of c element
        c_sequence[c_cnt][7:4] <= a_symbol[4];
        c_sequence[c_cnt][3:0] <= a_symbol[5];
    end
end

//================================
//        BACKTRACK
//================================

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(i=0;i<11;i=i+1)
        begin
            code[i] <= {8{1'b0}};
        end
    end
    else if(state_BACKTRACK)
    begin
        code[c_idx0[c_cnt]] <= ls_c_symbol + 'd0;
        code[c_idx1[c_cnt]] <= ls_c_symbol + 'd1;
    end
    else
    begin
        for(i=0;i<11;i=i+1)
        begin
            code[i] <= code[i];
        end
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        mask_ptr <= 0;
    end
    else if(state_RD_DATA)
    begin
        mask_ptr <= 0;
    end
    else if(state_BACKTRACK && (c_larger_index_lt || c_smaller_index_lt))
    begin
        mask_ptr <= mask_ptr + 1;
    end
    else
    begin
        mask_ptr <= mask_ptr;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(i=0;i<6;i=i+1)
        begin
            mask[i] <= {8{1'b0}};
        end
    end
    else if(state_BACKTRACK)
    begin
        if(!c_larger_index_lt)
        begin
            case(mask_ptr)
                'd0: mask[c_idx0[c_cnt]] <= 8'b0000_0001;
                'd1: mask[c_idx0[c_cnt]] <= 8'b0000_0011;
                'd2: mask[c_idx0[c_cnt]] <= 8'b0000_0111;
                'd3: mask[c_idx0[c_cnt]] <= 8'b0000_1111;
                'd4: mask[c_idx0[c_cnt]] <= 8'b0001_1111;
                'd5: mask[c_idx0[c_cnt]] <= 8'b0011_1111;
                'd6: mask[c_idx0[c_cnt]] <= 8'b0000_0000;
                'd7: mask[c_idx0[c_cnt]] <= 8'b0000_0000;
            endcase
        end
        if(!c_smaller_index_lt)
        begin
            case(mask_ptr)
                'd0: mask[c_idx1[c_cnt]] <= 8'b0000_0001;
                'd1: mask[c_idx1[c_cnt]] <= 8'b0000_0011;
                'd2: mask[c_idx1[c_cnt]] <= 8'b0000_0111;
                'd3: mask[c_idx1[c_cnt]] <= 8'b0000_1111;
                'd4: mask[c_idx1[c_cnt]] <= 8'b0001_1111;
                'd5: mask[c_idx1[c_cnt]] <= 8'b0011_1111;
                'd6: mask[c_idx1[c_cnt]] <= 8'b0000_0000;
                'd7: mask[c_idx1[c_cnt]] <= 8'b0000_0000;
            endcase
        end
    end
    else
    begin
        for(i=0;i<6;i=i+1)
        begin
            mask[i] <= mask[i];
        end
    end
end

//================================
//        I/O
//================================
always@(*)
begin
    if(rd_data_done_f)
    begin
        CNT1 = a_sequence[0][7:0];
        CNT2 = a_sequence[1][7:0];
        CNT3 = a_sequence[2][7:0];
        CNT4 = a_sequence[3][7:0];
        CNT5 = a_sequence[4][7:0];
        CNT6 = a_sequence[5][7:0];
        CNT_valid = 1'b1;
    end
    else
        begin
        CNT1 = 0;
        CNT2 = 0;
        CNT3 = 0;
        CNT4 = 0;
        CNT5 = 0;
        CNT6 = 0;
        CNT_valid=1'b0;
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
       {HC1, HC2, HC3, HC4, HC5, HC6} <= 'd0;
       {M1, M2, M3, M4, M5, M6} <= 'd0;
       code_valid   <= 1'b0;
    end
    else if(state_DONE)
    begin
        HC1 <= code[0];
        HC2 <= code[1];
        HC3 <= code[2];
        HC4 <= code[3];
        HC5 <= code[4];
        HC6 <= code[5];

        M1  <= mask[0];
        M2  <= mask[1];
        M3  <= mask[2];
        M4  <= mask[3];
        M5  <= mask[4];
        M6  <= mask[5];

        code_valid <= 1'b1;
    end
end

endmodule
