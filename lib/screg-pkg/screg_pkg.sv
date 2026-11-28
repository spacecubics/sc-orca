//-----------------------------------------------------------------------------
// SPDX-License-Identifier: CERN-OHL-W-2.0
// Copyright 2025 Space Cubics Inc.
//
// This source is licensed under CERN-OHL-W-2.0.
// This Covered Source is provided "as is"; any express or implied
// warranties are disclaimed to the maximum extent permitted by law.
//-----------------------------------------------------------------------------
// Space Cubics Open-Source Resilient Component Architecture
//  Register framework
//  Package: SC Register Package (screg_pkg)
//-----------------------------------------------------------------------------

`ifndef _SCREG_PKG_SV_
`define _SCREG_PKG_SV_

`timescale 1ps/1ps

package screg_pkg;

localparam logic [7:0]  SCREG_VERSION_MAJOR = 8'd1;
localparam logic [7:0]  SCREG_VERSION_MINOR = 8'd1;
localparam logic [15:0] SCREG_VERSION_PATCH = 16'd0;

localparam logic [31:0] SCREG_VERSION = {
  SCREG_VERSION_MAJOR,
  SCREG_VERSION_MINOR,
  SCREG_VERSION_PATCH
};

localparam int unsigned DATA_WIDTH = 32;
localparam int unsigned DATA_BYTES = DATA_WIDTH / 8;


// --------------------------------------------------
// Register Package Structure
// --------------------------------------------------

// Register Bus Structure
typedef struct packed {
  logic [31:0] wadr;
  logic [9:0]  wtyp;
  logic [DATA_BYTES-1:0] wenb;
  logic [DATA_WIDTH-1:0] wdat;
  logic        wwat;
  logic        werr;
  logic [31:0] radr;
  logic [9:0]  rtyp;
  logic        renb;
  logic [DATA_WIDTH-1:0] rdat;
  logic        rwat;
  logic        rerr;
} sc_regbus_t;

// Register access attributes: per-bit write behavior.
typedef struct packed {
  logic [DATA_WIDTH-1:0] wr;      // WR: write data is stored directly (0 -> 0, 1 -> 1)
  logic [DATA_WIDTH-1:0] w1s;     // W1S: write 1 sets bit; write 0 has no effect
  logic [DATA_WIDTH-1:0] w1c;     // W1C: write 1 clears bit; write 0 has no effect
  logic [DATA_WIDTH-1:0] fixed;   // FIXED: bit is held at its initial value; writes are ignored
} sc_reg_attr_t;

// Register descriptor: static metadata describing each register.
typedef struct packed {
  logic [31:0] addr;              // ADDR: byte offset from the module base address
  logic [31:0] dmask;             // DMASK: decode mask for address comparison (1 = compare, 0 = ignore)
  logic [31:0] offset;            // OFFSET: byte offset between consecutive registers (>= 4; ignored if single register)
  sc_reg_attr_t rattr;            // RATTR: register access attributes
  logic [DATA_WIDTH-1:0] init;    // INIT: reset value for this register
} sc_reg_desc_t;

// Memory descriptor: static metadata describing a memory-mapped region.
typedef struct packed {
  logic [31:0] addr;              // ADDR: byte offset from the module base address
  logic [31:0] dmask;             // DMASK: decode mask for address comparison (1 = compare, 0 = ignore)
  integer words;                  // WORDS: number of register words in this memory region
} sc_mem_desc_t;

// Register entry: contains the register descriptor and its current value.
typedef struct packed {
  sc_reg_desc_t desc;             // DESC: register descriptor
  logic [DATA_WIDTH-1:0] data;    // DATA: current register value
  integer regid;                  // REGID: index of this instance (0 for the first)
} sc_reg_entry_t;

// Register access event: structure capturing a bus read/write transaction.
typedef struct packed {
  logic [DATA_WIDTH-1:0] en;      // EN: bit enable mask for read or write
  integer regid;                  // REGID: index of this instance (0 for the first)
  logic [DATA_WIDTH-1:0] data;    // DATA: data value associated with the access
} sc_reg_event_t;

// --------------------------------------------------
// Register Package Function
// --------------------------------------------------

// Get Register index
// ------------------------------
// Calculate register index from address offset and stride.
function automatic integer get_idx;
  input sc_reg_desc_t rd;
  input integer regid;
begin
  return ((rd.addr + (regid * rd.offset)) >> $clog2(DATA_BYTES));
end
endfunction

// Address Match Check
// ------------------------------
// Check if the current bus address matches the register entry address.
function automatic logic is_raddr_hit;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
begin
  return (ety.desc.dmask != '0) &
          ((bus.radr & ety.desc.dmask) == ((ety.desc.addr + (ety.regid * ety.desc.offset)) & ety.desc.dmask));
end
endfunction

function automatic logic is_waddr_hit;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
begin
  return (ety.desc.dmask != '0) &
          ((bus.wadr & ety.desc.dmask) == ((ety.desc.addr + (ety.regid * ety.desc.offset)) & ety.desc.dmask));
end
endfunction

// Majority Voter
// ------------------------------
// Perform bitwise majority voting on three redundant register values.
function automatic logic [DATA_WIDTH-1:0] reg_mvote;
  input logic [2:0][DATA_WIDTH-1:0] data;
begin
  reg_mvote = (data[0] & data[1]) |
              (data[1] & data[2]) |
              (data[2] & data[0]);
end
endfunction

// Register Reset
// ------------------------------
// Generate the initial register value based on the register descriptor.
function automatic logic [DATA_WIDTH-1:0] reg_reset;
  input sc_reg_entry_t ety;
begin
  reg_reset = ety.desc.init;
end
endfunction

// Register Reset for TMR
// ------------------------------
// Generate reset values for triple-modular redundant registers.
function automatic logic [2:0][DATA_WIDTH-1:0] reg_reset_tmr;
  input sc_reg_entry_t ety;
begin
  reg_reset_tmr = '{default: reg_reset(ety)};
end
endfunction

// Register Write
// ------------------------------
// Return the new register data after applying the write logic as defined by access attributes.
function automatic logic [DATA_WIDTH-1:0] reg_write;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
  integer i;
begin

  // Initialize
  for (i=0; i<DATA_WIDTH; i++) begin
    if ((ety.desc.rattr.fixed[i] == 0) &
        (ety.desc.rattr.wr[i] | ety.desc.rattr.w1s[i] | ety.desc.rattr.w1c[i]))
      reg_write[i] = ety.data[i];
    else
      reg_write[i] = ety.desc.init[i];
  end

  // Data write
  if (is_waddr_hit(ety, bus)) begin
    for (i=0; i<DATA_WIDTH; i++) begin
      if (bus.wenb[i/8] & ~ety.desc.rattr.fixed[i]) begin
        if (ety.desc.rattr.wr[i])
          reg_write[i] = bus.wdat[i];
        else if (ety.desc.rattr.w1s[i] & bus.wdat[i])
          reg_write[i] = 1'b1;
        else if (ety.desc.rattr.w1c[i] & bus.wdat[i])
          reg_write[i] = 1'b0;
      end
    end
  end
end
endfunction

// Register Write for TMR
// ------------------------------
// Return the new register data for all TMR lanes after applying the same write logic.
function automatic logic [2:0][DATA_WIDTH-1:0] reg_write_tmr;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
begin
  reg_write_tmr = '{default: reg_write(ety, bus)};
end
endfunction

// Register Read
// ------------------------------
// Return the register data when the bus address matches the register entry.
function automatic logic [DATA_WIDTH-1:0] reg_read;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
begin
  if (is_raddr_hit(ety, bus))
    reg_read = ety.data;
  else
    reg_read = '0;
end
endfunction

// Register Write Event
// ------------------------------
// Return 1 when a valid register write occurs (bus address matches the register entry).
function automatic logic is_valid_reg_write;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
  output sc_reg_event_t evt;
  integer i;
begin
  evt.en = '0;
  evt.regid = 0;
  evt.data = '0;

  if (is_waddr_hit(ety, bus)) begin
    for (i=0; i<DATA_WIDTH; i++) begin
      if (bus.wenb[i/8]) begin
        evt.en[i] = 1'b1;
        evt.data[i] = bus.wdat[i];
      end
    end
    evt.regid = ety.regid;
  end
  return (evt.en != '0);
end
endfunction

// Register Write Data Match Event
// ------------------------------
// Return 1 when a valid register write occurs and the written data matches the expected value.
function automatic logic is_valid_reg_write_match;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
  input logic [DATA_WIDTH-1:0] mask;
  input logic [DATA_WIDTH-1:0] data;
  integer i;
begin
  if (is_waddr_hit(ety, bus)) begin
    for (i=0; i<DATA_WIDTH; i++) begin
      if (mask[i])
        if (!(bus.wenb[i/8] & (bus.wdat[i] == data[i])))
          return 0;
    end
    return 1;
  end
  return 0;
end
endfunction

// Register Read Event
// ------------------------------
// Return 1 when a valid register read occurs (bus address matches the register entry).
// When detected, the event structure is filled with the read data.
function automatic logic is_valid_reg_read;
  input sc_reg_entry_t ety;
  input sc_regbus_t bus;
  output sc_reg_event_t evt;
begin
  evt.en = '0;
  evt.regid = 0;
  evt.data = '0;

  if (is_raddr_hit(ety, bus)) begin
    if (bus.renb) begin
      evt.en = '1;
      evt.regid = ety.regid;
      evt.data = ety.data;
      return 1;
    end
  end
  return 0;
end
endfunction

// Memory Space Write Event
// ------------------------------
// Return 1 when a valid memory write occurs (bus address matches the memory space).
// When detected, the event structure is filled with the written data and word index.
function automatic logic is_valid_mem_write;
  input sc_mem_desc_t md;
  input sc_regbus_t bus;
  output sc_reg_event_t evt;
  integer i, j;
begin
  evt.en = '0;
  evt.regid = 0;
  evt.data = '0;

  for (i=0; i<md.words; i++) begin
    if ((md.dmask != '0) &&
        ((bus.wadr & md.dmask)
         == ((md.addr + (i * DATA_BYTES)) & md.dmask))) begin
      for (j=0; j<DATA_WIDTH; j++) begin
        if (bus.wenb[j/8]) begin
          evt.en[j] = 1'b1;
          evt.data[j] = bus.wdat[j];
        end
      end
      evt.regid = i;
    end
  end
  return (evt.en != '0);
end
endfunction

// Memory Space Read Event
// ------------------------------
// Return 1 when a valid memory read occurs (bus address matches the memory space).
// When detected, the event structure is filled with the corresponding word index.
function automatic logic is_valid_mem_read;
  input sc_mem_desc_t md;
  input sc_regbus_t bus;
  output sc_reg_event_t evt;
  integer i;
begin
  evt.en = '0;
  evt.regid = 0;
  evt.data = '0;

  for (i=0; i<md.words; i++) begin
    if ((md.dmask != '0) &&
        ((bus.radr & md.dmask)
         == ((md.addr + (i * DATA_BYTES)) & md.dmask))) begin
      if (bus.renb) begin
        evt.en = '1;
        evt.regid = i;
        return 1;
      end
    end
  end
  return 0;
end
endfunction

endpackage
`endif
