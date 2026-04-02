module top (
    input  wire CLOCK_50,     // 50 MHz clock (DE2-115)
    input  wire UART_RXD,     // UART RX from USB
    output reg  [7:0] LEDR    // LEDs
);

    wire [7:0] data;
    wire valid;

    uart_rx_minimal uut (
        .clk(CLOCK_50),
        .rx(UART_RXD),
        .data(data),
        .valid(valid)
    );

    always @(posedge CLOCK_50) begin
        if (valid)
            LEDR <= data;
    end

endmodule


