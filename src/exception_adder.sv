module exception_adder import round_pkg::*; (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  round_mode round,
    input  logic overflow,
    input  logic underflow,
    input  logic inexact_bit,
    input  logic [31:0] z_calc,

    output logic [31:0] result,
    output logic zero_f,
    output logic inf_f,
    output logic nan_f,
    output logic tiny_f,
    output logic huge_f,
    output logic inexact_f
);
    typedef enum logic [2:0] {
        ZERO,
        INF,
        NORM,
        MIN_NORM,
        MAX_NORM
    } interp_t;

    function interp_t num_interp(input logic [31:0] val);
        logic [7:0] exp;
        exp = val[30:23];
        if (exp == 8'hFF)
            return INF;
        else if (exp == 8'h00)
            return ZERO;
        else
            return NORM;
    endfunction

    function logic [30:0] z_num(input interp_t interp);
        case (interp)
            ZERO:     return 31'h00000000;
            INF:      return 31'h7F800000;
            MIN_NORM: return 31'h00800000;
            MAX_NORM: return 31'h7F7FFFFF;
            default:  return 31'h00000000;
        endcase
    endfunction

    always_comb begin
        result = z_calc;
        zero_f = 1'b0;
        inf_f = 1'b0;
        nan_f = 1'b0;
        tiny_f = 1'b0;
        huge_f = 1'b0;
        inexact_f = 1'b0;

        case ({num_interp(a), num_interp(b)})
            {ZERO, ZERO}: begin
                logic sign_z;
                if (a[31] == b[31]) begin
                    sign_z = a[31];
                end else begin
                    sign_z = (round_mode'(round) == IEEE_ninf) ? 1'b1 : 1'b0;
                end
                result = {sign_z, z_num(ZERO)};
                zero_f = 1'b1;
            end
            
            {ZERO, INF}: begin
                result = {b[31], z_num(INF)};
                inf_f = 1'b1;
            end
            
            {INF, ZERO}: begin
                result = {a[31], z_num(INF)};
                inf_f = 1'b1;
            end
            
            {ZERO, NORM}: begin
                result = b;
            end
            
            {NORM, ZERO}: begin
                result = a;
            end
            
            {INF, INF}: begin
                if (a[31] != b[31]) begin
                    // +INF + -INF -> NaN, but compliance-0 treats NaN as +INF
                    result = {1'b0, z_num(INF)};
                    nan_f = 1'b1;   // invalid operation flag stays set
                end else begin
                    result = {a[31], z_num(INF)};
                    inf_f = 1'b1;
                end
            end
            
            {INF, NORM}: begin
                result = {a[31], z_num(INF)};
                inf_f = 1'b1;
            end
            
            {NORM, INF}: begin
                result = {b[31], z_num(INF)};
                inf_f = 1'b1;
            end
            
            {NORM, NORM}: begin
                if (overflow) begin
                    huge_f = 1'b1;
                    inexact_f = 1'b1;
                    case (round_mode'(round))
                        IEEE_near, near_maxMag: begin 
                            result = {z_calc[31], z_num(INF)}; 
                            inf_f = 1'b1; 
                        end
                        IEEE_zero: begin 
                            result = {z_calc[31], z_num(MAX_NORM)}; 
                        end
                        IEEE_pinf: begin
                            if (z_calc[31] == 1'b0) begin 
                                result = {z_calc[31], z_num(INF)}; 
                                inf_f = 1'b1; 
                            end else begin 
                                result = {z_calc[31], z_num(MAX_NORM)}; 
                            end
                        end
                        IEEE_ninf: begin
                            if (z_calc[31] == 1'b1) begin 
                                result = {z_calc[31], z_num(INF)}; 
                                inf_f = 1'b1; 
                            end else begin 
                                result = {z_calc[31], z_num(MAX_NORM)}; 
                            end
                        end
                        default: begin 
                            result = {z_calc[31], z_num(INF)}; 
                            inf_f = 1'b1; 
                        end
                    endcase
                end else if (underflow) begin
                    tiny_f = 1'b1;
                    inexact_f = 1'b1;
                    case (round_mode'(round))
                        IEEE_near, near_maxMag, IEEE_zero: begin 
                            result = {z_calc[31], z_num(ZERO)}; 
                            zero_f = 1'b1; 
                        end
                        IEEE_pinf: begin
                            if (z_calc[31] == 1'b0) begin 
                                result = {z_calc[31], z_num(MIN_NORM)}; 
                            end else begin 
                                result = {z_calc[31], z_num(ZERO)}; 
                                zero_f = 1'b1; 
                            end
                        end
                        IEEE_ninf: begin
                            if (z_calc[31] == 1'b1) begin 
                                result = {z_calc[31], z_num(MIN_NORM)}; 
                            end else begin 
                                result = {z_calc[31], z_num(ZERO)}; 
                                zero_f = 1'b1; 
                            end
                        end
                        default: begin 
                            result = {z_calc[31], z_num(ZERO)}; 
                            zero_f = 1'b1; 
                        end
                    endcase
                end else begin
                    // Valid normal calculation without exceptions
                    result = z_calc;
                    inexact_f = inexact_bit;
                    // Check for exact zero cancellation
                    if (z_calc[30:0] == 31'd0) begin
                        zero_f = 1'b1;
                    end
                end
            end
            
            default: begin
                result = z_calc;
            end
        endcase
    end

endmodule