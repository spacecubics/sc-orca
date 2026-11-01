//-----------------------------------------------------------------------------
// Copyright 2022-2025 Space Cubics, LLC.
// Copyright 2025-2026 Space Cubics Inc.
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
//  AMBA 3 AHB-Lite to Space Cubics Register Bus (SCRB) Bridge
//  Module: AMBA 3 AHB-Lite Subordinate (sc_ahbip_subordinate)
//-----------------------------------------------------------------------------

module sc_ahbip_subordinate # (
  parameter bit CYCLE_MODE = 1'b0
) (
  // AHB Interface
  input HCLK,
  input HRESETN,
  input HSEL,
  input [31:0] HADDR,
  input [1:0] HTRANS,
  input [2:0] HSIZE,
  input [2:0] HBURST,
  input [3:0] HPROT,
  input HMASTLOCK,
  input HWRITE,
  input HREADYIN,
  output logic HREADYOUT,
  input [31:0] HWDATA,
  output logic [31:0] HRDATA,
  output logic [1:0] HRESP,

  // Register Interface
  output logic [31:0] REG_WADR,
  output logic [9:0] REG_WTYP,
  output logic [3:0] REG_WENB,
  output logic [31:0] REG_WDAT,
  input REG_WWAT,
  input REG_WERR,

  output logic [31:0] REG_RADR,
  output logic [9:0] REG_RTYP,
  output logic REG_RENB,
  input [31:0] REG_RDAT,
  input REG_RWAT,
  input REG_RERR
);

// AHB Control
// ------------------------------
logic creq;
logic latch_dvalid;
logic latch_wvalid;
logic latch_rvalid;
logic [31:0] latch_addr;
logic [2:0] latch_size;
logic [9:0] latch_btype;
logic [31:0] latch_wdata;
logic [1:0] burst_type;
logic [7:0] burst_count;
logic burst_indefinite;

logic [9:0] initial_btype;
logic [9:0] request_btype;

assign creq = HSEL & HREADYIN & HREADYOUT & HTRANS[1];
assign initial_btype = btype(HBURST);
assign request_btype = (HTRANS == 2'b10)  ? initial_btype:
                        burst_indefinite  ? {burst_type, 8'h00}:
                       (burst_count == 0) ? 10'b00_00000000:
                                            {burst_type, burst_count};

always_ff @ (posedge HCLK) begin
  if (!HRESETN) begin
    latch_addr <= 32'h0000_0000;
    latch_wvalid <= 1'b0;
    latch_rvalid <= 1'b0;
    latch_size <= 3'b000;
    latch_btype <= 10'b00_00000000;
    burst_type <= 2'b00;
    burst_count <= 8'h00;
    burst_indefinite <= 1'b0;
  end
  else begin
    if ((REG_RENB & !REG_RWAT) | (|REG_WENB & !REG_WWAT)) begin
      latch_wvalid <= 1'b0;
      latch_rvalid <= 1'b0;
    end
    if (creq) begin
      latch_addr <= HADDR;
      latch_size <= HSIZE;
      latch_btype <= request_btype;
      if (HTRANS == 2'b10) begin
        burst_type <= initial_btype[9:8];
        burst_indefinite <= (HBURST == 3'b001);
        if ((HBURST == 3'b001) | (initial_btype[7:0] == 0))
          burst_count <= 8'h00;
        else
          burst_count <= initial_btype[7:0] - 1'b1;
      end
      else if (!burst_indefinite & (burst_count != 0))
        burst_count <= burst_count - 1'b1;

      if (HWRITE)
        latch_wvalid <= 1'b1;
      else
        latch_rvalid <= 1'b1;
    end
  end
end

always_ff @ (posedge HCLK) begin
  if (!HRESETN) begin
    latch_wdata <= 32'h0000_0000;
    latch_dvalid <= 1'b0;
  end
  else if (|REG_WENB & !REG_WWAT)
    latch_dvalid <= 1'b0;
  else if (latch_wvalid) begin
    latch_wdata <= HWDATA;
    latch_dvalid <= 1'b1;
  end
end

// Write Channel
// ------------------------------
logic wbyte;
logic whalf;
logic wword;
logic [3:0] wen;
assign wbyte = (latch_size == 3'b000);
assign whalf = (latch_size == 3'b001);
assign wword = latch_size[1];
assign wen[0] = wbyte &  (latch_addr[1:0] == 2'b00)
              | whalf & ~|latch_addr[1:0]
              | wword;
assign wen[1] = wbyte &  (latch_addr[1:0] == 2'b01)
              | whalf &  ~latch_addr[1]
              | wword;
assign wen[2] = wbyte &  (latch_addr[1:0] == 2'b10)
              | whalf &  (latch_addr[1] ^ latch_addr[0])
              | wword;
assign wen[3] = wbyte &  (latch_addr[1:0] == 2'b11)
              | whalf &   latch_addr[1]
              | wword;

always_comb begin
  REG_WADR = latch_addr;
  REG_WTYP = latch_btype;
  REG_WENB = 4'h0;
  REG_WDAT = 32'h0000_0000;
  if (CYCLE_MODE == 0) begin
    if (latch_wvalid) begin
      REG_WENB = wen;
      REG_WDAT = HWDATA;
    end
  end
  else begin
    REG_WDAT = latch_wdata;
    if (latch_dvalid)
      REG_WENB = wen;
  end
end

// Read Channel
// ------------------------------
logic rcycle;
always_ff @ (posedge HCLK) begin
  if (!HRESETN)
    rcycle <= 1'b0;
  else begin
    if (rcycle & !REG_RWAT)
      rcycle <= 1'b0;

    if (REG_RENB)
      rcycle <= 1'b1;
  end
end

logic wrrace;
logic rwrace_recovery;
assign wrrace = CYCLE_MODE == 0 & |REG_WENB & creq & !HWRITE;
always_ff @ (posedge HCLK) begin
  if (!HRESETN)
      rwrace_recovery <= 1'b0;
  else
      rwrace_recovery <= wrrace;
end

always_comb begin
  REG_RADR = latch_addr;
  REG_RTYP = latch_btype;
  REG_RENB = 1'b0;
  if (CYCLE_MODE | rwrace_recovery)
    REG_RENB = latch_rvalid;
  else if (CYCLE_MODE == 0 & !wrrace) begin
    REG_RADR = HADDR;
    REG_RTYP = request_btype;
    REG_RENB = creq & !HWRITE;
  end

  if (rcycle)
    HRDATA = REG_RDAT;
  else
    HRDATA = 32'h00000000;
end

// HREADY Control
// ------------------------------
assign HREADYOUT = ~(|REG_WENB & (REG_WWAT | REG_WERR)) &
                   ~(rcycle & (REG_RWAT | REG_RERR)) &
                   ~(CYCLE_MODE & latch_rvalid & REG_RENB) &
                   ~(rwrace_recovery & latch_rvalid & REG_RENB) &
                   ~(CYCLE_MODE & latch_wvalid & !(|REG_WENB));

// HRESP Control
// ------------------------------
logic reg_werror;
logic reg_rerror;
logic reg_error;
logic next_hresp;
assign reg_werror = (|REG_WENB) & REG_WERR;
assign reg_rerror = rcycle & REG_RERR;
assign reg_error = reg_werror | reg_rerror;
always_ff @ (posedge HCLK) begin
  if (!HRESETN)
    next_hresp <= 1'b0;
  else if (HREADYOUT & HRESP[0])
    next_hresp <= 1'b0;
  else if (reg_error)
    next_hresp <= 1'b1;
end
assign HRESP = {1'b0, reg_error | next_hresp};

// synthesis translate_off
assert property (@(posedge HCLK) disable iff (!HRESETN)
  (|REG_WENB) |-> !(REG_WWAT && REG_WERR)
) else $error("REG_WWAT and REG_WERR asserted together during a write");

assert property (@(posedge HCLK) disable iff (!HRESETN)
  rcycle |-> !(REG_RWAT && REG_RERR)
) else $error("REG_RWAT and REG_RERR asserted together during a read");
// synthesis translate_on

function [9:0] btype (
  input [2:0] burst
);
begin
  case (burst)
    3'b000: btype = 10'b00_00000000; // SINGLE
    3'b001: btype = 10'b01_00000000; // INCR
    3'b010: btype = 10'b10_00000011; // WRAP4
    3'b011: btype = 10'b01_00000011; // INCR4
    3'b100: btype = 10'b10_00000111; // WRAP8
    3'b101: btype = 10'b01_00000111; // INCR8
    3'b110: btype = 10'b10_00001111; // WRAP16
    3'b111: btype = 10'b01_00001111; // INCR16
  endcase
end
endfunction

endmodule
