module uart_hex_display_top (

    input  wire CLOCK_50,     // 50 MHz clock
    input  wire UART_RXD,     // UART RX

    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3

);

    // ---------------- UART RX ----------------
    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx #(
        .CLK_FREQ(50000000),
        .BAUD(9600)
    ) uart_inst (
        .clk(CLOCK_50),
        .rst(1'b0),
        .rx(UART_RXD),
        .data(rx_data),
        .valid(rx_valid)
    );

    // ---------------- HEX BUFFER ----------------
    reg [15:0] shift_reg = 0;
    reg [15:0] hex_out   = 0;

    // ASCII â HEX
    function [3:0] ascii_to_hex;
        input [7:0] char;
        begin
            if (char >= "0" && char <= "9")
                ascii_to_hex = char - "0";
            else if (char >= "A" && char <= "F")
                ascii_to_hex = char - "A" + 10;
            else if (char >= "a" && char <= "f")
                ascii_to_hex = char - "a" + 10;
            else
                ascii_to_hex = 4'h0;
        end
    endfunction

    // Check if valid hex char
    function is_hex;
        input [7:0] char;
        begin
            is_hex = ((char >= "0" && char <= "9") ||
                      (char >= "A" && char <= "F") ||
                      (char >= "a" && char <= "f"));
        end
    endfunction

    // ENTER detection
    wire is_enter = (rx_data == 8'h0D); // '\r'

    always @(posedge CLOCK_50) begin
        if (rx_valid) begin

            // Shift last 4 hex digits
            if (is_hex(rx_data)) begin
                shift_reg <= {shift_reg[11:0], ascii_to_hex(rx_data)};
            end

            // On ENTER â latch value
            if (is_enter) begin
                hex_out <= shift_reg;
            end
        end
    end

    // ---------------- 7-SEG DECODER ----------------
    function [6:0] hex_to_7seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_7seg = 7'b1000000;
                4'h1: hex_to_7seg = 7'b1111001;
                4'h2: hex_to_7seg = 7'b0100100;
                4'h3: hex_to_7seg = 7'b0110000;
                4'h4: hex_to_7seg = 7'b0011001;
                4'h5: hex_to_7seg = 7'b0010010;
                4'h6: hex_to_7seg = 7'b0000010;
                4'h7: hex_to_7seg = 7'b1111000;
                4'h8: hex_to_7seg = 7'b0000000;
                4'h9: hex_to_7seg = 7'b0010000;
                4'hA: hex_to_7seg = 7'b0001000;
                4'hB: hex_to_7seg = 7'b0000011;
                4'hC: hex_to_7seg = 7'b1000110;
                4'hD: hex_to_7seg = 7'b0100001;
                4'hE: hex_to_7seg = 7'b0000110;
                4'hF: hex_to_7seg = 7'b0001110;
            endcase
        end
    endfunction

    assign HEX0 = hex_to_7seg(hex_out[3:0]);
    assign HEX1 = hex_to_7seg(hex_out[7:4]);
    assign HEX2 = hex_to_7seg(hex_out[11:8]);
    assign HEX3 = hex_to_7seg(hex_out[15:12]);

endmodule



module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD     = 9600
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,

    output reg  [7:0] data,
    output reg  valid
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

    localparam IDLE=0, START=1, DATA=2, STOP=3;

    reg [1:0] state = IDLE;
    reg [15:0] clk_cnt = 0;
    reg [2:0] bit_idx = 0;
    reg [7:0] shift = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            valid <= 0;
        end else begin
            valid <= 0;

            case (state)
            IDLE:
                if (rx == 0) begin
                    clk_cnt <= 0;
                    state <= START;
                end

            START:
                if (clk_cnt == CLKS_PER_BIT/2) begin
                    clk_cnt <= 0;
                    state <= DATA;
                end else
                    clk_cnt <= clk_cnt + 1;

            DATA:
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    shift[bit_idx] <= rx;

                    if (bit_idx == 7) begin
                        bit_idx <= 0;
                        state <= STOP;
                    end else
                        bit_idx <= bit_idx + 1;
                end else
                    clk_cnt <= clk_cnt + 1;

            STOP:
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    data <= shift;
                    valid <= 1;
                    clk_cnt <= 0;
                    state <= IDLE;
                end else
                    clk_cnt <= clk_cnt + 1;
            endcase
        end
    end

endmodule