`timescale 1ns/1ps
module TPU (
    input clk, rst_n, in_valid,
    input [7:0] K, M, N,
    output reg busy,

    // Buffer A Interface (DO NOT instantiate global_buffer here!)
    output reg         A_wr_en,
    output reg  [15:0] A_index,
    output reg  [31:0] A_data_in,
    input       [31:0] A_data_out,

    // Buffer B Interface
    output reg         B_wr_en,
    output reg  [15:0] B_index,
    output reg  [31:0] B_data_in,
    input       [31:0] B_data_out,

    // Buffer C Interface
    output reg         C_wr_en,
    output reg  [15:0] C_index,
    output reg [127:0] C_data_in,
    input      [127:0] C_data_out
);
    // ========================================
    // Parameters
    // ========================================
    localparam TILE = 4;
    localparam ELEM = 8;

    // ========================================
    // FSM States
    // ========================================
    localparam IDLE    = 2'd0;
    localparam LOAD    = 2'd1;
    localparam COMPUTE = 2'd2;
    localparam STORE   = 2'd3;

    reg [1:0] state, nstate;

    // ========================================
    // Tile Dimensions (ceiling division)
    // ========================================
    wire [7:0] M_tile = (M + 3) >> 2;
    wire [7:0] N_tile = (N + 3) >> 2;
    wire [7:0] K_tile = (K + 3) >> 2;

    reg [7:0] m_cnt, n_cnt, k_cnt;

    // ========================================
    // Base Addresses for SRAM
    // ========================================
    reg [15:0] baseA, baseB, baseC;

    // ========================================
    // in_valid Edge Detection
    // ========================================
    reg in_valid_d;
    wire in_valid_fall = in_valid_d && !in_valid;

    // ========================================
    // Counters
    // ========================================
    reg [3:0] load_cnt;   // 0-15
    reg [2:0] comp_cnt;   // 0-6
    reg [1:0] store_cnt;  // 0-3

    // ========================================
    // Tile Buffers (4x4)
    // ========================================
    reg [7:0] tileA [0:3][0:3];
    reg [7:0] tileB [0:3][0:3];

    // ========================================
    // Systolic Array I/O
    // ========================================
    wire [7:0]  sa_a [0:3];
    wire [7:0]  sa_b [0:3];
    wire [15:0] sa_c [0:15];

    // ========================================
    // Systolic Array Instantiation
    // ========================================
    Systolic_4 #(.data_size(ELEM)) u_sa (
        .clk(clk),
        .reset(~rst_n),  // Active-high reset for P_E
        .a1(sa_a[0]), .a2(sa_a[1]), .a3(sa_a[2]), .a4(sa_a[3]),
        .b1(sa_b[0]), .b2(sa_b[1]), .b3(sa_b[2]), .b4(sa_b[3]),
        .c1(sa_c[0]),  .c2(sa_c[1]),  .c3(sa_c[2]),  .c4(sa_c[3]),
        .c5(sa_c[4]),  .c6(sa_c[5]),  .c7(sa_c[6]),  .c8(sa_c[7]),
        .c9(sa_c[8]), .c10(sa_c[9]), .c11(sa_c[10]), .c12(sa_c[11]),
        .c13(sa_c[12]), .c14(sa_c[13]), .c15(sa_c[14]), .c16(sa_c[15])
    );

    // ========================================
    // busy Signal: Set on in_valid fall, clear when done
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            busy <= 0;
        else if (in_valid_fall)
            busy <= 1;
        else if (state == STORE && store_cnt == 3 &&
                 m_cnt == M_tile-1 && n_cnt == N_tile-1 && k_cnt == K_tile-1)
            busy <= 0;
    end

    // ========================================
    // in_valid Delay for Edge Detection
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            in_valid_d <= 0;
        else
            in_valid_d <= in_valid;
    end

    // ========================================
    // Next State Logic
    // ========================================
    always @* begin
        nstate = state;
        case (state)
            IDLE:    if (in_valid)     nstate = LOAD;
            LOAD:    if (load_cnt == 15) nstate = COMPUTE;
            COMPUTE: if (comp_cnt == 6)  nstate = STORE;
            STORE:   if (store_cnt == 3) nstate = IDLE;
            default: nstate = IDLE;
        endcase
    end

    // ========================================
    // State Register
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nstate;
    end

    // ========================================
    // Tile Counters (m, n, k)
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_cnt <= 0; n_cnt <= 0; k_cnt <= 0;
        end else if (state == IDLE && in_valid) begin
            m_cnt <= 0; n_cnt <= 0; k_cnt <= 0;
        end else if (state == STORE && store_cnt == 3) begin
            if (k_cnt == K_tile - 1) begin
                k_cnt <= 0;
                if (n_cnt == N_tile - 1) begin
                    n_cnt <= 0;
                    if (m_cnt < M_tile - 1)
                        m_cnt <= m_cnt + 1;
                end else
                    n_cnt <= n_cnt + 1;
            end else
                k_cnt <= k_cnt + 1;
        end
    end

    // ========================================
    // Base Address Update
    // ========================================
    always @(posedge clk) begin
        if (state == IDLE && in_valid) begin
            baseA <= 0; baseB <= 0; baseC <= 0;
        end else if (state == STORE && store_cnt == 3) begin
            baseA <= baseA + (K_tile << 2);  // +4 * K_tile
            baseB <= baseB + 16;             // +4 tiles
            baseC <= baseC + (N_tile << 2);  // +4 * N_tile
        end
    end

    // ========================================
    // LOAD State: Read 16 words from A and B
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_cnt <= 0;
            A_wr_en  <= 0;
            B_wr_en  <= 0;
        end else if (state == LOAD) begin
            A_index <= baseA + load_cnt;
            B_index <= baseB + load_cnt;
            A_wr_en <= 0;
            B_wr_en <= 0;

            // Unpack 32-bit word into 4x8-bit elements
            {tileA[load_cnt[1:0]][3], tileA[load_cnt[1:0]][2],
             tileA[load_cnt[1:0]][1], tileA[load_cnt[1:0]][0]} <= A_data_out;

            {tileB[load_cnt[1:0]][3], tileB[load_cnt[1:0]][2],
             tileB[load_cnt[1:0]][1], tileB[load_cnt[1:0]][0]} <= B_data_out;

            load_cnt <= (load_cnt == 15) ? 0 : load_cnt + 1;
        end else begin
            load_cnt <= 0;
        end
    end

    // ========================================
    // COMPUTE State: Feed data into Systolic Array
    // ========================================
    assign sa_a[0] = (comp_cnt < 4) ? tileA[comp_cnt][0] : 0;
    assign sa_a[1] = (comp_cnt < 4) ? tileA[comp_cnt][1] : 0;
    assign sa_a[2] = (comp_cnt < 4) ? tileA[comp_cnt][2] : 0;
    assign sa_a[3] = (comp_cnt < 4) ? tileA[comp_cnt][3] : 0;

    assign sa_b[0] = (comp_cnt < 4) ? tileB[0][comp_cnt] : 0;
    assign sa_b[1] = (comp_cnt < 4) ? tileB[1][comp_cnt] : 0;
    assign sa_b[2] = (comp_cnt < 4) ? tileB[2][comp_cnt] : 0;
    assign sa_b[3] = (comp_cnt < 4) ? tileB[3][comp_cnt] : 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            comp_cnt <= 0;
        else if (state == COMPUTE)
            comp_cnt <= (comp_cnt == 6) ? 0 : comp_cnt + 1;
        else
            comp_cnt <= 0;
    end

    // ========================================
    // STORE State: Write 4 rows to Buffer C
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            store_cnt <= 0;
            C_wr_en   <= 0;
        end else if (state == STORE) begin
            C_index <= baseC + store_cnt;
            C_wr_en <= 1;

            // Sign-extend 16-bit result to 32-bit
            C_data_in[127:96] <= {{16{sa_c[store_cnt*4+3][15]}}, sa_c[store_cnt*4+3]};
            C_data_in[95:64]  <= {{16{sa_c[store_cnt*4+2][15]}}, sa_c[store_cnt*4+2]};
            C_data_in[63:32]  <= {{16{sa_c[store_cnt*4+1][15]}}, sa_c[store_cnt*4+1]};
            C_data_in[31:0]   <= {{16{sa_c[store_cnt*4+0][15]}}, sa_c[store_cnt*4+0]};

            store_cnt <= (store_cnt == 3) ? 0 : store_cnt + 1;
        end else begin
            store_cnt <= 0;
            C_wr_en   <= 0;
        end
    end

endmodule