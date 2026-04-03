//PRINTS CHAR ENTERED IN TERMINAL IN FIRST ROW FIRST POSITION OF LCD

module top (
    input  wire       CLOCK_50,
    input  wire       UART_RXD,
    output reg  [7:0] LEDR,

    output reg        LCD_RS,
    output reg        LCD_EN,
    output wire       LCD_RW,
    output reg  [7:0] LCD_DATA,
    output wire       LCD_ON,
    output wire       LCD_BLON
);

    assign LCD_RW   = 0;
    assign LCD_ON   = 1;
    assign LCD_BLON = 1;

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx_minimal u_rx (
        .clk  (CLOCK_50),
        .rx   (UART_RXD),
        .data (rx_data),
        .valid(rx_valid)
    );

    
    localparam
        S_PWRON   = 4'd0,
        S_INIT1   = 4'd1,
        S_INIT2   = 4'd2,
        S_INIT3   = 4'd3,
        S_CLRWAIT = 4'd4,
        S_INIT4   = 4'd5,
        S_IDLE    = 4'd6,
        S_HOME    = 4'd7,
        S_WRCHAR  = 4'd8,
        S_WRWAIT  = 4'd9;

    reg [3:0]  state;
    reg [19:0] cnt;
    reg [7:0]  curr;
    reg [5:0]  en_cnt;

    always @(posedge CLOCK_50) begin

        if (en_cnt != 0) begin
            en_cnt <= en_cnt - 1;
            LCD_EN <= (en_cnt > 20) ? 1 : 0;
        end

        case (state)

            S_PWRON: begin
                LCD_RS   <= 0;
                LCD_EN   <= 0;
                LCD_DATA <= 0;
                if (cnt == 0) begin
                    cnt   <= 750_000;
                    state <= S_INIT1;
                end else
                    cnt <= cnt - 1;
            end

            S_INIT1: begin
                if (cnt == 0) begin
                    LCD_RS   <= 0;
                    LCD_DATA <= 8'h38;
                    en_cnt   <= 6'd50;
                    cnt      <= 3_000;
                    state    <= S_INIT2;
                end else
                    cnt <= cnt - 1;
            end

            S_INIT2: begin
                if (cnt == 0) begin
                    LCD_RS   <= 0;
                    LCD_DATA <= 8'h0C;
                    en_cnt   <= 6'd50;
                    cnt      <= 3_000;
                    state    <= S_INIT3;
                end else
                    cnt <= cnt - 1;
            end

            S_INIT3: begin
                if (cnt == 0) begin
                    LCD_RS   <= 0;
                    LCD_DATA <= 8'h01;
                    en_cnt   <= 6'd50;
                    cnt      <= 100_000;
                    state    <= S_CLRWAIT;
                end else
                    cnt <= cnt - 1;
            end

            S_CLRWAIT: begin
                if (cnt == 0) state <= S_INIT4;
                else          cnt   <= cnt - 1;
            end

            S_INIT4: begin
                LCD_RS   <= 0;
                LCD_DATA <= 8'h06;
                en_cnt   <= 6'd50;
                cnt      <= 3_000;
                state    <= S_IDLE;
            end

            // --- Wait for byte ---
            S_IDLE: begin
                if (cnt == 0) begin
                    if (rx_valid) begin
                        curr  <= rx_data;
                        LEDR  <= rx_data;
                        state <= S_HOME;
                    end
                end else
                    cnt <= cnt - 1;
            end

            // --- Cursor to row 0, col 0 ---
            S_HOME: begin
                LCD_RS   <= 0;
                LCD_DATA <= 8'h80;
                en_cnt   <= 6'd50;
                cnt      <= 3_000;
                state    <= S_WRCHAR;
            end

    
            S_WRCHAR: begin
                if (cnt == 0) begin
                    LCD_RS   <= 1;
                    LCD_DATA <= curr;   // send raw ASCII directly
                    en_cnt   <= 6'd50;
                    cnt      <= 3_000;
                    state    <= S_WRWAIT;
                end else
                    cnt <= cnt - 1;
            end

            S_WRWAIT: begin
                if (cnt == 0) state <= S_IDLE;
                else          cnt   <= cnt - 1;
            end

            default: state <= S_PWRON;
        endcase
    end

endmodule


module uart_rx_minimal (
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    parameter CLKS_PER_BIT = 5208;

    reg [12:0] clk_cnt = 0;
    reg  [3:0] bit_idx = 0;
    reg  [7:0] shift   = 0;
    reg  [1:0] state   = 0;

    localparam IDLE  = 0, START = 1, DATA = 2, STOP = 3;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                valid   <= 0;
                clk_cnt <= 0;
                bit_idx <= 0;
                if (rx == 0) state <= START;
            end
            START: begin
                if (clk_cnt == CLKS_PER_BIT/2) begin
                    clk_cnt <= 0;
                    state   <= DATA;
                end else
                    clk_cnt <= clk_cnt + 1;
            end
            DATA: begin
                if (clk_cnt < CLKS_PER_BIT - 1)
                    clk_cnt <= clk_cnt + 1;
                else begin
                    clk_cnt        <= 0;
                    shift[bit_idx] <= rx;
                    if (bit_idx < 7)
                        bit_idx <= bit_idx + 1;
                    else begin
                        bit_idx <= 0;
                        state   <= STOP;
                    end
                end
            end
            STOP: begin
                if (clk_cnt < CLKS_PER_BIT - 1)
                    clk_cnt <= clk_cnt + 1;
                else begin
                    data    <= shift;
                    valid   <= 1;
                    state   <= IDLE;
                    clk_cnt <= 0;
                end
            end
        endcase
    end

endmodule