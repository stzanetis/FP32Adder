module mantissa_calc (
    input logic [8:0] exp_diff,          // Exponent difference
    input logic [23:0] mant_a, mant_b,   // Mantissas of the two floating point numbers
    input logic sign_exp_diff,           // Sign of the exponent difference
    input logic sa, sb,                  // Signs of the two floating point numbers

    output logic [27:0] result_mant      // Resulting mantissa after alignment and addition
);
    logic [8:0] d;
    assign d = exp_diff;

    logic [23:0] mant_larger;
    logic [23:0] mant_smaller;
    
    always_comb begin
        if (sign_exp_diff) begin
            mant_larger = mant_a;
            mant_smaller = mant_b;
        end else begin
            mant_larger = mant_b;
            mant_smaller = mant_a;
        end
    end

    // The intermediate signal of 49-bits
    logic [48:0] shift_in;
    logic [48:0] shifted_val;
    assign shift_in = {mant_smaller, 25'b0};
    assign shifted_val = shift_in >> d;

    // GRS bits extraction
    logic guard, round, sticky;
    assign guard = shifted_val[24];
    assign round = shifted_val[23];
    assign sticky = (|shifted_val[22:0]) | (d > 9'd48);

    // 27-bit aligned mantissas
    logic [26:0] aligned_smaller;
    logic [26:0] aligned_larger;
    
    assign aligned_smaller = {shifted_val[48:25], guard, round, sticky};
    assign aligned_larger  = {mant_larger, 3'b000};

    // Subtraction or addition of aligned mantissas
    always_comb begin
        if (sa == sb) begin
            result_mant = {1'b0, aligned_larger} + {1'b0, aligned_smaller};
        end else begin
            if (aligned_larger >= aligned_smaller) begin
                result_mant = {1'b0, aligned_larger} - {1'b0, aligned_smaller};
            end else begin
                result_mant = {1'b0, aligned_smaller} - {1'b0, aligned_larger};
            end
        end
    end

endmodule