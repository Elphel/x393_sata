/*******************************************************************************
 * Module: ahci_top
 * Date:2016-01-09  
 * Author: Andrey Filippov     
 * Description: Top module of the AHCI implementation
 * 
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_top.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_top.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_top#(
    parameter PREFETCH_ALWAYS =   0,
    parameter READ_REG_LATENCY =  2, // 0 if  reg_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter READ_CT_LATENCY =   1, // 0 if  ct_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter ADDRESS_BITS =     10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)
)(
    input             aclk,    // clock - should be buffered
    input             arst,    // @aclk sync reset, active high
    input             mclk,    // SATA system clock (current 75MHz for SATA2)
    input             mrst,    // reset in mclk clock domain (after SATA PLL is on)
    // async reset for SATA (mrst will be responce to it)
    output            hba_arst,          // hba async reset (currently does ~ the same as port reset)
    output            port_arst,         // port0 async reset by software
    
    input             hclk,    // AXI HP interface clock for 64-bit DMA (current - 150MHz
    input             hrst,    // reset in hclk clock domain
// MAXIGP1   
// AXI Write Address
    input      [31:0] awaddr,  // AWADDR[31:0], input
    input             awvalid, // AWVALID, input
    output            awready, // AWREADY, output
    input      [11:0] awid,    // AWID[11:0], input
    input      [ 3:0] awlen,   // AWLEN[3:0], input
    input      [ 1:0] awsize,  // AWSIZE[1:0], input
    input      [ 1:0] awburst, // AWBURST[1:0], input
// AXI PS Master GP0: Write Data
    input      [31:0] wdata,   // WDATA[31:0], input
    input             wvalid,  // WVALID, input
    output            wready,  // WREADY, output
    input      [11:0] wid,     // WID[11:0], input
    input             wlast,   // WLAST, input
    input      [ 3:0] wstb,    // WSTRB[3:0], input
// AXI PS Master GP0: Write Responce
    output            bvalid,  // BVALID, output
    input             bready,  // BREADY, input
    output     [11:0] bid,     // BID[11:0], output
    output     [ 1:0] bresp,    // BRESP[1:0], output
// AXI Read Address   
    input      [31:0] araddr,  // ARADDR[31:0], input 
    input             arvalid, // ARVALID, input
    output            arready, // ARREADY, output
    input      [11:0] arid,    // ARID[11:0], input
    input      [ 3:0] arlen,   // ARLEN[3:0], input
    input      [ 1:0] arsize,  // ARSIZE[1:0], input
    input      [ 1:0] arburst, // ARBURST[1:0], input
// AXI Read Data
    output     [31:0] rdata,   // RDATA[31:0], output
    output            rvalid,  // RVALID, output
    input             rready,  // RREADY, input
    output     [11:0] rid,     // RID[11:0], output
    output            rlast,   // RLAST, output
    output     [ 1:0] rresp,   // RRESP
// SAXIHP3    
    // axi_hp signals write channel
    // write address
    output     [31:0] afi_awaddr,
    output            afi_awvalid,
    input             afi_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_awid,
    output     [ 1:0] afi_awlock,
    output     [ 3:0] afi_awcache,
    output     [ 2:0] afi_awprot,
    output     [ 3:0] afi_awlen,
    output     [ 1:0] afi_awsize,
    output     [ 1:0] afi_awburst,
    output     [ 3:0] afi_awqos,
    // write data
    output     [63:0] afi_wdata,
    output            afi_wvalid,
    input             afi_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_wid,
    output            afi_wlast,
    output     [ 7:0] afi_wstrb,
    // write response
    input             afi_bvalid,   // @SuppressThisWarning VEditor unused
    output            afi_bready,
    input      [ 5:0] afi_bid,      // @SuppressThisWarning VEditor unused
    input      [ 1:0] afi_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input      [ 7:0] afi_wcount,
    input      [ 5:0] afi_wacount,
    output            afi_wrissuecap1en,
    // AXI_HP signals - read channel
    // read address
    output     [31:0] afi_araddr,
    output               afi_arvalid,
    input                afi_arready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_arid,
    output     [ 1:0] afi_arlock,
    output     [ 3:0] afi_arcache,
    output     [ 2:0] afi_arprot,
    output     [ 3:0] afi_arlen,
    output     [ 1:0] afi_arsize,
    output     [ 1:0] afi_arburst,
    output     [ 3:0] afi_arqos,
    // read data
    input      [63:0] afi_rdata,
    input             afi_rvalid,
    output            afi_rready,
    input      [ 5:0] afi_rid,     // @SuppressThisWarning VEditor unused
    input             afi_rlast,   // @SuppressThisWarning VEditor unused
    input      [ 1:0] afi_rresp,   // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input      [ 7:0] afi_rcount,
    input      [ 2:0] afi_racount,
    output            afi_rdissuecap1en,
// Data/type FIFO, host -> device   
    // Data System memory or FIS -> device
    output      [31:0] h2d_data,     // 32-bit data from the system memory to HBA (dma data)
    output      [ 1:0] h2d_type,     // 0 - data, 1 - FIS head, 2 - FIS END (make FIS_Last?)
    output             h2d_valid,    // output register full
    input              h2d_ready,     // send FIFO has room for data (>= 8? dwords)
 
// Data/type FIFO, device -> host
    input       [31:0] d2h_data,         // FIFO output data
    input       [ 1:0] d2h_type,    // 0 - data, 1 - FIS head, 2 - R_OK, 3 - R_ERR
    input              d2h_valid,  // Data available from the transport layer in FIFO                
    input              d2h_many,    // Multiple DWORDs available from the transport layer in FIFO           
    output             d2h_ready,   // This module or DMA consumes DWORD
    
    // communication with transport/link/phys layers
//    input              phy_rst,      // frome phy, as a responce to hba_arst || port_arst. It is deasserted when clock is stable
    input              phy_ready,
    input              syncesc_recv, // These two inputs interrupt transmit
    input              xmit_err,     // Error during sending of a FIS
    output             syncesc_send,  // Send sync escape
    input              syncesc_send_done, // "SYNC escape until the interface is quiescent..."
    input              cominit_got,
    output             set_offline, // electrically idle
    input              x_rdy_collision, // X_RDY/X_RDY collision on interface 
    
    output             send_R_OK,    // Should it be originated in this layer SM?
    output             send_R_ERR,

    output             irq // CPU interrupt request
    
);
// axi_ahci_regs signals:
// 1. Notification of data written @ hba_clk
    wire [ADDRESS_BITS-1:0] soft_write_addr;  // register address written by software
    wire             [31:0] soft_write_data;  // register data written (after applying wstb and type (RO, RW, RWC, RW1)
    wire                    soft_write_en;    // write enable for data write
//    wire                    hba_arst;       // hba async reset (currently does ~ the same as port reset)
//    wire                    port_arst;      // port0 async reset by software
// 2. HBA R/W registers, use hba clock
//    wire                    hba_rst;
    wire                    regs_we_acs;
//    wire              [1:0] regs_re_fsm;
    wire             [31:0] regs_din_from_acs; // from fsm
    wire                    regs_we_freceive;
    wire              [1:0] regs_re_ftransmit; // [0] - re, [1] - regen
    wire [ADDRESS_BITS-1:0] regs_saddr; // read/write adderss from ahci_fsm
    wire [ADDRESS_BITS-1:0] regs_waddr;
    wire [ADDRESS_BITS-1:0] regs_raddr;
    wire             [31:0] regs_din_from_freceive;
    wire             [31:0] regs_dout;
    wire [ADDRESS_BITS-1:0] regs_addr = ({ADDRESS_BITS{regs_we}} & regs_waddr) |
                                        ({ADDRESS_BITS{regs_re[0]}} & regs_raddr) |
//                                        ({ADDRESS_BITS{regs_re_fsm[0] | regs_we_acs}} & regs_saddr);
                                        ({ADDRESS_BITS{regs_we_acs}} & regs_saddr);
                                        
    wire             [31:0] regs_din =  ({32{regs_we_freceive}} & regs_din_from_freceive) |
                                        ({32{regs_we_acs}} &      regs_din_from_acs);
//    wire              [1:0] regs_re = regs_re_ftransmit | regs_re_fsm; // [0] - re, [1] - regen
    wire              [1:0] regs_re = regs_re_ftransmit; // [0] - re, [1] - regen
    wire                    regs_we = regs_we_freceive | regs_we_acs;
    
    
//---------------------    

//    wire             [31:7] ctba; // input[31:7] 
    wire                    ctba_ld; // input
    wire             [15:0] prdtl; // input[15:0]
     
    wire                    dev_wr; // input
    wire                    dma_cmd_start; // input
    wire                    dma_prd_start; // input
    wire                    dma_cmd_abort; // input
// Use some of the custom registers in the address space?    
    wire             [17:0] fsm_pgm_ad; // @aclk, address/data to program the AHCI FSM
    wire                    fsm_pgm_wa; // @aclk, address strobe to program the AHCI FSM
    wire                    fsm_pgm_wd; // @aclk, data strobe to program the AHCI FSM
    
    
    wire             [ 3:0] axi_wr_cache_mode; // input[3:0] 
    wire             [ 3:0] axi_rd_cache_mode; // input[3:0] 
    wire                    set_axi_cache_mode; // input (both axi_wr_cache_mode and axi_rd_cache_mode)
    wire                    dma_ct_busy; // output reg 
    wire             [ 4:0] dma_ct_addr; // input[4:0] 
    wire             [ 1:0] dma_ct_re; // input
    wire             [31:0] dma_ct_data; // output[31:0] reg 
    wire                    dma_prd_done; // output (finished next prd)
    wire                    dma_prd_irq; // output (finished next prd and prd irq is enabled)
    wire                    dma_cmd_busy; // output reg (DMA engine is processing PRDs)
    wire                    dma_cmd_done; // output (last PRD is over)
    wire             [31:0] dma_dout;    // output[31:0] 
    wire                    dma_dav; // output
    wire                    dma_re;      // input
    wire                    dma_in_ready; // output
    wire                    dma_we;      // input
// ---------------------------------------
    // fsm <-> ahc_fis_receive
    // fsm ->
    wire                    frcv_first_vld;
    wire                    frcv_get_dsfis;
    wire                    frcv_get_psfis;
    wire                    frcv_get_rfis;
    wire                    frcv_get_sdbfis;
    wire                    frcv_get_ufis;
    wire                    frcv_get_data_fis;
    wire                    frcv_get_ignore;    // ignore whatever FIS (use for DMA activate too?)
    // short commands:
    // next commands use register address/data/we for 1 clock cycle - after next to command (commnd - t0, we - t2)
    wire                    frcv_update_err_sts;// update PxTFD.STS and PxTFD.ERR from the last received regs d2h
    wire                    frcv_update_pio;    // update PxTFD.STS and PxTFD.ERR from pio_* (entry PIO:Update)
    
    wire                    frcv_update_prdbc;  // update PRDBC in registers
    wire                    frcv_clear_bsy_drq; // clear PxTFD.STS.BSY and PxTFD.STS.DRQ, update
    wire                    frcv_clear_bsy_set_drq; // clear PxTFD.STS.BSY and sets PxTFD.STS.DRQ, update
    
    wire                    frcv_set_bsy;       // set PxTFD.STS.BSY, update
    wire                    frcv_set_sts_7f;    // set PxTFD.STS = 0x7f, update
    wire                    frcv_set_sts_80;    // set PxTFD.STS = 0x80 (may be combined with set_sts_7f), update
    wire                    frcv_decr_dwc;      // decrement DMA Xfer counter // need pulse to 'update_prdbc' to write to registers
    wire                    frcv_clear_xfer_cntr; // Clear pXferCntr to 0
    
    // fsm <-
    wire                    frcv_busy;          // busy processing FIS 
    wire                    frcv_done;          // done processing FIS (see fis_ok, fis_err, fis_ferr)
    wire                    frcv_ok;            // FIS done,  checksum OK reset by starting a new get FIS
    wire                    frcv_err;           // FIS done, checksum ERROR reset by starting a new get FIS
    wire                    frcv_ferr;          // FIS done, fatal error - FIS too long

    wire                    frcv_set_update_sig; // when set, enables get_sig (and resets itself)
    wire                    frcv_pUpdateSig;     // state variable
    wire                    frcv_sig_available;  // signature data available
    wire                    frcv_update_sig;        // update signature

    
    // fsm <- state variables that are maintained inside 'ahc_fis_receive'
    wire              [7:0] tfd_sts;       // Current PxTFD status field (updated after regFIS and SDB - certain fields)
                                           // tfd_sts[7] - BSY, tfd_sts[4] - DRQ, tfd_sts[0] - ERR
    wire              [7:0] tfd_err;       // Current PxTFD error field (updated after regFIS and SDB)
    wire                    fis_i;         // value of "I" field in received regsD2H or SDB FIS
    wire                    sdb_n;         // value of "N" field in received SDB FIS 
    wire                    dma_a;         // value of "A" field in received DMA Setup FIS 
    wire                    dma_d;         // value of "D" field in received DMA Setup FIS
    wire                    pio_i;         // value of "I" field in received PIO Setup FIS
    wire                    pio_d;         // value of "D" field in received PIO Setup FIS
    wire              [7:0] pio_es;        // value of PIO E_Status
    
    wire                    pPioXfer;
    // Using even word count (will be rounded up), partial DWORD (last) will be handled by PRD length if needed
    
    wire             [31:0] xfer_cntr; 
    wire                    xfer_cntr_zero; 
                                             
    wire             [11:0] data_in_dwords;  // number of DWORDs received in data FIS (can be updated internally). Is it needed?

    // fsm <-> ahc_fis_transmit
    // Command pulses to execute states fsm -> ahc_fis_transmit
    wire                    fsnd_fetch_cmd;   // Enter p:FetchCmd, fetch command header (from the register memory, prefetch command FIS)
                                               // wait for either fetch_cmd_busy == 0 or pCmdToIssue ==1 after fetch_cmd
    wire                    fsnd_cfis_xmit;    // transmit command (wait for dma_ct_busy == 0)
    wire                    fsnd_dx_transmit;  // send FIS header DWORD, (just 0x46), then forward DMA data
                                                // transmit until error, 2048DWords or pDmaXferCnt 
    wire                    fsnd_atapi_xmit;  // tarsmit ATAPI command FIS
    // responses fsm <- ahc_fis_transmit
    wire                    fsnd_done;
    wire                    fsnd_busy;
    // Short action pulses fsm -> ahc_fis_transmit
    wire                    fsnd_clearCmdToIssue; // From CFIS:SUCCESS 
    // State variables fsm <- ahc_fis_transmit 
    wire                    fsnd_pCmdToIssue; // AHCI port variable
    wire             [ 1:0] fsnd_dx_err;       // bit 0 - syncesc_recv, 1 - xmit_err  (valid @ xmit_err and later, reset by new command)
    wire                    fsnd_ch_c;        // Clear busy upon R_OK for this FIS
    wire                    fsnd_ch_b;        // Built-in self test command
    wire                    fsnd_ch_r;        // reset - may need to send SYNC escape before this command
    wire                    fsnd_ch_p;        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    wire                    fsnd_ch_w;        // Write: system memory -> device
    wire                    fsnd_ch_a;        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    wire              [4:0] fsnd_ch_cfl;      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal, ... Maybe not needed outside ahc_fis_transmit

    wire             [11:0] data_out_dwords; // number of DWORDs sent in data FIS

    wire                    was_hba_rst; 
    wire                    was_port_rst; 

    // signals between ahci_fsm and ahci_ctrl_stat
    wire                          update_regs_pending;
    wire                          update_all_regs;
    wire                          update_regs_busy; // valid same cycle as update_all_regs

    wire                          st01_pending;    // software turned PxCMD.ST from 0 to 1
    wire                          st10_pending;    // software turned PxCMD.ST from 1 to 0
    wire                          st_pending_reset;// reset both st01_pending and st10_pending

    
    // these following individual signals may be unneded - use update_all_regs -> update_regs_busy
    wire                          update_GHC__IS;
    wire                          update_HBA_PORT__PxIS;
    wire                          update_HBA_PORT__PxSSTS;
    wire                          update_HBA_PORT__PxSERR;
    wire                          update_HBA_PORT__PxCMD;
    wire                          update_HBA_PORT__PxCI;

// PxCMD
    wire                          pcmd_clear_icc; // clear PxCMD.ICC field
    wire                          pcmd_esp;       // external SATA port (just forward value)
    wire                          pcmd_cr;        // command list run - current
    wire                          pcmd_cr_set;    // command list run set
    wire                          pcmd_cr_reset;  // command list run reset
    wire                          pcmd_fr;        // ahci_fis_receive:get_fis_busy
    wire                          pcmd_fre;       // FIS enable copy to memory
    wire                          pcmd_clear_bsy_drq; // == ahci_fis_receive:clear_bsy_drq
    wire                          pcmd_clo;       //RW1, causes ahci_fis_receive:clear_bsy_drq, that in turn resets this bit
    wire                          pcmd_clear_st;  // RW clear ST (start) bit
    wire                          pcmd_st;        // current value
    wire                          pfsm_started;   // H: FSM done, P: FSM started (enable sensing pcmd_st_cleared)
    wire                          pcmd_st_cleared; // bit was cleared by software    
//clear_bsy_drq    
// Interrupt inputs
    wire                          sirq_TFE; // RWC: Task File Error Status
    wire                          sirq_IF;  // RWC: Interface Fatal Error Status (sect. 6.1.2)
    wire                          sirq_INF; // RWC: Interface Non-Fatal Error Status (sect. 6.1.2)
    wire                          sirq_OF;  // RWC: Overflow Status
    wire                          sirq_PRC; // RO:  PhyRdy changed Status
    wire                          sirq_PC;  // RO:  Port Connect Change Status
    wire                          sirq_DP;  // RWC: Descriptor Processed with "I" bit on
    wire                          sirq_UF;  // RO:  Unknown FIS
    wire                          sirq_SDB; // RWC: Set Device Bits Interrupt - Set Device bits FIS with 'I' bit set
    wire                          sirq_DS;  // RWC: DMA Setup FIS Interrupt - DMA Setup FIS received with 'I' bit set
    wire                          sirq_PS;  // RWC: PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set
    wire                          sirq_DHR; // RWC: D2H Register FIS Interrupt - D2H Register FIS received with 'I' bit set
// SCR1:SError (only inputs that are not available in sirq_* ones
                                  //sirq_PC;
                                  //sirq_UF
    wire                          serr_DT;   // RWC: Transport state transition error
    wire                          serr_DS;   // RWC: Link sequence error
    wire                          serr_DH;   // RWC: Handshake Error (i.e. Device got CRC error)
    wire                          serr_DC;   // RWC: CRC error in Link layer
    wire                          serr_DB;   // RWC: 10B to 8B decode error
    wire                          serr_DW;   // RWC: COMMWAKE signal was detected
    wire                          serr_DI;   // RWC: PHY Internal Error
                                  // sirq_PRC;
                                  // sirq_IF || // sirq_INF  
    wire                          serr_EP;   // RWC: Protocol Error - a violation of SATA protocol detected
    wire                          serr_EC;   // RWC: Persistent Communication or Data Integrity Error
    wire                          serr_ET;   // RWC: Transient Data Integrity Error (error not recovered by the interface)
    wire                          serr_EM;   // RWC: Communication between the device and host was lost but re-established
    wire                          serr_EI;   // RWC: Recovered Data integrity Error
    wire                          serr_diag_X; // value of PxSERR.DIAG.X

     
    
// SCR0: SStatus
    wire                          ssts_ipm_dnp;      // device not present or communication not established
    wire                          ssts_ipm_active;   // device in active state
    wire                          ssts_ipm_part;     // device in partial state
    wire                          ssts_ipm_slumb;    // device in slumber state
    wire                          ssts_ipm_devsleep; // device in DevSleep state
    
    wire                          ssts_spd_dnp;      // device not present or communication not established
    wire                          ssts_spd_gen1;     // Gen 1 rate negotiated
    wire                          ssts_spd_gen2;     // Gen 2 rate negotiated
    wire                          ssts_spd_gen3;     // Gen 3 rate negotiated
    
    wire                          ssts_det_ndnp;     // no device detected, phy communication not established
    wire                          ssts_det_dnp;      // device detected, but phy communication not established
    wire                          ssts_det_dp;       // device detected, phy communication established
    wire                          ssts_det_offline;  // device detected, phy communication established
    wire                    [3:0] ssts_det;          // current value of PxSSTS.DET
    
 // SCR2:SControl (written by software only)
    wire                    [3:0] sctl_ipm;          // Interface power management transitions allowed
    wire                    [3:0] sctl_spd;          // Interface maximal speed
    wire                    [3:0] sctl_det;          // Device detection initialization requested
    wire                          sctl_det_changed;  // Software had written new value to sctl_det
    wire                          sctl_det_reset;    // clear sctl_det_changed
    
    wire                          pxci0_clear;       // PxCI clear
    wire                          pxci0;             // pxCI current value



    ahci_fsm// #(
//        .READ_REG_LATENCY(2),
//        .ADDRESS_BITS(10)
//    ) 
    ahci_fsm_i (
        .hba_rst                 (mrst),               // input
        .mclk                     (mclk),              // input
        .was_hba_rst              (was_hba_rst),       // input 
        .was_port_rst             (was_port_rst),      // input

        .aclk                     (aclk),              // input
        .arst                     (arst),              // input
        .pgm_ad                   (fsm_pgm_ad),        // input[17:0] 
        .pgm_wa                   (fsm_pgm_wa),        // input
        .pgm_wd                   (fsm_pgm_wd),        // input

        .phy_ready                (phy_ready),         // input
        .syncesc_send             (syncesc_send),      // output
        .syncesc_send_done        (syncesc_send_done), // input
        .cominit_got              (cominit_got),       // input
        .set_offline              (set_offline),       // output
        .x_rdy_collision          (x_rdy_collision),   // input 
        
        .send_R_OK                (send_R_OK),         // output
        .send_R_ERR               (send_R_ERR),        // output
        
        .update_pending           (update_regs_pending),// input
        .update_all               (update_all_regs),   // output
        .update_busy              (update_regs_busy),  // input
        .update_gis               (update_GHC__IS),    // output
        .update_pis               (update_HBA_PORT__PxIS),   // output
        .update_ssts              (update_HBA_PORT__PxSSTS), // output
        .update_serr              (update_HBA_PORT__PxSERR), // output
        .update_pcmd              (update_HBA_PORT__PxCMD),  // output
        .update_pci               (update_HBA_PORT__PxCI),   // output
        .st01_pending             (st01_pending),      // input 
        .st10_pending             (st10_pending),      // input 
        .st_pending_reset         (st_pending_reset),  // output
        .pcmd_clear_icc           (pcmd_clear_icc),    // output
        .pcmd_esp                 (pcmd_esp),          // output
        .pcmd_cr                  (pcmd_cr),           // input
        .pcmd_cr_set              (pcmd_cr_set),       // output
        .pcmd_cr_reset            (pcmd_cr_reset),     // output
        .pcmd_fr                  (pcmd_fr),           // output
        .pcmd_clear_bsy_drq       (pcmd_clear_bsy_drq),// output
        .pcmd_clo                 (pcmd_clo),          // input
        .pcmd_clear_st            (pcmd_clear_st),     // output
        .pcmd_st                  (pcmd_st),           // input
        .pfsm_started             (pfsm_started),      // output
        .pcmd_st_cleared          (pcmd_st_cleared),   // input 
        .sirq_TFE                 (sirq_TFE),          // output
        .sirq_IF                  (sirq_IF),           // output
        .sirq_INF                 (sirq_INF),          // output
        .sirq_OF                  (sirq_OF),           // output
        .sirq_PRC                 (sirq_PRC),          // output
        .sirq_PC                  (sirq_PC),           // output
        .sirq_DP                  (sirq_DP),           // output
        .sirq_UF                  (sirq_UF),           // output
        .sirq_SDB                 (sirq_SDB),          // output
        .sirq_DS                  (sirq_DS),           // output
        .sirq_PS                  (sirq_PS),           // output
        .sirq_DHR                 (sirq_DHR),          // output
        .serr_DT                  (serr_DT),           // output
        .serr_DS                  (serr_DS),           // output
        .serr_DH                  (serr_DH),           // output
        .serr_DC                  (serr_DC),           // output
        .serr_DB                  (serr_DB),           // output
        .serr_DW                  (serr_DW),           // output
        .serr_DI                  (serr_DI),           // output
        .serr_EP                  (serr_EP),           // output
        .serr_EC                  (serr_EC),           // output
        .serr_ET                  (serr_ET),           // output
        .serr_EM                  (serr_EM),           // output
        .serr_EI                  (serr_EI),           // output
        .serr_diag_X              (serr_diag_X),       // input
        .ssts_ipm_dnp             (ssts_ipm_dnp),      // output
        .ssts_ipm_active          (ssts_ipm_active),   // output
        .ssts_ipm_part            (ssts_ipm_part),     // output
        .ssts_ipm_slumb           (ssts_ipm_slumb),    // output
        .ssts_ipm_devsleep        (ssts_ipm_devsleep), // output
        .ssts_spd_dnp             (ssts_spd_dnp),      // output
        .ssts_spd_gen1            (ssts_spd_gen1),     // output
        .ssts_spd_gen2            (ssts_spd_gen2),     // output
        .ssts_spd_gen3            (ssts_spd_gen3),     // output
        .ssts_det_ndnp            (ssts_det_ndnp),     // output
        .ssts_det_dnp             (ssts_det_dnp),      // output
        .ssts_det_dp              (ssts_det_dp),       // output
        .ssts_det_offline         (ssts_det_offline),  // output
        .ssts_det                 (ssts_det),          // input[3:0]
        .sctl_ipm                 (sctl_ipm),          // input[3:0] 
        .sctl_spd                 (sctl_spd),          // input[3:0] 
        .sctl_det                 (sctl_det),          // input[3:0] 
        .sctl_det_changed         (sctl_det_changed),  // input 
        .sctl_det_reset           (sctl_det_reset),    // output
        .pxci0_clear              (pxci0_clear),       // output
        .pxci0                    (pxci0),             // input

        .dma_prd_done    (dma_prd_done),       // input
        .dma_prd_irq     (dma_prd_irq),        // input
        .dma_cmd_busy    (dma_cmd_busy),       // input
        .dma_cmd_done    (dma_cmd_done),       // input
        
        .fis_first_vld   (frcv_first_vld),     // input
        .fis_type        (d2h_data[7:0]),      // input[7:0] FIS type (low byte in the first FIS DWORD), valid with  'fis_first_vld'
        .bist_bits       (d2h_data[23:16]),    // bits that define built-in self test

        .get_dsfis       (frcv_get_dsfis),     // output
        .get_psfis       (frcv_get_psfis),     // output
        .get_rfis        (frcv_get_rfis),      // output
        .get_sdbfis      (frcv_get_sdbfis),    // output
        .get_ufis        (frcv_get_ufis),      // output
        .get_data_fis    (frcv_get_data_fis),  // output
        .get_ignore      (frcv_get_ignore),    // output
        .get_fis_busy    (frcv_busy),          // input
        .get_fis_done    (frcv_done),          // input
        .fis_ok          (frcv_ok),            // input
        .fis_err         (frcv_err),           // input
        .fis_ferr        (frcv_ferr),          // input
        
        .set_update_sig  (frcv_set_update_sig),// output
        .pUpdateSig      (frcv_pUpdateSig),    // input
        .sig_available   (frcv_sig_available), // input
        .update_sig      (frcv_update_sig),    // output
        
        .update_err_sts  (frcv_update_err_sts),// output
        .update_pio      (frcv_update_pio),    // output 
        .update_prdbc    (frcv_update_prdbc),  // output
        .clear_bsy_drq   (frcv_clear_bsy_drq), // output
        .clear_bsy_set_drq(frcv_clear_bsy_set_drq), //output
        .set_bsy         (frcv_set_bsy),       // output
        .set_sts_7f      (frcv_set_sts_7f),    // output
        .set_sts_80      (frcv_set_sts_80),    // output
        .clear_xfer_cntr (frcv_clear_xfer_cntr), //output Clear pXferCntr
        .decr_dwc        (frcv_decr_dwc),      // output increment pXferCntr after transmit by data transmitted)
//      .decr_DXC_dw     (data_out_dwords),    // output[11:2] **** Probably not needed
        .pxcmd_fre       (pcmd_fre), // input
        
        .pPioXfer        (pPioXfer),           // input      
         
        .tfd_sts         (tfd_sts),            // input[7:0] 
        .tfd_err         (tfd_err),            // input[7:0] 
        .fis_i           (fis_i),              // input
        .sdb_n           (sdb_n),              // input
        .dma_a           (dma_a),              // input
        .dma_d           (dma_d),              // input
        .pio_i           (pio_i),              // input
        .pio_d           (pio_d),              // input
        .pio_es          (pio_es),             // input[7:0] 
        .xfer_cntr       (xfer_cntr[31:2]),    // input[31:2] 
        .xfer_cntr_zero  (xfer_cntr_zero),     // input
        
        .fetch_cmd       (fsnd_fetch_cmd),     // output
        .cfis_xmit       (fsnd_cfis_xmit),     // output
        .dx_transmit     (fsnd_dx_transmit),   // output
        .atapi_xmit      (fsnd_atapi_xmit),    // output
        .xmit_done       (fsnd_done),          // input
        .xmit_busy       (fsnd_busy),          // input
        .clearCmdToIssue (fsnd_clearCmdToIssue),// output // From CFIS:SUCCESS 
        .pCmdToIssue     (fsnd_pCmdToIssue),   // input
        .dx_err          (fsnd_dx_err),        // input[1:0] 
        .ch_prdtl        (prdtl),              // input[15:0] 
        .ch_c            (fsnd_ch_c),          // input
        .ch_b            (fsnd_ch_b),          // input
        .ch_r            (fsnd_ch_r),          // input
        .ch_p            (fsnd_ch_p),          // input
        .ch_w            (fsnd_ch_w),          // input
        .ch_a            (fsnd_ch_a),          // input
        .ch_cfl          (fsnd_ch_cfl),        // input[4:0] 
        .dwords_sent     (data_out_dwords)     // input[11:0] ????
    );



    axi_ahci_regs #(
        .ADDRESS_BITS(10)
    ) axi_ahci_regs_i (
        .aclk             (aclk),            // input
        .arst             (arst),            // input
        .awaddr           (awaddr),          // input[31:0] 
        .awvalid          (awvalid),         // input
        .awready          (awready),         // output
        .awid             (awid),            // input[11:0] 
        .awlen            (awlen),           // input[3:0] 
        .awsize           (awsize),          // input[1:0] 
        .awburst          (awburst),         // input[1:0] 
        .wdata            (wdata),           // input[31:0] 
        .wvalid           (wvalid),          // input
        .wready           (wready),          // output
        .wid              (wid),             // input[11:0] 
        .wlast            (wlast),           // input
        .wstb             (wstb),            // input[3:0] 
        .bvalid           (bvalid),          // output
        .bready           (bready),          // input
        .bid              (bid),             // output[11:0] 
        .bresp            (bresp),           // output[1:0] 
        .araddr           (araddr),          // input[31:0] 
        .arvalid          (arvalid),         // input
        .arready          (arready),         // output
        .arid             (arid),            // input[11:0] 
        .arlen            (arlen),           // input[3:0] 
        .arsize           (arsize),          // input[1:0] 
        .arburst          (arburst),         // input[1:0] 
        .rdata            (rdata),           // output[31:0] 
        .rvalid           (rvalid),          // output
        .rready           (rready),          // input
        .rid              (rid),             // output[11:0] 
        .rlast            (rlast),           // output
        .rresp            (rresp),           // output[1:0] 
        .soft_write_addr  (soft_write_addr), // output[9:0] 
        .soft_write_data  (soft_write_data), // output[31:0] 
        .soft_write_en    (soft_write_en),   // output
        .hba_arst         (hba_arst),        // output // does not include arst
        .port_arst        (port_arst),       // output // does not include arst
        .hba_clk          (mclk),            // input
        .hba_rst          (mrst),            // input   // deasserted when mclk is stable
        .hba_addr         (regs_addr),       // input[9:0] 
        .hba_we           (regs_we),         // input
        .hba_re           (regs_re),         // input[1:0] 
        .hba_din          (regs_din),        // input[31:0] 
        .hba_dout         (regs_dout),       // output[31:0] 
        .pgm_ad           (fsm_pgm_ad),      // output[17:0] reg 
        .pgm_wa           (fsm_pgm_wa),      // output reg 
        .pgm_wd           (fsm_pgm_wd),      // output reg 
        .afi_wcache       (axi_wr_cache_mode),// output[3:0] reg 
        .afi_rcache       (axi_rd_cache_mode),// output[3:0] reg 
        .afi_cache_set    (set_axi_cache_mode), // output
        .was_hba_rst      (was_hba_rst),     // output 
        .was_port_rst     (was_port_rst)     // output 
        
        
    );

    ahci_ctrl_stat #(
        .ADDRESS_BITS            (ADDRESS_BITS)
    ) ahci_ctrl_stat_i (
        .mrst                    (mrst),                    // input
        .mclk                    (mclk),                    // input
        .was_hba_rst             (was_hba_rst),             // input
        .was_port_rst            (was_port_rst),            // input
        .soft_write_addr         (soft_write_addr),         // input[9:0] 
        .soft_write_data         (soft_write_data),         // input[31:0] 
        .soft_write_en           (soft_write_en),           // input
        .regs_addr               (regs_saddr),              // output[9:0] reg 
        .regs_we                 (regs_we_acs),             // output reg 
        .regs_din                (regs_din_from_acs),       // output[31:0] reg 
        .update_pending          (update_regs_pending),     // output
        .update_all              (update_all_regs),         // input
        .update_busy             (update_regs_busy),        // output
        .st01_pending            (st01_pending),            // output reg 
        .st10_pending            (st10_pending),            // output reg 
        .st_pending_reset        (st_pending_reset),        // input
        
        .update_gis              (update_GHC__IS),          // input
        .update_pis              (update_HBA_PORT__PxIS),   // input
        .update_ssts             (update_HBA_PORT__PxSSTS), // input
        .update_serr             (update_HBA_PORT__PxSERR), // input
        .update_pcmd             (update_HBA_PORT__PxCMD),  // input
        .update_pci              (update_HBA_PORT__PxCI),   // input
        .pcmd_clear_icc          (pcmd_clear_icc),          // input
        .pcmd_esp                (pcmd_esp),                // input
        .pcmd_cr                 (pcmd_cr),                 // output
        .pcmd_cr_set             (pcmd_cr_set),             // input
        .pcmd_cr_reset           (pcmd_cr_reset),           // input
        .pcmd_fr                 (pcmd_fr),                 // input
        .pcmd_fre                (pcmd_fre),                // output
        .pcmd_clear_bsy_drq      (pcmd_clear_bsy_drq),      // input
        .pcmd_clo                (pcmd_clo),                // output
        .pcmd_clear_st           (pcmd_clear_st),           // input
        .pcmd_st                 (pcmd_st),                 // output
        .pfsm_started            (pfsm_started),            // input
        .pcmd_st_cleared         (pcmd_st_cleared),         // output reg 
        .sirq_TFE                (sirq_TFE),                // input
        .sirq_IF                 (sirq_IF),                 // input
        .sirq_INF                (sirq_INF),                // input
        .sirq_OF                 (sirq_OF),                 // input
        .sirq_PRC                (sirq_PRC),                // input
        .sirq_PC                 (sirq_PC),                 // input
        .sirq_DP                 (sirq_DP),                 // input
        .sirq_UF                 (sirq_UF),                 // input
        .sirq_SDB                (sirq_SDB),                // input
        .sirq_DS                 (sirq_DS),                 // input
        .sirq_PS                 (sirq_PS),                 // input
        .sirq_DHR                (sirq_DHR),                // input
        .serr_DT                 (serr_DT),                 // input
        .serr_DS                 (serr_DS),                 // input
        .serr_DH                 (serr_DH),                 // input
        .serr_DC                 (serr_DC),                 // input
        .serr_DB                 (serr_DB),                 // input
        .serr_DW                 (serr_DW),                 // input
        .serr_DI                 (serr_DI),                 // input
        .serr_EP                 (serr_EP),                 // input
        .serr_EC                 (serr_EC),                 // input
        .serr_ET                 (serr_ET),                 // input
        .serr_EM                 (serr_EM),                 // input
        .serr_EI                 (serr_EI),                 // input
        .serr_diag_X             (serr_diag_X),             // output
        .ssts_ipm_dnp            (ssts_ipm_dnp),            // input
        .ssts_ipm_active         (ssts_ipm_active),         // input
        .ssts_ipm_part           (ssts_ipm_part),           // input
        .ssts_ipm_slumb          (ssts_ipm_slumb),          // input
        .ssts_ipm_devsleep       (ssts_ipm_devsleep),       // input
        .ssts_spd_dnp            (ssts_spd_dnp),            // input
        .ssts_spd_gen1           (ssts_spd_gen1),           // input
        .ssts_spd_gen2           (ssts_spd_gen2),           // input
        .ssts_spd_gen3           (ssts_spd_gen3),           // input
        .ssts_det_ndnp           (ssts_det_ndnp),           // input
        .ssts_det_dnp            (ssts_det_dnp),            // input
        .ssts_det_dp             (ssts_det_dp),             // input
        .ssts_det_offline        (ssts_det_offline),        // input
        .ssts_det                (ssts_det),                // output[3:0]
        .sctl_ipm                (sctl_ipm),                // output[3:0] reg 
        .sctl_spd                (sctl_spd),                // output[3:0] reg 
        .sctl_det                (sctl_det),                // output[3:0] reg
        .sctl_det_changed        (sctl_det_changed),        // output reg 
        .sctl_det_reset          (sctl_det_reset),          // input
        .pxci0_clear             (pxci0_clear),             // input
        .pxci0                   (pxci0),                   // output
        .irq                     (irq)                      // output reg 
    );

    ahci_dma ahci_dma_i (
        .mrst                  (mrst),          // input
        .hrst                  (hrst),          // input
        .mclk                  (mclk),          // input
        .hclk                  (hclk),          // input
        .ctba                  (regs_dout[31:7]),// input[31:7] 
        .ctba_ld               (ctba_ld),       // input
        .prdtl                 (prdtl),         // input[15:0] 
        .dev_wr                (dev_wr),        // input
        .cmd_start             (dma_cmd_start), // input
        .prd_start             (dma_prd_start), // input
        .cmd_abort             (dma_cmd_abort), // input
        .axi_wr_cache_mode     (axi_wr_cache_mode), // input[3:0] 
        .axi_rd_cache_mode     (axi_rd_cache_mode), // input[3:0] 
        .set_axi_wr_cache_mode (set_axi_cache_mode), // input
        .set_axi_rd_cache_mode (set_axi_cache_mode), // input
        .ct_busy               (dma_ct_busy),   // output reg 
        .ct_addr               (dma_ct_addr),   // input[4:0] 
        .ct_re                 (dma_ct_re[0]),  // input
        .ct_data               (dma_ct_data),   // output[31:0] reg 
        .prd_done              (dma_prd_done),  // output
        .prd_irq               (dma_prd_irq),   // output
        .cmd_busy              (dma_cmd_busy),  // output reg 
        .cmd_done              (dma_cmd_done),  // output
        .sys_out               (dma_dout),      // output[31:0] 
        .sys_dav               (dma_dav),       // output
        .sys_re                (dma_re),        // input
        .sys_in                (d2h_data),      // input[31:0] 
        .sys_nfull             (dma_in_ready),  // output
        .sys_we                (dma_we),        // input

        .afi_awaddr        (afi_awaddr),        // output[31:0] 
        .afi_awvalid       (afi_awvalid),       // output
        .afi_awready       (afi_awready),       // input
        .afi_awid          (afi_awid),          // output[5:0] 
        .afi_awlock        (afi_awlock),        // output[1:0] 
        .afi_awcache       (afi_awcache),       // output[3:0] reg 
        .afi_awprot        (afi_awprot),        // output[2:0] 
        .afi_awlen         (afi_awlen),         // output[3:0] 
        .afi_awsize        (afi_awsize),        // output[1:0] 
        .afi_awburst       (afi_awburst),       // output[1:0] 
        .afi_awqos         (afi_awqos),         // output[3:0] 
        .afi_wdata         (afi_wdata),         // output[63:0] 
        .afi_wvalid        (afi_wvalid),        // output
        .afi_wready        (afi_wready),        // input
        .afi_wid           (afi_wid),           // output[5:0] 
        .afi_wlast         (afi_wlast),         // output
        .afi_wstrb         (afi_wstrb),         // output[7:0] 
        .afi_bvalid        (afi_bvalid),        // input
        .afi_bready        (afi_bready),        // output
        .afi_bid           (afi_bid),           // input[5:0] 
        .afi_bresp         (afi_bresp),         // input[1:0] 
        .afi_wcount        (afi_wcount),        // input[7:0] 
        .afi_wacount       (afi_wacount),       // input[5:0] 
        .afi_wrissuecap1en (afi_wrissuecap1en), // output
        .afi_araddr        (afi_araddr),        // output[31:0] 
        .afi_arvalid       (afi_arvalid),       // output
        .afi_arready       (afi_arready),       // input
        .afi_arid          (afi_arid),          // output[5:0] 
        .afi_arlock        (afi_arlock),        // output[1:0] 
        .afi_arcache       (afi_arcache),       // output[3:0] reg 
        .afi_arprot        (afi_arprot),        // output[2:0] 
        .afi_arlen         (afi_arlen),         // output[3:0] 
        .afi_arsize        (afi_arsize),        // output[1:0] 
        .afi_arburst       (afi_arburst),       // output[1:0] 
        .afi_arqos         (afi_arqos),         // output[3:0] 
        .afi_rdata         (afi_rdata),         // input[63:0] 
        .afi_rvalid        (afi_rvalid),        // input
        .afi_rready        (afi_rready),        // output
        .afi_rid           (afi_rid),           // input[5:0] 
        .afi_rlast         (afi_rlast),         // input
        .afi_rresp         (afi_rresp),         // input[1:0] 
        .afi_rcount        (afi_rcount),        // input[7:0] 
        .afi_racount       (afi_racount),       // input[2:0] 
        .afi_rdissuecap1en (afi_rdissuecap1en)  // output
    );

    ahci_fis_receive #(
        .ADDRESS_BITS      (ADDRESS_BITS)
    ) ahci_fis_receive_i (
        .hba_rst           (mrst),                   // input
        .mclk              (mclk),                   // input
        
        .fis_first_vld     (frcv_first_vld),         // output reg 

        .get_dsfis         (frcv_get_dsfis),         // input
        .get_psfis         (frcv_get_psfis),         // input
        .get_rfis          (frcv_get_rfis),          // input
        .get_sdbfis        (frcv_get_sdbfis),        // input
        .get_ufis          (frcv_get_ufis),          // input
        .get_data_fis      (frcv_get_data_fis),      // input
        .get_ignore        (frcv_get_ignore),        // input
        
        .get_fis_busy      (frcv_busy),              // output reg 
        .get_fis_done      (frcv_done),              // output reg 
        .fis_ok            (frcv_ok),                // output reg 
        .fis_err           (frcv_err),               // output reg 
        .fis_ferr          (frcv_ferr),              // output

        .set_update_sig    (frcv_set_update_sig),    // input
        .pUpdateSig        (frcv_pUpdateSig),        // output
        .sig_available     (frcv_sig_available),     // output reg 
        .update_sig        (frcv_update_sig),        // input
        
        .update_err_sts    (frcv_update_err_sts),    // input
        .update_pio        (frcv_update_pio),        // input  update PxTFD.STS and PxTFD.ERR from pio_* (entry PIO:Update)
        
        .update_prdbc      (frcv_update_prdbc),      // input
        .clear_bsy_drq     (frcv_clear_bsy_drq),     // input
        .clear_bsy_set_drq (frcv_clear_bsy_set_drq), // input
        
        .set_bsy           (frcv_set_bsy),           // input
        .set_sts_7f        (frcv_set_sts_7f),        // input
        .set_sts_80        (frcv_set_sts_80),        // input
        .clear_xfer_cntr (frcv_clear_xfer_cntr),     // input Clear pXferCntr
        .decr_dwc          (frcv_decr_dwc),          // input
        .decr_DXC_dw       (data_out_dwords),        // input[11:2]
        .pcmd_fre          (pcmd_fre),               // input
         
        .pPioXfer          (pPioXfer),               // output reg 
        
        .tfd_sts           (tfd_sts),                // output[7:0] 
        .tfd_err           (tfd_err),                // output[7:0] 
        .fis_i             (fis_i),                  // output reg 
        .sdb_n             (sdb_n),                  // output reg 
        .dma_a             (dma_a),                  // output reg 
        .dma_d             (dma_d),                  // output reg 
        .pio_i             (pio_i),                  // output reg 
        .pio_d             (pio_d),                  // output reg 
        .pio_es            (pio_es),                 // output[7:0] reg 
        .xfer_cntr         (xfer_cntr[31:2]),        // output[31:2] 
        .xfer_cntr_zero    (xfer_cntr_zero),         // output reg
        .data_in_dwords    (data_in_dwords),         // output[11:0] 
         
        .reg_addr          (regs_waddr),             // output[9:0] reg 
        .reg_we            (regs_we_freceive),       // output reg 
        .reg_data          (regs_din_from_freceive), // output[31:0] reg 
        .hba_data_in       (d2h_data),               // input[31:0] 
        .hba_data_in_type  (d2h_type),               // input[1:0] 
        .hba_data_in_valid (d2h_valid),              // input
        .hba_data_in_many  (d2h_many),               // input
        .hba_data_in_ready (d2h_ready),              // output
        .dma_in_ready      (dma_in_ready),           // input
        .dma_in_valid      (dma_we)                  // output
    );

    ahci_fis_transmit #(
        .PREFETCH_ALWAYS  (PREFETCH_ALWAYS),
        .READ_REG_LATENCY (READ_REG_LATENCY),
        .READ_CT_LATENCY  (READ_CT_LATENCY),
        .ADDRESS_BITS     (ADDRESS_BITS)
    ) ahci_fis_transmit_i (
        .hba_rst           (mrst),                 // input
        .mclk              (mclk),                 // input

        .fetch_cmd         (fsnd_fetch_cmd),       // input
        .cfis_xmit         (fsnd_cfis_xmit),       // input
        .dx_transmit       (fsnd_dx_transmit),     // input
        .atapi_xmit        (fsnd_atapi_xmit),      // input
        
        .done              (fsnd_done),            // output reg 
        .busy              (fsnd_busy),            // output reg 
        .clearCmdToIssue   (fsnd_clearCmdToIssue), // input
        .pCmdToIssue       (fsnd_pCmdToIssue),     // output
        .syncesc_recv      (syncesc_recv),         // input
        .xmit_err          (xmit_err),             // input
        .dx_err            (fsnd_dx_err),          // output[1:0] 
        .ch_prdtl          (prdtl),                // output[15:0]
        .ch_c              (fsnd_ch_c),            // output
        .ch_b              (fsnd_ch_b),            // output
        .ch_r              (fsnd_ch_r),            // output
        .ch_p              (fsnd_ch_p),            // output
        .ch_w              (fsnd_ch_w),            // output
        .ch_a              (fsnd_ch_a),            // output
        .ch_cfl            (fsnd_ch_cfl),          // output[4:0] 

        .dwords_sent       (data_out_dwords),      // output[11:0] reg
        .reg_addr          (regs_raddr),           // output[9:0] reg 
        .reg_re            (regs_re_ftransmit),    // output[1:0]
        .reg_rdata         (regs_dout),            // input[31:0] 
        .xfer_cntr         (xfer_cntr[31:2]),      // input[31:2] 
        .dma_ctba_ld       (ctba_ld),              // output
        .dma_start         (dma_cmd_start),        // output
        .dma_dev_wr        (dev_wr),               // output
        .dma_ct_busy       (dma_ct_busy),          // input
        .dma_prd_start     (dma_prd_start),        // output reg 
        .dma_cmd_abort     (dma_cmd_abort),        // output reg 
        .ct_addr           (dma_ct_addr),          // output[4:0] reg 
        .ct_re             (dma_ct_re),            // output[1:0]
        .ct_data           (dma_ct_data),          // input[31:0] 
        .dma_out           (dma_dout),             // input[31:0] 
        .dma_dav           (dma_dav),              // input
        .dma_re            (dma_re),               // output
        .todev_data        (h2d_data),             // output[31:0] reg 
        .todev_type        (h2d_type),             // output[1:0] reg 
        .todev_valid       (h2d_valid),            // output
        .todev_ready       (h2d_ready)             // input
    );


endmodule

