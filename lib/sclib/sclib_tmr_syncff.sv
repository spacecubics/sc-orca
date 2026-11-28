//-----------------------------------------------------------------------------
// SPDX-License-Identifier: CERN-OHL-W-2.0
// Copyright 2026 Space Cubics Inc.
//
// This source is licensed under CERN-OHL-W-2.0.
// This Covered Source is provided "as is"; any express or implied
// warranties are disclaimed to the maximum extent permitted by law.
//-----------------------------------------------------------------------------
// Space Cubics Open-Source Resilient Component Architecture
//  Triple modular redundancy synchronizer flip-flop
//  Module: sclib_tmr_syncff
//-----------------------------------------------------------------------------

module sclib_tmr_syncff # (
  parameter int unsigned SYNC_STAGES = 2,  // Number of synchronizer stages. Must be 2 or more.
  parameter logic RESET_VALUE = 1'b0       // Reset value of synchronizer flip-flops
) (
  input  logic CLK,
  input  logic RSTB,
  input  logic DIN,
  output logic QOUT                        // QOUT must be sampled by the synchronized clock domain.
) /* synthesis syn_radhardlevel="none" */;

localparam int unsigned TMR_REPLICAS = 3;

(* dont_touch = "yes", async_reg = "true" *)
logic [TMR_REPLICAS-1:0][SYNC_STAGES-1:0] sync /* synthesis syn_preserve = 1 */;

// synthesis translate_off
initial begin
  assert (SYNC_STAGES >= 2)
    else $fatal(1, "SYNC_STAGES must be 2 or greater.");
end
// synthesis translate_on

always_ff @(posedge CLK) begin
  if (!RSTB) begin
    sync <= {TMR_REPLICAS{{SYNC_STAGES{RESET_VALUE}}}};
  end
  else begin
    for (int unsigned i = 0; i < TMR_REPLICAS; i++) begin
      sync[i] <= {sync[i][SYNC_STAGES-2:0], DIN};
    end
  end
end

always_comb begin
  QOUT = (sync[0][SYNC_STAGES-1] & sync[1][SYNC_STAGES-1]) |
         (sync[1][SYNC_STAGES-1] & sync[2][SYNC_STAGES-1]) |
         (sync[2][SYNC_STAGES-1] & sync[0][SYNC_STAGES-1]);
end

endmodule
