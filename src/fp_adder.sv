module fp_adder (
    input logic [31:0] a, b,    // Floating point inputs
    input logic [2:0] round,    // Rounding mode

    output logic [31:0] result, // Floating point result
    output logic [7:0] status   // Status flags
);

// Floating point number sign calculation stage
logic sign;
assign sign = (a[31] == b[31]) ? a[31] : ((a[30:0] > b[30:0]) ? a[31] : b[31]);

endmodule