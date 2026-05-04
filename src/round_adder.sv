module round_adder import round_pkg::*; (
    input logic [2:0] round,            // Rounding mode
    input logic [26:0] norm_mant,       // Normalized mantissa with GRS bits
    input logic z_sign,                 // Zero sign (1 if the result is zero and should be negative, 0 otherwise)

    output logic [24:0] rounded_mant,   // Rounded mantissa with leading 1 and overflow bit
    output logic inexact_bit            // Inexact bit (1 if rounding caused a loss of precision, 0 otherwise)
);
    logic [23:0] mant_unrounded;
    logic g, r, s;
    logic round_up;
    logic tie;

    assign mant_unrounded = {norm_mant[26], norm_mant[25:3]};
    assign g = norm_mant[2];
    assign r = norm_mant[1];
    assign s = norm_mant[0];
    
    assign tie = (g == 1'b1 && r == 1'b0 && s == 1'b0);
    assign inexact_bit = g | r | s;

    always_comb begin
        round_up = 1'b0;
        case (round_mode'(round))
            IEEE_near: begin
                if (g && (r || s || mant_unrounded[0]))
                    round_up = 1'b1;
            end
            IEEE_zero: begin
                round_up = 1'b0;
            end
            IEEE_ninf: begin
                if (z_sign && inexact_bit)
                    round_up = 1'b1;
            end
            IEEE_pinf: begin
                if (!z_sign && inexact_bit)
                    round_up = 1'b1;
            end
            near_maxMag: begin
                if (g)
                    round_up = 1'b1;
            end
            default: round_up = 1'b0;
        endcase
    end

    assign rounded_mant = {1'b0, mant_unrounded} + round_up;

endmodule