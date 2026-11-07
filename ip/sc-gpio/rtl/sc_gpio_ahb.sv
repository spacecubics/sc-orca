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
//  Module: GPIO Core top module (sc_gpio_ahb)
//-----------------------------------------------------------------------------

module sc_gpio_ahb # (
  parameter  GPIO_NUM_PORTS = 1,
  parameter [31:0] GPIO_TMR_PORTS = 32'h0000_0000,
  // nr_ports: clamp GPIO_NUM_PORTS into valid range [1,32]
  localparam nr_ports = (GPIO_NUM_PORTS >= 32) ? 32:
                        (GPIO_NUM_PORTS <= 0)  ? 1 : GPIO_NUM_PORTS
) (
  // System Interface
  input SYS_CLK,
  input SYS_RST_B,
  output GPIO_IRQ,

  // AHB Interface
  input AHB_S_HSEL,
  input [31:0] AHB_S_HADDR,
  input [1:0] AHB_S_HTRANS,
  input [2:0] AHB_S_HSIZE,
  input [2:0] AHB_S_HBURST,
  input [3:0] AHB_S_HPROT,
  input AHB_S_HMASTLOCK,
  input AHB_S_HWRITE,
  input AHB_S_HREADYIN,
  output AHB_S_HREADYOUT,
  input [31:0] AHB_S_HWDATA,
  output [31:0] AHB_S_HRDATA,
  output [1:0] AHB_S_HRESP,

  // GPIO Parameter Interface
  // Per-port static configuration (constant wiring expected)
  input [31:0] GPIO_BITS_PRESENT [nr_ports],
  input [31:0] GPIO_DIR_WRITABLE [nr_ports],
  input [31:0] GPIO_DIR_INIT [nr_ports],
  input [31:0] GPIO_OUT_INIT [nr_ports],

  // GPIO Interface
  input [31:0] GPIO_I [nr_ports],
  output [31:0] GPIO_O [nr_ports],
  output [31:0] GPIO_E [nr_ports] // 1: output enabled, 0: input/High-Z
);

// synthesis translate_off
initial begin
  assert ((GPIO_NUM_PORTS >= 1) && (GPIO_NUM_PORTS <= 32))
    else $fatal(1, "GPIO_NUM_PORTS must be between 1 and 32.");
end
// synthesis translate_on

logic [31:0] reg_wadr;
logic [9:0] reg_wtyp;
logic [3:0] reg_wenb;
logic [31:0] reg_wdat;
logic reg_wwat;
logic reg_werr;
logic [31:0] reg_radr;
logic [9:0] reg_rtyp;
logic reg_renb;
logic [31:0] reg_rdat;
logic reg_rwat;
logic reg_rerr;

// AHB Subordinate
sc_ahbip_subordinate # (
  .CYCLE_MODE(1)
) ahb_s (
  // AHB Interface
  .HCLK(SYS_CLK),
  .HRESETN(SYS_RST_B),
  .HSEL(AHB_S_HSEL),
  .HADDR(AHB_S_HADDR),
  .HTRANS(AHB_S_HTRANS),
  .HSIZE(AHB_S_HSIZE),
  .HBURST(AHB_S_HBURST),
  .HPROT(AHB_S_HPROT),
  .HMASTLOCK(AHB_S_HMASTLOCK),
  .HWRITE(AHB_S_HWRITE),
  .HREADYIN(AHB_S_HREADYIN),
  .HREADYOUT(AHB_S_HREADYOUT),
  .HWDATA(AHB_S_HWDATA),
  .HRDATA(AHB_S_HRDATA),
  .HRESP(AHB_S_HRESP),

  // Register Interface
  .REG_WADR(reg_wadr),
  .REG_WTYP(reg_wtyp),
  .REG_WENB(reg_wenb),
  .REG_WDAT(reg_wdat),
  .REG_WWAT(reg_wwat),
  .REG_WERR(reg_werr),
  .REG_RADR(reg_radr),
  .REG_RTYP(reg_rtyp),
  .REG_RENB(reg_renb),
  .REG_RDAT(reg_rdat),
  .REG_RWAT(reg_rwat),
  .REG_RERR(reg_rerr)
);
sc_gpio_reg # (
  .NUM_PORTS(nr_ports),
  .TMR_PORTS(GPIO_TMR_PORTS)
) gpio_reg (
  // System Interface
  .SYS_CLK(SYS_CLK),
  .SYS_RST_B(SYS_RST_B),
  .GPIO_IRQ(GPIO_IRQ),

  // Register Interface
  .REG_WADR(reg_wadr),
  .REG_WTYP(reg_wtyp),
  .REG_WENB(reg_wenb),
  .REG_WDAT(reg_wdat),
  .REG_WWAT(reg_wwat),
  .REG_WERR(reg_werr),
  .REG_RADR(reg_radr),
  .REG_RTYP(reg_rtyp),
  .REG_RENB(reg_renb),
  .REG_RDAT(reg_rdat),
  .REG_RWAT(reg_rwat),
  .REG_RERR(reg_rerr),

  // GPIO Parameter Interface
  .GPIO_BITS_PRESENT(GPIO_BITS_PRESENT),
  .GPIO_DIR_WRITABLE(GPIO_DIR_WRITABLE),
  .GPIO_DIR_INIT(GPIO_DIR_INIT),
  .GPIO_OUT_INIT(GPIO_OUT_INIT),

  // GPIO Interface
  .GPIO_I(GPIO_I),
  .GPIO_O(GPIO_O),
  .GPIO_E(GPIO_E)
);

endmodule
