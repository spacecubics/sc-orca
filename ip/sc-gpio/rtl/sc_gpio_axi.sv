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
//  Module: GPIO Core top module (sc_gpio_axi)
//-----------------------------------------------------------------------------

module sc_gpio_axi # (
  parameter AXI_ID_WIDTH = 1,
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

  // AXI Interface
  input [AXI_ID_WIDTH-1:0] AXI_S_AWID,
  input [31:0] AXI_S_AWADDR,
  input [7:0] AXI_S_AWLEN,
  input [2:0] AXI_S_AWSIZE,
  input [1:0] AXI_S_AWBURST,
  input AXI_S_AWLOCK,
  input [3:0] AXI_S_AWCACHE,
  input [2:0] AXI_S_AWPROT,
  input AXI_S_AWVALID,
  output AXI_S_AWREADY,
  input [31:0] AXI_S_WDATA,
  input [3:0] AXI_S_WSTRB,
  input AXI_S_WLAST,
  input AXI_S_WVALID,
  output AXI_S_WREADY,
  output [AXI_ID_WIDTH-1:0] AXI_S_BID,
  output [1:0] AXI_S_BRESP,
  output AXI_S_BVALID,
  input AXI_S_BREADY,
  input [AXI_ID_WIDTH-1:0] AXI_S_ARID,
  input [31:0] AXI_S_ARADDR,
  input [7:0] AXI_S_ARLEN,
  input [2:0] AXI_S_ARSIZE,
  input [1:0] AXI_S_ARBURST,
  input AXI_S_ARLOCK,
  input [3:0] AXI_S_ARCACHE,
  input [2:0] AXI_S_ARPROT,
  input AXI_S_ARVALID,
  output AXI_S_ARREADY,
  output [AXI_ID_WIDTH-1:0] AXI_S_RID,
  output [31:0] AXI_S_RDATA,
  output [1:0] AXI_S_RRESP,
  output AXI_S_RLAST,
  output AXI_S_RVALID,
  input AXI_S_RREADY,

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

// AXI Subordinate
sc_axiip_subordinate # (
  .AXI_ID_WIDTH(AXI_ID_WIDTH),
  .AXI_ADDR_WIDTH(32),
  .AXI_DATA_BYTE(4)
) axi_s (
  // System Interface
  .AXI_CLK(SYS_CLK),
  .AXI_RESETN(SYS_RST_B),

  // AXI Interface
  .AXI_S_AWID(AXI_S_AWID),
  .AXI_S_AWADDR(AXI_S_AWADDR),
  .AXI_S_AWLEN(AXI_S_AWLEN),
  .AXI_S_AWSIZE(AXI_S_AWSIZE),
  .AXI_S_AWBURST(AXI_S_AWBURST),
  .AXI_S_AWLOCK(AXI_S_AWLOCK),
  .AXI_S_AWCACHE(AXI_S_AWCACHE),
  .AXI_S_AWPROT(AXI_S_AWPROT),
  .AXI_S_AWVALID(AXI_S_AWVALID),
  .AXI_S_AWREADY(AXI_S_AWREADY),
  .AXI_S_WDATA(AXI_S_WDATA),
  .AXI_S_WSTRB(AXI_S_WSTRB),
  .AXI_S_WLAST(AXI_S_WLAST),
  .AXI_S_WVALID(AXI_S_WVALID),
  .AXI_S_WREADY(AXI_S_WREADY),
  .AXI_S_BID(AXI_S_BID),
  .AXI_S_BRESP(AXI_S_BRESP),
  .AXI_S_BVALID(AXI_S_BVALID),
  .AXI_S_BREADY(AXI_S_BREADY),
  .AXI_S_ARID(AXI_S_ARID),
  .AXI_S_ARADDR(AXI_S_ARADDR),
  .AXI_S_ARLEN(AXI_S_ARLEN),
  .AXI_S_ARSIZE(AXI_S_ARSIZE),
  .AXI_S_ARBURST(AXI_S_ARBURST),
  .AXI_S_ARLOCK(AXI_S_ARLOCK),
  .AXI_S_ARCACHE(AXI_S_ARCACHE),
  .AXI_S_ARPROT(AXI_S_ARPROT),
  .AXI_S_ARVALID(AXI_S_ARVALID),
  .AXI_S_ARREADY(AXI_S_ARREADY),
  .AXI_S_RID(AXI_S_RID),
  .AXI_S_RDATA(AXI_S_RDATA),
  .AXI_S_RRESP(AXI_S_RRESP),
  .AXI_S_RLAST(AXI_S_RLAST),
  .AXI_S_RVALID(AXI_S_RVALID),
  .AXI_S_RREADY(AXI_S_RREADY),

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
