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
//  Module: GPIO Register Descriptor (sc_gpio_reg_desc)
//-----------------------------------------------------------------------------

localparam int unsigned ADDR_SPACE_SIZE = 32'h800;
localparam logic [31:0] ADDR_DECODE_MASK = ADDR_SPACE_SIZE - 4;
localparam int unsigned REG_TABLE_ENTRIES = (32'h100 / 4) + (NUM_PORTS * 8);
sc_reg_entry_t [0:REG_TABLE_ENTRIES-1] reg_table;

logic [31:0] port_valid = (32'hFFFF_FFFF >> (32 - NUM_PORTS));
logic [31:0] bit_valid [NUM_PORTS];
assign bit_valid = GPIO_BITS_PRESENT;

// Common structures and attributes
//--------------------------------------------
// GPORT_ structures and attributes are used for registers that store
// the status of each GPIO port.
// The structure members for the fields are prepared as 32-bit wide,
// but ports beyond the number specified by NUM_PORTS are treated as
// reserved bits and controlled by GPORT_wr_attr.

typedef struct packed {
  logic [31:0] gport;
} GPORT_s;

const sc_reg_attr_t GPORT_wr_attr = '{wr: port_valid, default: '0};

// GBIT_ structures and attributes are used for registers that store
// the status of each bit in each GPIO port.
// The structure members for the fields are prepared as 32-bit wide,
// but bits beyond those defined by GPIO_PORT_WIDTH[] are treated as
// reserved bits and controlled by GBIT_wr_attr and GBIT_w1c_attr.

typedef struct packed {
  logic [31:0] gbit;
} GBIT_s;

sc_reg_attr_t GBIT_wr_attr [NUM_PORTS];
sc_reg_attr_t GBIT_w1c_attr [NUM_PORTS];

always_comb begin
  for (int i=0; i<NUM_PORTS; i++) begin
    GBIT_wr_attr[i]  = '{wr: bit_valid[i], default: '0};
    GBIT_w1c_attr[i] = '{w1c: bit_valid[i], default: '0};
  end
end

// rdonly_attr is a common attribute that can be used for
// read-only registers.
// All members of the sc_reg_attr_t structure are assigned 0.

const sc_reg_attr_t rdonly_attr = '{default: '0};



// IP Version Register
//--------------------------------------------
typedef struct packed {
  logic [7:0]  major_ver;
  logic [7:0]  minor_ver;
  logic [15:0] patch_ver;
} IPVER_s;

// IP Version Value
const IPVER_s IPVER_value = '{major_ver: MAJOR_VERSION,
                              minor_ver: MINOR_VERSION,
                              patch_ver: PATCH_VERSION};

// Register descriptor
const sc_reg_desc_t IPVER_desc = '{32'h0000_0000,    // ADDR
                                   ADDR_DECODE_MASK, // DMASK
                                   32'h0000_0000,    // OFFSET
                                   rdonly_attr,      // REG ATTR
                                   IPVER_value};     // INIT


// IP Configuration Register
//--------------------------------------------
typedef struct packed {
  logic [31:6] reserved;
  logic [5:0] port_number;
} IPCONF_s;

// Configuration information
const IPCONF_s IPCONF_value = '{port_number: NUM_PORTS, default: '0};

// Register descriptor
const sc_reg_desc_t IPCONF_desc = '{32'h0000_0004,    // ADDR
                                    ADDR_DECODE_MASK, // DMASK
                                    32'h0000_0000,    // OFFSET
                                    rdonly_attr,      // REG ATTR
                                    IPCONF_value};    // INIT


// Reset Control Register
//--------------------------------------------
typedef struct packed {
  logic [31:1] reserved;
  logic ip_reset;
} RSTCTRL_s;

RSTCTRL_s RSTCTRL_wr = '{ip_reset: '1, default: '0};

// Register access attributes        WR          W1S            W1C            FIXED
const sc_reg_attr_t RSTCTRL_attr = '{RSTCTRL_wr, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000};

// Register descriptor
const sc_reg_desc_t RSTCTRL_desc = '{32'h0000_0010,    // ADDR
                                     ADDR_DECODE_MASK, // DMASK
                                     32'h0000_0000,    // OFFSET
                                     RSTCTRL_attr,     // REG ATTR
                                     32'h0000_0001};   // INIT


// Scratch Pad Register
//--------------------------------------------
typedef struct packed {
  logic [31:0] scratch_pad;
} SCRPAD_s;

// Register access attributes       WR             W1S            W1C            FIXED
const sc_reg_attr_t SCRPAD_attr = '{32'hFFFF_FFFF, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000};

// Register descriptor
const sc_reg_desc_t SCRPAD_desc = '{32'h0000_001C,    // ADDR
                                    ADDR_DECODE_MASK, // DMASK
                                    32'h0000_0000,    // OFFSET
                                    SCRPAD_attr,      // REG ATTR
                                    32'h0000_0000};   // INIT


// Interrupt Status/Enable Registers
//--------------------------------------------

// Register descriptor
const sc_reg_desc_t INTSTATS_desc = '{32'h0000_0020,    // ADDR
                                      ADDR_DECODE_MASK, // DMASK
                                      32'h0000_0000,    // OFFSET
                                      rdonly_attr,      // REG ATTR
                                      32'h0000_0000};   // INIT

// Register descriptor
const sc_reg_desc_t INTENB_desc   = '{32'h0000_0024,    // ADDR
                                      ADDR_DECODE_MASK, // DMASK
                                      32'h0000_0000,    // OFFSET
                                      GPORT_wr_attr,    // REG ATTR
                                      32'h0000_0000};   // INIT


// GPIO Port Control Registers
// Output, Input, Direction, Bit Present
//--------------------------------------------

// Register descriptor
sc_reg_desc_t GPIOOUT_desc [NUM_PORTS];
sc_reg_desc_t GPIOIN_desc [NUM_PORTS];
sc_reg_attr_t GPIODIR_attr [NUM_PORTS];
sc_reg_desc_t GPIODIR_desc [NUM_PORTS];
sc_reg_desc_t GPIOBPR_desc [NUM_PORTS];

always_comb begin
  for (int i=0; i<NUM_PORTS; i++) begin
    GPIOOUT_desc[i] = '{32'h0000_0100 + (8'h20 * i),         // ADDR
                        ADDR_DECODE_MASK,                    // DMASK
                        32'h0000_0000,                       // OFFSET
                        GBIT_wr_attr[i],                     // REG ATTR
                        GPIO_OUT_INIT[i] & bit_valid[i]      // INIT
                       };

    GPIOIN_desc[i]  = '{32'h0000_0104 + (8'h20 * i),         // ADDR
                        ADDR_DECODE_MASK,                    // DMASK
                        32'h0000_0000,                       // OFFSET
                        rdonly_attr,                         // REG ATTR
                        32'h0000_0000};                      // INIT

    GPIODIR_attr[i] = '{GPIO_DIR_WRITABLE[i] & bit_valid[i], // WR
                        32'h0000_0000,                       // W1S
                        32'h00000000,                        // W1C
                        32'h0000_0000};                      // FIXED

    GPIODIR_desc[i] = '{32'h0000_0108 + (8'h20 * i),         // ADDR
                        ADDR_DECODE_MASK,                    // DMASK
                        32'h0000_0000,                       // OFFSET
                        GPIODIR_attr[i],                     // REG ATTR
                        GPIO_DIR_INIT[i] & bit_valid[i]      // INIT
                       };

    GPIOBPR_desc[i] = '{32'h0000_010C + (8'h20 * i),         // ADDR
                        ADDR_DECODE_MASK,                    // DMASK
                        32'h0000_0000,                       // OFFSET
                        rdonly_attr,                         // REG ATTR
                        bit_valid[i]                         // INIT
                       };
  end
end


// Port Edge Pending Register
//--------------------------------------------

// Register descriptor
sc_reg_desc_t EPENDING_desc [NUM_PORTS];

always_comb begin
  for (int i=0; i<NUM_PORTS; i++)
    EPENDING_desc[i] = '{32'h0000_0110 + (8'h20 * i), // ADDR
                          ADDR_DECODE_MASK,           // DMASK
                          32'h0000_0000,              // OFFSET
                          GBIT_w1c_attr[i],           // REG ATTR
                          32'h0000_0000               // INIT
                         };
end


// Port Interrupt Enable Register
//--------------------------------------------

// Register descriptor
sc_reg_desc_t PINTENB_desc [NUM_PORTS];

always_comb begin
  for (int i=0; i<NUM_PORTS; i++)
    PINTENB_desc[i] = '{32'h0000_0114 + (8'h20 * i), // ADDR
                        ADDR_DECODE_MASK,            // DMASK
                        32'h0000_0000,               // OFFSET
                        GBIT_wr_attr[i],             // REG ATTR
                        32'h0000_0000                // INIT
                       };
end


// Port Raiseing/Falling Edge Detect Enable Register
//--------------------------------------------

// Register descriptor
sc_reg_desc_t REDETEN_desc [NUM_PORTS];
sc_reg_desc_t FEDETEN_desc [NUM_PORTS];

always_comb begin
  for (int i=0; i<NUM_PORTS; i++) begin
    REDETEN_desc[i] = '{32'h0000_0118 + (8'h20 * i), // ADDR
                       ADDR_DECODE_MASK,             // DMASK
                       32'h0000_0000,                // OFFSET
                       GBIT_wr_attr[i],              // REG ATTR
                       32'h0000_0000                 // INIT
                      };

    FEDETEN_desc[i] = '{32'h0000_011C + (8'h20 * i), // ADDR
                       ADDR_DECODE_MASK,             // DMASK
                       32'h0000_0000,                // OFFSET
                       GBIT_wr_attr[i],              // REG ATTR
                       32'h0000_0000                 // INIT
                      };
  end
end
