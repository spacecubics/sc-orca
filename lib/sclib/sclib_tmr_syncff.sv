//-----------------------------------------------------------------------------
// Copyright 2026 Space Cubics Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
