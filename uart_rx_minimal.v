



module uart_rx_minimal (
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
