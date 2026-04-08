package round_pkg;
    typedef enum logic [2:0] {
        IEEE_near   = 3'b000,
        IEEE_zero   = 3'b001,
        IEEE_ninf   = 3'b010,
        IEEE_pinf   = 3'b011,
        near_maxMag = 3'b100
    } round_mode;
endpackage