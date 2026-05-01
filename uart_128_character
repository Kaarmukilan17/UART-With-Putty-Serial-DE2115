// =============================================================================
// uart_display_verify.v
//
// Flow: UART RX (32 hex chars + Enter) --> 128-bit latch --> 7-seg display
//
// Usage:
//   - Open serial terminal at 9600 8N1
//   - Type exactly 32 hex characters (0-9, A-F, a-f)
//   - Press Enter ('\r')
//   - Press btn to scroll through the 4 x 32-bit segments on HEX7..HEX0
//   - status_led[1:0] shows which segment is currently displayed
// =============================================================================

// -----------------------------------------------------------------------------
// TOP
// -----------------------------------------------------------------------------

/*
module top (
    input  wire        CLOCK_50,   // 50 MHz onboard oscillator
    input  wire        UART_RXD,   // DE2-115 UART RX pin
    input  wire        reset,      // active-high reset (KEY[0] inverted, or SW)
    input  wire        btn,        // scroll button (KEY[1])

    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    output wire [6:0]  HEX6,
    output wire [6:0]  HEX7,

    output wire [1:0]  status_led  // shows current 32-bit segment index
);

    // ---- UART → 128-bit plaintext ----
    wire [127:0] plaintext;

    uart_rx_128 uart_inst (
        .clk     (CLOCK_50),
        .rx      (UART_RXD),
        .data_out(plaintext)
    );

    // ---- 128-bit → 7-seg display ----
    top_128bit_display display_inst (
        .clk       (CLOCK_50),
        .reset     (reset),
        .btn       (btn),
        .data      (plaintext),

        .seg0      (HEX0),
        .seg1      (HEX1),
        .seg2      (HEX2),
        .seg3      (HEX3),
        .seg4      (HEX4),
        .seg5      (HEX5),
        .seg6      (HEX6),
        .seg7      (HEX7),

        .status_led(status_led)
    );

endmodule


// -----------------------------------------------------------------------------
// UART_RX_128
// Receives 32 valid hex ASCII chars, latches 128-bit value on '\r'
// -----------------------------------------------------------------------------
module uart_rx_128 #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD     = 9600
)(
    input  wire        clk,
    input  wire        rx,
    output reg [127:0] data_out
);

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx
       
     u_uart_rx (
        .clk  (clk),
       
        .rx   (rx),
        .data (rx_data),
        .valid(rx_valid)
    );

    function [3:0] ascii_to_hex;
        input [7:0] c;
        begin
            if      (c >= "0" && c <= "9") ascii_to_hex = c - "0";
            else if (c >= "A" && c <= "F") ascii_to_hex = c - "A" + 4'd10;
            else if (c >= "a" && c <= "f") ascii_to_hex = c - "a" + 4'd10;
            else                           ascii_to_hex = 4'h0;
        end
    endfunction

    function is_hex;
        input [7:0] c;
        begin
            is_hex = ((c >= "0" && c <= "9") ||
                      (c >= "A" && c <= "F") ||
                      (c >= "a" && c <= "f"));
        end
    endfunction

    reg [127:0] shift_reg = 128'd0;
    reg [5:0]   hex_count = 6'd0;

    always @(posedge clk) begin
        if (rx_valid) begin

            if (is_hex(rx_data) && hex_count < 6'd32) begin
                shift_reg <= {shift_reg[123:0], ascii_to_hex(rx_data)};
                hex_count <= hex_count + 6'd1;
            end

            if (rx_data == 8'h0D) begin          // '\r' Enter
                data_out  <= shift_reg;
                shift_reg <= 128'd0;
                hex_count <= 6'd0;
            end

        end
    end

endmodule



module uart_rx (
    input wire clk,        // 50 MHz clock
    input wire rx,         // UART RX line

    output reg [7:0] data, // received byte
    output reg valid       // goes high for 1 cycle when data is ready
);

    parameter CLKS_PER_BIT = 5208; // 50e6 / 9600

    reg [12:0] clk_cnt = 0;
    reg [3:0] bit_idx = 0;
    reg [7:0] shift = 0;

    reg [1:0] state = 0;

    localparam IDLE  = 0;
    localparam START = 1;
    localparam DATA  = 2;
    localparam STOP  = 3;

    always @(posedge clk) begin
        case (state)

       
        IDLE: begin
            valid <= 0;
            clk_cnt <= 0;
            bit_idx <= 0;

            if (rx == 0)   // detect start bit
                state <= START;
        end

       
        START: begin
            if (clk_cnt == CLKS_PER_BIT/2) begin
                clk_cnt <= 0;
                state <= DATA;
            end else
                clk_cnt <= clk_cnt + 1;
        end

       
        DATA: begin
            if (clk_cnt < CLKS_PER_BIT-1)
                clk_cnt <= clk_cnt + 1;
            else begin
                clk_cnt <= 0;

                shift[bit_idx] <= rx;

                if (bit_idx < 7)
                    bit_idx <= bit_idx + 1;
                else begin
                    bit_idx <= 0;
                    state <= STOP;
                end
            end
        end

       
        STOP: begin
            if (clk_cnt < CLKS_PER_BIT-1)
                clk_cnt <= clk_cnt + 1;
            else begin
                data <= shift;
                valid <= 1;     // data ready
                state <= IDLE;
                clk_cnt <= 0;
            end
        end

        endcase
    end

endmodule


// -----------------------------------------------------------------------------
// TOP_128BIT_DISPLAY
// Scrolls 128-bit data across 8 x 7-seg displays in 32-bit chunks
// -----------------------------------------------------------------------------
module top_128bit_display (
    input  wire        clk,
    input  wire        reset,
    input  wire        btn,
    input  wire [127:0] data,

    output wire [6:0]  seg0,
    output wire [6:0]  seg1,
    output wire [6:0]  seg2,
    output wire [6:0]  seg3,
    output wire [6:0]  seg4,
    output wire [6:0]  seg5,
    output wire [6:0]  seg6,
    output wire [6:0]  seg7,

    output wire [1:0]  status_led
);

    wire        btn_clean;
    wire        btn_pulse;
    wire [1:0]  seg_sel;
    wire [31:0] seg_data;

    debounce db_inst (
        .clk    (clk),
        .btn_in (btn),
        .btn_out(btn_clean)
    );

    edge_detector edge_inst (
        .clk      (clk),
        .signal_in(btn_clean),
        .pulse_out (btn_pulse)
    );

    counter2_up counter_inst (
        .clk   (clk),
        .reset (reset),
        .enable(btn_pulse),
        .count (seg_sel)
    );

    mux4x1_32bit mux_inst (
        .in0(data[31:0]),
        .in1(data[63:32]),
        .in2(data[95:64]),
        .in3(data[127:96]),
        .sel(seg_sel),
        .out(seg_data)
    );

    eight_sevenseg_32bit display_inst (
        .data32(seg_data),
        .seg0  (seg0),
        .seg1  (seg1),
        .seg2  (seg2),
        .seg3  (seg3),
        .seg4  (seg4),
        .seg5  (seg5),
        .seg6  (seg6),
        .seg7  (seg7)
    );

    assign status_led = seg_sel;

endmodule


// -----------------------------------------------------------------------------
// DEBOUNCE — counter-based glitch filter
// -----------------------------------------------------------------------------
module debounce (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_out
);
    reg [19:0] cnt = 0;
    reg        sync = 0;

    always @(posedge clk) begin
        sync <= btn_in;

        if (sync == btn_out)
            cnt <= 0;
        else begin
            cnt <= cnt + 1;
            if (cnt == 20'hFFFFF)
                btn_out <= sync;
        end
    end
endmodule


// -----------------------------------------------------------------------------
// EDGE_DETECTOR — rising edge → single cycle pulse
// -----------------------------------------------------------------------------
module edge_detector (
    input  wire clk,
    input  wire signal_in,
    output wire pulse_out
);
    reg prev = 0;
    always @(posedge clk) prev <= signal_in;
    assign pulse_out = signal_in & ~prev;
endmodule


// -----------------------------------------------------------------------------
// COUNTER2_UP — 2-bit up counter (wraps 0→1→2→3→0)
// -----------------------------------------------------------------------------
module counter2_up (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,
    output reg  [1:0] count
);
    always @(posedge clk) begin
        if (reset)
            count <= 2'd0;
        else if (enable)
            count <= count + 2'd1;
    end
endmodule


// -----------------------------------------------------------------------------
// MUX4X1_32BIT — selects one 32-bit segment from 128-bit data
// -----------------------------------------------------------------------------
module mux4x1_32bit (
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire [31:0] in2,
    input  wire [31:0] in3,
    input  wire [1:0]  sel,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            2'd0: out = in0;
            2'd1: out = in1;
            2'd2: out = in2;
            2'd3: out = in3;
        endcase
    end
endmodule


// -----------------------------------------------------------------------------
// EIGHT_SEVENSEG_32BIT — drives 8 seven-segment displays from 32-bit word
// -----------------------------------------------------------------------------
module eight_sevenseg_32bit (
    input  wire [31:0] data32,
    output wire [6:0]  seg0,
    output wire [6:0]  seg1,
    output wire [6:0]  seg2,
    output wire [6:0]  seg3,
    output wire [6:0]  seg4,
    output wire [6:0]  seg5,
    output wire [6:0]  seg6,
    output wire [6:0]  seg7
);
    hex_to_7seg d0(.hex(data32[3:0]),   .seg(seg0));
    hex_to_7seg d1(.hex(data32[7:4]),   .seg(seg1));
    hex_to_7seg d2(.hex(data32[11:8]),  .seg(seg2));
    hex_to_7seg d3(.hex(data32[15:12]), .seg(seg3));
    hex_to_7seg d4(.hex(data32[19:16]), .seg(seg4));
    hex_to_7seg d5(.hex(data32[23:20]), .seg(seg5));
    hex_to_7seg d6(.hex(data32[27:24]), .seg(seg6));
    hex_to_7seg d7(.hex(data32[31:28]), .seg(seg7));
endmodule


// -----------------------------------------------------------------------------
// HEX_TO_7SEG — 4-bit hex nibble to 7-segment (active-low, DE2-115)
// Segment order: [6:0] = a b c d e f g
// -----------------------------------------------------------------------------
module hex_to_7seg (
    input  wire [3:0] hex,
    output reg  [6:0] seg
);
    always @(*) begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111; // blank
        endcase
    end
endmodule

*/


//with debug


// Flow: UART RX (32 hex chars + Enter) --> 128-bit latch --> 7-seg display
//
// Usage:
//   - Open serial terminal at 9600 8N1
//   - Type exactly 32 hex characters (0-9, A-F, a-f)
//   - Press Enter ('\r')
//   - Press btn to scroll through the 4 x 32-bit segments on HEX7..HEX0
//   - status_led[1:0] shows which segment is currently displayed
//
// DEBUG LEDs (DE2-115 LEDR[17:0]):
//   LEDR[7:0]   — last received raw byte (ASCII), holds until next byte
//   LEDR[8]     — blinks ~20ms on every received byte (valid strobe)
//   LEDR[9]     — 1 if last byte was a valid hex char, 0 otherwise
//   LEDR[14:10] — hex_count (how many hex chars accumulated so far, 0..31)
//   LEDR[15]    — goes HIGH once 32 hex chars received (ready to latch)
//   LEDR[16]    — blinks ~20ms when Enter received (latch triggered)
//   LEDR[17]    — raw UART_RXD line state (idle=1, actively receiving=0)
// =============================================================================

// -----------------------------------------------------------------------------
// TOP
// -----------------------------------------------------------------------------
module top (
    input  wire        CLOCK_50,
    input  wire        UART_RXD,
    input  wire        reset,
    input  wire        btn,

    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    output wire [6:0]  HEX6,
    output wire [6:0]  HEX7,

    output wire [1:0]  status_led,
    output wire [17:0] LEDR          // debug LEDs
);

    // ---- UART -> 128-bit plaintext + debug signals ----
    wire [127:0] plaintext;
    wire [7:0]   dbg_rx_data;
    wire         dbg_rx_valid;
    wire         dbg_is_hex;
    wire [5:0]   dbg_hex_count;
    wire         dbg_enter;
    wire         dbg_full;

    uart_rx_128 #(
        .CLK_FREQ(50000000),
        .BAUD    (9600)
    ) uart_inst (
        .clk          (CLOCK_50),
        .rx           (UART_RXD),
        .data_out     (plaintext),
        .dbg_rx_data  (dbg_rx_data),
        .dbg_rx_valid (dbg_rx_valid),
        .dbg_is_hex   (dbg_is_hex),
        .dbg_hex_count(dbg_hex_count),
        .dbg_enter    (dbg_enter),
        .dbg_full     (dbg_full)
    );

    // ---- Stretch single-cycle pulses to ~20ms so LEDs are visible ----
    reg [7:0]  led_byte         = 8'd0;
    reg [19:0] valid_stretch    = 20'd0;
    reg [19:0] enter_stretch    = 20'd0;

    always @(posedge CLOCK_50) begin
        // Latch last byte — holds until next byte arrives
        if (dbg_rx_valid)
            led_byte <= dbg_rx_data;

        // valid strobe stretch
        if (dbg_rx_valid)
            valid_stretch <= 20'hFFFFF;
        else if (valid_stretch != 0)
            valid_stretch <= valid_stretch - 1;

        // enter strobe stretch
        if (dbg_enter)
            enter_stretch <= 20'hFFFFF;
        else if (enter_stretch != 0)
            enter_stretch <= enter_stretch - 1;
    end

    // ---- LED wiring ----
    assign LEDR[7:0]   = led_byte;                // last ASCII byte (e.g. 'A'=0x41)
    assign LEDR[8]     = (valid_stretch != 0);    // blinks each byte
    assign LEDR[9]     = dbg_is_hex;              // 1 = valid hex char
    assign LEDR[14:10] = dbg_hex_count[4:0];      // count 0..31 in binary
    assign LEDR[15]    = dbg_full;                // high when 32 chars ready
    assign LEDR[16]    = (enter_stretch != 0);    // blinks on Enter
    assign LEDR[17]    = UART_RXD;                // raw line (sanity check)

    // ---- 128-bit -> 7-seg display ----
    top_128bit_display display_inst (
        .clk       (CLOCK_50),
        .reset     (reset),
        .btn       (btn),
        .data      (plaintext),
        .seg0      (HEX0),
        .seg1      (HEX1),
        .seg2      (HEX2),
        .seg3      (HEX3),
        .seg4      (HEX4),
        .seg5      (HEX5),
        .seg6      (HEX6),
        .seg7      (HEX7),
        .status_led(status_led)
    );

endmodule


// -----------------------------------------------------------------------------
// UART_RX_128
// Receives 32 valid hex ASCII chars, latches 128-bit value on '\r'
// Debug ports expose internal state for LED visibility
// -----------------------------------------------------------------------------
module uart_rx_128 #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD     = 9600
)(
    input  wire        clk,
    input  wire        rx,
    output reg [127:0] data_out,

    // debug ports
    output wire [7:0]  dbg_rx_data,    // raw byte from uart_rx
    output wire        dbg_rx_valid,   // 1-cycle pulse per received byte
    output reg         dbg_is_hex,     // 1 if last byte was valid hex
    output wire [5:0]  dbg_hex_count,  // chars accumulated so far
    output reg         dbg_enter,      // 1-cycle pulse when '\r' seen
    output wire        dbg_full        // 1 when hex_count == 32
);

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD    (BAUD)
    ) u_uart_rx (
        .clk  (clk),
        .rst  (1'b0),
        .rx   (rx),
        .data (rx_data),
        .valid(rx_valid)
    );

    // expose raw uart_rx outputs directly
    assign dbg_rx_data  = rx_data;
    assign dbg_rx_valid = rx_valid;

    function [3:0] ascii_to_hex;
        input [7:0] c;
        begin
            if      (c >= "0" && c <= "9") ascii_to_hex = c - "0";
            else if (c >= "A" && c <= "F") ascii_to_hex = c - "A" + 4'd10;
            else if (c >= "a" && c <= "f") ascii_to_hex = c - "a" + 4'd10;
            else                           ascii_to_hex = 4'h0;
        end
    endfunction

    function is_hex;
        input [7:0] c;
        begin
            is_hex = ((c >= "0" && c <= "9") ||
                      (c >= "A" && c <= "F") ||
                      (c >= "a" && c <= "f"));
        end
    endfunction

    reg [127:0] shift_reg = 128'd0;
    reg [5:0]   hex_count = 6'd0;

    assign dbg_hex_count = hex_count;
    assign dbg_full      = (hex_count == 6'd32);

    always @(posedge clk) begin
        dbg_enter  <= 1'b0;   // default low, pulse only on '\r'
        dbg_is_hex <= 1'b0;   // default low, high when hex char seen

        if (rx_valid) begin

            if (is_hex(rx_data) && hex_count < 6'd32) begin
                shift_reg  <= {shift_reg[123:0], ascii_to_hex(rx_data)};
                hex_count  <= hex_count + 6'd1;
                dbg_is_hex <= 1'b1;
            end

            if (rx_data == 8'h0D) begin          // '\r' Enter
                data_out   <= shift_reg;
                shift_reg  <= 128'd0;
                hex_count  <= 6'd0;
                dbg_enter  <= 1'b1;
            end

        end
    end

endmodule


// -----------------------------------------------------------------------------
// UART_RX — byte-level UART receiver
// -----------------------------------------------------------------------------
module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD     = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;

    reg [1:0]  state   = IDLE;
    reg [15:0] clk_cnt = 16'd0;
    reg [2:0]  bit_idx = 3'd0;
    reg [7:0]  shift   = 8'd0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            valid   <= 0;
        end else begin
            valid <= 0;

            case (state)
                IDLE:
                    if (rx == 1'b0) begin
                        clk_cnt <= 0;
                        state   <= START;
                    end

                START:
                    if (clk_cnt == CLKS_PER_BIT/2) begin
                        clk_cnt <= 0;
                        state   <= DATA;
                    end else
                        clk_cnt <= clk_cnt + 1;

                DATA:
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt        <= 0;
                        shift[bit_idx] <= rx;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 0;
                            state   <= STOP;
                        end else
                            bit_idx <= bit_idx + 1;
                    end else
                        clk_cnt <= clk_cnt + 1;

                STOP:
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        data    <= shift;
                        valid   <= 1;
                        clk_cnt <= 0;
                        state   <= IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1;
            endcase
        end
    end

endmodule


// -----------------------------------------------------------------------------
// TOP_128BIT_DISPLAY
// Scrolls 128-bit data across 8 x 7-seg displays in 32-bit chunks
// -----------------------------------------------------------------------------
module top_128bit_display (
    input  wire        clk,
    input  wire        reset,
    input  wire        btn,
    input  wire [127:0] data,

    output wire [6:0]  seg0,
    output wire [6:0]  seg1,
    output wire [6:0]  seg2,
    output wire [6:0]  seg3,
    output wire [6:0]  seg4,
    output wire [6:0]  seg5,
    output wire [6:0]  seg6,
    output wire [6:0]  seg7,

    output wire [1:0]  status_led
);

    wire        btn_clean;
    wire        btn_pulse;
    wire [1:0]  seg_sel;
    wire [31:0] seg_data;

    debounce db_inst (
        .clk    (clk),
        .btn_in (btn),
        .btn_out(btn_clean)
    );

    edge_detector edge_inst (
        .clk      (clk),
        .signal_in(btn_clean),
        .pulse_out (btn_pulse)
    );

    counter2_up counter_inst (
        .clk   (clk),
        .reset (reset),
        .enable(btn_pulse),
        .count (seg_sel)
    );

    mux4x1_32bit mux_inst (
        .in0(data[31:0]),
        .in1(data[63:32]),
        .in2(data[95:64]),
        .in3(data[127:96]),
        .sel(seg_sel),
        .out(seg_data)
    );

    eight_sevenseg_32bit display_inst (
        .data32(seg_data),
        .seg0  (seg0),
        .seg1  (seg1),
        .seg2  (seg2),
        .seg3  (seg3),
        .seg4  (seg4),
        .seg5  (seg5),
        .seg6  (seg6),
        .seg7  (seg7)
    );

    assign status_led = seg_sel;

endmodule


// -----------------------------------------------------------------------------
// DEBOUNCE — counter-based glitch filter
// -----------------------------------------------------------------------------
module debounce (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_out
);
    reg [19:0] cnt = 0;
    reg        sync = 0;

    always @(posedge clk) begin
        sync <= btn_in;

        if (sync == btn_out)
            cnt <= 0;
        else begin
            cnt <= cnt + 1;
            if (cnt == 20'hFFFFF)
                btn_out <= sync;
        end
    end
endmodule


// -----------------------------------------------------------------------------
// EDGE_DETECTOR — rising edge → single cycle pulse
// -----------------------------------------------------------------------------
module edge_detector (
    input  wire clk,
    input  wire signal_in,
    output wire pulse_out
);
    reg prev = 0;
    always @(posedge clk) prev <= signal_in;
    assign pulse_out = signal_in & ~prev;
endmodule


// -----------------------------------------------------------------------------
// COUNTER2_UP — 2-bit up counter (wraps 0→1→2→3→0)
// -----------------------------------------------------------------------------
module counter2_up (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,
    output reg  [1:0] count
);
    always @(posedge clk) begin
        if (reset)
            count <= 2'd0;
        else if (enable)
            count <= count + 2'd1;
    end
endmodule


// -----------------------------------------------------------------------------
// MUX4X1_32BIT — selects one 32-bit segment from 128-bit data
// -----------------------------------------------------------------------------
module mux4x1_32bit (
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire [31:0] in2,
    input  wire [31:0] in3,
    input  wire [1:0]  sel,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            2'd0: out = in0;
            2'd1: out = in1;
            2'd2: out = in2;
            2'd3: out = in3;
        endcase
    end
endmodule


// -----------------------------------------------------------------------------
// EIGHT_SEVENSEG_32BIT — drives 8 seven-segment displays from 32-bit word
// -----------------------------------------------------------------------------
module eight_sevenseg_32bit (
    input  wire [31:0] data32,
    output wire [6:0]  seg0,
    output wire [6:0]  seg1,
    output wire [6:0]  seg2,
    output wire [6:0]  seg3,
    output wire [6:0]  seg4,
    output wire [6:0]  seg5,
    output wire [6:0]  seg6,
    output wire [6:0]  seg7
);
    hex_to_7seg d0(.hex(data32[3:0]),   .seg(seg0));
    hex_to_7seg d1(.hex(data32[7:4]),   .seg(seg1));
    hex_to_7seg d2(.hex(data32[11:8]),  .seg(seg2));
    hex_to_7seg d3(.hex(data32[15:12]), .seg(seg3));
    hex_to_7seg d4(.hex(data32[19:16]), .seg(seg4));
    hex_to_7seg d5(.hex(data32[23:20]), .seg(seg5));
    hex_to_7seg d6(.hex(data32[27:24]), .seg(seg6));
    hex_to_7seg d7(.hex(data32[31:28]), .seg(seg7));
endmodule


// -----------------------------------------------------------------------------
// HEX_TO_7SEG — 4-bit hex nibble to 7-segment (active-low, DE2-115)
// Segment order: [6:0] = a b c d e f g
// -----------------------------------------------------------------------------
module hex_to_7seg (
    input  wire [3:0] hex,
    output reg  [6:0] seg
);
    always @(*) begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111; // blank
        endcase
    end
endmodule
