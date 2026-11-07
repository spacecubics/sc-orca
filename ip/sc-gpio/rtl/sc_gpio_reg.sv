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
//  General-purpose input/output
//  Module: GPIO Register (sc_gpio_reg)
//-----------------------------------------------------------------------------

module sc_gpio_reg
  import screg_pkg::*;
# (
  parameter NUM_PORTS = 1,
  parameter [31:0] TMR_PORTS = 32'h0000_0000
) (
  // System Interface
  input SYS_CLK,
  input SYS_RST_B,
  output GPIO_IRQ,

  // Register Interface
  input [31:0] REG_WADR,
  input [9:0] REG_WTYP,
  input [3:0] REG_WENB,
  input [31:0] REG_WDAT,
  output logic REG_WWAT,
  output logic REG_WERR,

  input [31:0] REG_RADR,
  input [9:0] REG_RTYP,
  input REG_RENB,
  output logic [31:0] REG_RDAT,
  output logic REG_RWAT,
  output logic REG_RERR,

  // GPIO Parameter Interface
  // Per-port static configuration (constant wiring expected)
  input [31:0] GPIO_BITS_PRESENT [NUM_PORTS],
  input [31:0] GPIO_DIR_WRITABLE [NUM_PORTS],
  input [31:0] GPIO_DIR_INIT [NUM_PORTS],
  input [31:0] GPIO_OUT_INIT [NUM_PORTS],

  // GPIO Interface
  input [31:0] GPIO_I [NUM_PORTS],
  output logic [31:0] GPIO_O [NUM_PORTS],
  output logic [31:0] GPIO_E [NUM_PORTS] // 1: output enabled, 0: input/High-Z
);

// Declaration of base variable for register framework
//------------------------------------------------------
`include "sc_gpio_version.svh"
`include "sc_gpio_reg_desc.svh"

sc_regbus_t bus;
always_comb begin
  bus.wadr = REG_WADR;
  bus.wtyp = REG_WTYP;
  bus.wenb = REG_WENB;
  bus.wdat = REG_WDAT;
  REG_WWAT = bus.wwat;
  REG_WERR = bus.werr;
  bus.radr = REG_RADR;
  bus.rtyp = REG_RTYP;
  bus.renb = REG_RENB;
  REG_RDAT = bus.rdat;
  REG_RWAT = bus.rwat;
  REG_RERR = bus.rerr;
end
assign bus.wwat = 1'b0;
assign bus.werr = 1'b0;
assign bus.rwat = 1'b0;
assign bus.rerr = 1'b0;


logic reg_rst_b;

// IP Version/Configuration Register
//--------------------------------------------
IPVER_s IPVER;
IPCONF_s IPCONF;

always_comb begin
  IPVER  = reg_reset(reg_table[get_idx(IPVER_desc, 0)]);
  IPCONF = reg_reset(reg_table[get_idx(IPCONF_desc, 0)]);
end


// Reset Control Register
//--------------------------------------------
(* dont_touch = "yes" *) RSTCTRL_s [2:0] RSTCTRL /* synthesis syn_preserve = 1 */;

always_ff @ (posedge SYS_CLK) begin
  if (!SYS_RST_B)
    RSTCTRL <= reg_reset_tmr(reg_table[get_idx(RSTCTRL_desc, 0)]);
  else
    RSTCTRL <= reg_write_tmr(reg_table[get_idx(RSTCTRL_desc, 0)], bus);
end
RSTCTRL_s rstctrl_data;
assign rstctrl_data = reg_mvote(RSTCTRL);
assign reg_rst_b = ~rstctrl_data.ip_reset;


// Scratch Pad Register
//--------------------------------------------
SCRPAD_s SCRPAD;

always_ff @ (posedge SYS_CLK) begin
  if (!reg_rst_b)
    SCRPAD <= reg_reset(reg_table[get_idx(SCRPAD_desc, 0)]);
  else
    SCRPAD <= reg_write(reg_table[get_idx(SCRPAD_desc, 0)], bus);
end


// Interrupt Status/Enable Register
//--------------------------------------------
GPORT_s INTSTATS;
GPORT_s INTENB;
GBIT_s EPENDING [NUM_PORTS];
GBIT_s PINTENB [NUM_PORTS];

always_ff @ (posedge SYS_CLK) begin
  if (!reg_rst_b)
    INTENB <= reg_reset(reg_table[get_idx(INTENB_desc, 0)]);
  else
    INTENB <= reg_write(reg_table[get_idx(INTENB_desc, 0)], bus);
end

always_comb begin
  INTSTATS = 0;
  for (int i=0; i<NUM_PORTS; i++) begin
    INTSTATS[i] = |(PINTENB[i] & EPENDING[i]);
  end
end
assign GPIO_IRQ = |(INTSTATS & INTENB);


// GPIO Port Register (Direction/Out/In/Bit Present)
//--------------------------------------------
GBIT_s GPIOOUT [NUM_PORTS];
GBIT_s GPIOIN [NUM_PORTS];
GBIT_s GPIODIR [NUM_PORTS];
GBIT_s GPIOBPR [NUM_PORTS];

logic [31:0] gpio_in_r2 [NUM_PORTS];
always_ff @ (posedge SYS_CLK) begin
  for (int i=0; i<NUM_PORTS; i++) begin
    if (!reg_rst_b) begin
      GPIOIN[i]  <= reg_reset(reg_table[get_idx(GPIOIN_desc[i], 0)]);
    end
    else begin
      GPIOIN[i]  <= gpio_in_r2[i] & bit_valid[i];
    end
  end
end
assign GPIOBPR = bit_valid;

generate begin
  for (genvar i=0; i<NUM_PORTS; i++) begin : g_port
    // TMR GPIO output and direction registers
    if (TMR_PORTS[i]) begin : g_tmr
      (* dont_touch = "yes" *) GBIT_s [2:0] gpioout_reg /* synthesis syn_preserve = 1 */;
      (* dont_touch = "yes" *) GBIT_s [2:0] gpiodir_reg /* synthesis syn_preserve = 1 */;

      always_ff @(posedge SYS_CLK) begin
        if (!reg_rst_b) begin
          gpioout_reg <= reg_reset_tmr(reg_table[get_idx(GPIOOUT_desc[i], 0)]);
          gpiodir_reg <= reg_reset_tmr(reg_table[get_idx(GPIODIR_desc[i], 0)]);
        end
        else begin
          gpioout_reg <= reg_write_tmr(reg_table[get_idx(GPIOOUT_desc[i], 0)], bus);
          gpiodir_reg <= reg_write_tmr(reg_table[get_idx(GPIODIR_desc[i], 0)], bus);
        end
      end

      assign GPIOOUT[i] = reg_mvote(gpioout_reg);
      assign GPIODIR[i] = reg_mvote(gpiodir_reg);
    end
    // Single GPIO output and direction registers
    else begin : g_single
      GBIT_s gpioout_reg;
      GBIT_s gpiodir_reg;

      always_ff @(posedge SYS_CLK) begin
        if (!reg_rst_b) begin
          gpioout_reg <= reg_reset(reg_table[get_idx(GPIOOUT_desc[i], 0)]);
          gpiodir_reg <= reg_reset(reg_table[get_idx(GPIODIR_desc[i], 0)]);
        end
        else begin
          gpioout_reg <= reg_write(reg_table[get_idx(GPIOOUT_desc[i], 0)], bus);
          gpiodir_reg <= reg_write(reg_table[get_idx(GPIODIR_desc[i], 0)], bus);
        end
      end

      assign GPIOOUT[i] = gpioout_reg;
      assign GPIODIR[i] = gpiodir_reg;
    end
  end
end
endgenerate

always_comb begin
  for (int i=0; i<NUM_PORTS; i++) begin
    GPIO_E[i] = GPIODIR[i] & bit_valid[i];
    GPIO_O[i] = GPIOOUT[i] & bit_valid[i];
  end
end

// 2-stage TMR synchronizer followed by the GPIO input register
generate begin
  for (genvar i=0; i<NUM_PORTS; i++) begin
    for (genvar j=0; j<32; j++)
      sclib_tmr_syncff sync_gi (.CLK(SYS_CLK), .RSTB(reg_rst_b), .DIN(GPIO_I[i][j]), .QOUT(gpio_in_r2[i][j]));
  end
end
endgenerate


// GPIO Edge Event Detect Function
//--------------------------------------------
// GPIOIN: previous, gpio_in_r2: current; used for edge detection
GBIT_s REDETEN [NUM_PORTS];
GBIT_s FEDETEN [NUM_PORTS];

always_ff @ (posedge SYS_CLK) begin
  for (int i=0; i<NUM_PORTS; i++) begin
    if (!reg_rst_b) begin
      EPENDING[i] <= reg_reset(reg_table[get_idx(EPENDING_desc[i], 0)]);
      PINTENB[i]  <= reg_reset(reg_table[get_idx(PINTENB_desc[i], 0)]);
      REDETEN[i]  <= reg_reset(reg_table[get_idx(REDETEN_desc[i], 0)]);
      FEDETEN[i]  <= reg_reset(reg_table[get_idx(FEDETEN_desc[i], 0)]);
    end
    else begin
      EPENDING[i] <= reg_write(reg_table[get_idx(EPENDING_desc[i], 0)], bus);
      PINTENB[i]  <= reg_write(reg_table[get_idx(PINTENB_desc[i], 0)], bus);
      REDETEN[i]  <= reg_write(reg_table[get_idx(REDETEN_desc[i], 0)], bus);
      FEDETEN[i]  <= reg_write(reg_table[get_idx(FEDETEN_desc[i], 0)], bus);

      for (int j=0; j<32; j++) begin
        if ((REDETEN[i][j] & ~GPIOIN[i][j] &  gpio_in_r2[i][j]) |
            (FEDETEN[i][j] &  GPIOIN[i][j] & ~gpio_in_r2[i][j]))
          EPENDING[i][j] <= 1'b1;
      end
    end
  end
end


// Register Read Logic
//----------------------------------
always_ff @ (posedge SYS_CLK) begin
  sc_reg_event_t re;
  if (!SYS_RST_B)
    bus.rdat <= '0;
  else begin
    bus.rdat <= '0;
    for(int i=0; i<$size(reg_table); i++) begin
      if (is_valid_reg_read(reg_table[i], bus, re))
        bus.rdat <= re.data;
    end
  end
end

// Register Table
//--------------------------------------------
always_comb begin                           // Descriptor        Data                Reg ID
  reg_table = '0;
  reg_table[get_idx(IPVER_desc, 0)]         = {IPVER_desc,       IPVER,              32'h0};
  reg_table[get_idx(IPCONF_desc, 0)]        = {IPCONF_desc,      IPCONF,             32'h0};
  reg_table[get_idx(RSTCTRL_desc, 0)]       = {RSTCTRL_desc,     reg_mvote(RSTCTRL), 32'h0};
  reg_table[get_idx(SCRPAD_desc, 0)]        = {SCRPAD_desc,      SCRPAD,             32'h0};
  reg_table[get_idx(INTSTATS_desc, 0)]      = {INTSTATS_desc,    INTSTATS,           32'h0};
  reg_table[get_idx(INTENB_desc, 0)]        = {INTENB_desc,      INTENB,             32'h0};
  for (int i=0; i<NUM_PORTS; i++) begin
    reg_table[get_idx(GPIOOUT_desc[i], 0)]  = {GPIOOUT_desc[i],  GPIOOUT[i],         32'h0};
    reg_table[get_idx(GPIOIN_desc[i], 0)]   = {GPIOIN_desc[i],   GPIOIN[i],          32'h0};
    reg_table[get_idx(GPIODIR_desc[i], 0)]  = {GPIODIR_desc[i],  GPIODIR[i],         32'h0};
    reg_table[get_idx(GPIOBPR_desc[i], 0)]  = {GPIOBPR_desc[i],  GPIOBPR[i],         32'h0};
    reg_table[get_idx(EPENDING_desc[i], 0)] = {EPENDING_desc[i], EPENDING[i],        32'h0};
    reg_table[get_idx(PINTENB_desc[i], 0)]  = {PINTENB_desc[i],  PINTENB[i],         32'h0};
    reg_table[get_idx(REDETEN_desc[i], 0)]  = {REDETEN_desc[i],  REDETEN[i],         32'h0};
    reg_table[get_idx(FEDETEN_desc[i], 0)]  = {FEDETEN_desc[i],  FEDETEN[i],         32'h0};
  end
end

endmodule
