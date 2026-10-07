// Global buffer with clock enable.  phys_opt inserts these on high-fanout data nets (resets) too;
// modelled as a gate (no CE synchronisation: fine for data nets and for a CE that does not toggle).
module BUFGCE #(parameter CE_TYPE = "SYNC", parameter [0:0] IS_CE_INVERTED = 1'b0,
                parameter [0:0] IS_I_INVERTED = 1'b0, parameter SIM_DEVICE = "ULTRASCALE_PLUS",
                parameter STARTUP_SYNC = "FALSE")
  (output O, input CE, input I);
   assign O = (I ^ IS_I_INVERTED) & (CE ^ IS_CE_INVERTED);
endmodule
