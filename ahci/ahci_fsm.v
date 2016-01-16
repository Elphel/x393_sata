/*******************************************************************************
 * Module: ahci_fsm
 * Date:2016-01-10  
 * Author: andrey     
 * Description: AHCI host+port0 state machine
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_fsm.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_fsm.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_fsm 
/*#(
//    parameter PREFETCH_ALWAYS =   0,
    parameter READ_REG_LATENCY =  2, // 0 if  reg_rdata is available with reg_re/reg_addr, 2 with re/regen
//    parameter READ_CT_LATENCY =   1, // 0 if  ct_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter ADDRESS_BITS =     10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)
) */
(
    input                         hba_rst, // @posedge mclk
    input                         mclk, // for command/status
    input                         was_hba_rst,    // last reset was hba reset (not counting system reset)
    input                         was_port_rst,   // last reset was port reset
    
    // Writing FSM program memory
    input                         aclk,
    input                         arst,
    input                  [17:0] pgm_ad, // @aclk, address/data to program the AHCI FSM
    input                         pgm_wa,  // @aclk, address strobe to program the AHCI FSM
    input                         pgm_wd,  // @aclk, data strobe to program the AHCI FSM

    
    // direct communication with transposrt, link and phy layers
    input                         phy_ready,     // goes up after comreset,cominit, align, ...
    output                        syncesc_send,  // Send sync escape
    input                         cominit_got,   // asynchronously jumps to P:Cominit state
    output                        set_offline, // electrically idle
    output                        send_R_OK,    // Should it be originated in this layer SM?
    output                        send_R_ERR,
    
    // Other signals....
    
    // Communication with ahci_ctrl_stat (some are not needed)
    // update register inputs (will write to register memory current value of the corresponding register)
    output                        pfsm_started, // H: FSM doene, P: FSM started (enable sensing pcmd_st_cleared)
    // update register inputs (will write to register memory current value of the corresponding register)
    input                         update_pending,
    output                        update_all,
    input                         update_busy, // valid same cycle as update_all
    output                        update_gis,  // these following individual may be unneeded - just use universal update_all
    output                        update_pis,
    output                        update_ssts,
    output                        update_serr,
    output                        update_pcmd,
    output                        update_pci,
    input                         st01_pending,    // software turned PxCMD.ST from 0 to 1
    input                         st10_pending,    // software turned PxCMD.ST from 1 to 0
    output                        st_pending_reset,// reset both st01_pending and st10_pending

// PxCMD
    output                        pcmd_clear_icc, // clear PxCMD.ICC field
    output                        pcmd_esp,       // external SATA port (just forward value)
    input                         pcmd_cr,        // command list run - current
    output                        pcmd_cr_set,    // command list run set
    output                        pcmd_cr_reset,  // command list run reset
    output                        pcmd_fr,        // ahci_fis_receive:get_fis_busy
    output                        pcmd_clear_bsy_drq, // == ahci_fis_receive:clear_bsy_drq
    input                         pcmd_clo,       //RW1, causes ahci_fis_receive:clear_bsy_drq, that in turn resets this bit
    output                        pcmd_clear_st,  // RW clear ST (start) bit
    input                         pcmd_st,        // current value
    input                         pcmd_st_cleared,// ST bit cleared by software;
    
//clear_bsy_drq    
// Interrupt inputs
    output                        sirq_TFE, // RWC: Task File Error Status
    output                        sirq_IF,  // RWC: Interface Fatal Error Status (sect. 6.1.2)
    output                        sirq_INF, // RWC: Interface Non-Fatal Error Status (sect. 6.1.2)
    output                        sirq_OF,  // RWC: Overflow Status
    output                        sirq_PRC, // RO:  PhyRdy changed Status
    output                        sirq_PC,  // RO:  Port Connect Change Status
    output                        sirq_DP,  // RWC: Descriptor Processed with "I" bit on
    output                        sirq_UF,  // RO:  Unknown FIS
    output                        sirq_SDB, // RWC: Set Device Bits Interrupt - Set Device bits FIS with 'I' bit set
    output                        sirq_DS,  // RWC: DMA Setup FIS Interrupt - DMA Setup FIS received with 'I' bit set
    output                        sirq_PS,  // RWC: PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set
    output                        sirq_DHR, // RWC: D2H Register FIS Interrupt - D2H Register FIS received with 'I' bit set
// SCR1:SError (only inputs that are not available in sirq_* ones
                                  //sirq_PC,
                                  //sirq_UF
    output                        serr_DT,   // RWC: Transport state transition error
    output                        serr_DS,   // RWC: Link sequence error
    output                        serr_DH,   // RWC: Handshake Error (i.e. Device got CRC error)
    output                        serr_DC,   // RWC: CRC error in Link layer
    output                        serr_DB,   // RWC: 10B to 8B decode error
    output                        serr_DW,   // RWC: COMMWAKE signal was detected
    output                        serr_DI,   // RWC: PHY Internal Error
                                  // sirq_PRC,
                                  // sirq_IF || // sirq_INF  
    output                        serr_EP,   // RWC: Protocol Error - a violation of SATA protocol detected
    output                        serr_EC,   // RWC: Persistent Communication or Data Integrity Error
    output                        serr_ET,   // RWC: Transient Data Integrity Error (error not recovered by the interface)
    output                        serr_EM,   // RWC: Communication between the device and host was lost but re-established
    output                        serr_EI,   // RWC: Recovered Data integrity Error
    input                         serr_diag_X, // value of PxSERR.DIAG.X

     
    
// SCR0: SStatus
    output                        ssts_ipm_dnp,      // device not present or communication not established
    output                        ssts_ipm_active,   // device in active state
    output                        ssts_ipm_part,     // device in partial state
    output                        ssts_ipm_slumb,    // device in slumber state
    output                        ssts_ipm_devsleep, // device in DevSleep state
    
    output                        ssts_spd_dnp,      // device not present or communication not established
    output                        ssts_spd_gen1,     // Gen 1 rate negotiated
    output                        ssts_spd_gen2,     // Gen 2 rate negotiated
    output                        ssts_spd_gen3,     // Gen 3 rate negotiated
    
    output                        ssts_det_ndnp,     // no device detected, phy communication not established
    output                        ssts_det_dnp,      // device detected, but phy communication not established
    output                        ssts_det_dp,       // device detected, phy communication established
    output                        ssts_det_offline,  // device detected, phy communication established

 // SCR2:SControl (written by software only)
    input                   [3:0] sctl_ipm,          // Interface power management transitions allowed
    input                   [3:0] sctl_spd,          // Interface maximal speed
    input                   [3:0] sctl_det,          // Device detection initialization requested
    input                         sctl_det_changed,  // Software had written new value to sctl_det
    output                        sctl_det_reset,    // clear sctl_det_changed
    
    output                        pxci0_clear,       // PxCI clear
    input                         pxci0,             // pxCI current value
    
    // inputs from the DMA engine
    input                         dma_prd_done, // output (finished next prd)
    input                         dma_prd_irq, // output (finished next prd and prd irq is enabled)
    input                         dma_cmd_busy, // output reg (DMA engine is processing PRDs)
    input                         dma_cmd_done, // output (last PRD is over)
    
    // Communication with ahci_fis_receive (some are unused
    input                         fis_first_vld, // fis_first contains valid FIS header, reset by 'get_*'
    input                   [7:0] fis_type,      // FIS type (low byte in the first FIS DWORD), valid with  'fis_first_vld'
    // Receiving FIS
    output                        set_update_sig, // when set, enables get_sig (and resets itself)
    input                         pUpdateSig,     // state variable
    
    output                        get_sig,        // update signature
    output                        get_dsfis,
    output                        get_psfis,
    output                        get_rfis,
    output                        get_sdbfis,
    output                        get_ufis,
    output                        get_data_fis,
    output                        get_ignore,    // ignore whatever FIS (use for DMA activate too?)
    input                         get_fis_busy,  // busy processing FIS 
    input                         get_fis_done,  // done processing FIS (see fis_ok, fis_err, fis_ferr)
    input                         fis_ok,        // FIS done,  checksum OK reset by starting a new get FIS
    input                         fis_err,       // FIS done, checksum ERROR reset by starting a new get FIS
    input                         fis_ferr,      // FIS done, fatal error - FIS too long
    // next commands use register address/data/we for 1 clock cycle - after next to command (commnd - t0, we - t2)
    output                        update_err_sts,// update PxTFD.STS and PxTFD.ERR from the last received regs d2h
    output                        update_pio,    // update PxTFD.STS and PxTFD.ERR from pio_* (entry PIO:Update)
    
    output                        update_prdbc,  // update PRDBC in registers
    output                        clear_bsy_drq, // clear PxTFD.STS.BSY and PxTFD.STS.DRQ, update
    output                        clear_bsy_set_drq, // clear PxTFD.STS.BSY and sets PxTFD.STS.DRQ, update
    
    output                        set_bsy,       // set PxTFD.STS.BSY, update
    output                        set_sts_7f,    // set PxTFD.STS = 0x7f, update
    output                        set_sts_80,    // set PxTFD.STS = 0x80 (may be combined with set_sts_7f), update
    output                        clear_xfer_cntr, // clear pXferCntr (is it needed as a separate input)?
    
    output                        decr_dwc,      // decrement DMA Xfer counter // need pulse to 'update_prdbc' to write to registers
//    output                 [11:0] decr_DXC_dw,   // decrement value (in DWORDs)
    input                         pxcmd_fre,     // control bit enables saving FIS to memory
    input                         pPioXfer,      // state variable
    input                   [7:0] tfd_sts,       // Current PxTFD status field (updated after regFIS and SDB - certain fields)
                                                 // tfd_sts[7] - BSY, tfd_sts[4] - DRQ, tfd_sts[0] - ERR
    input                   [7:0] tfd_err,       // Current PxTFD error field (updated after regFIS and SDB)
    input                         fis_i,         // value of "I" field in received regsD2H or SDB FIS
    input                         sdb_n,         // value of "N" field in received SDB FIS 
    input                         dma_a,         // value of "A" field in received DMA Setup FIS 
    input                         dma_d,         // value of "D" field in received DMA Setup FIS
    input                         pio_i,         // value of "I" field in received PIO Setup FIS
    input                         pio_d,         // value of "D" field in received PIO Setup FIS
    input                   [7:0] pio_es,        // value of PIO E_Status
    // Using even word count (will be rounded up), partial DWORD (last) will be handled by PRD length if needed
    input                  [31:2] xfer_cntr,     // transfer counter in words for both DMA (31 bit) and PIO (lower 15 bits), updated after decr_dwc
    input                         xfer_cntr_zero,// valid next cycle                   
    
    // Communication with ahci_fis_transmit
    // Command pulses to execute states
    output                        fetch_cmd,   // Enter p:FetchCmd, fetch command header (from the register memory, prefetch command FIS)
                                               // wait for either fetch_cmd_busy == 0 or pCmdToIssue ==1 after fetch_cmd
    output                        cfis_xmit,    // transmit command (wait for dma_ct_busy == 0)
    output                        dx_transmit,  // send FIS header DWORD, (just 0x46), then forward DMA data
                                                // transmit until error, 2048DWords or pDmaXferCnt 
    output                        atapi_xmit,   // tarsmit ATAPI command FIS
    input                         xmit_done,
    input                         xmit_busy,

    output                        clearCmdToIssue, // From CFIS:SUCCESS 
    input                         pCmdToIssue, // AHCI port variable
//    output                        dmaCntrZero, // DMA counter is zero - would be a duplicate to the one in receive module and dwords_sent output
//    input                         syncesc_recv, // These two inputs interrupt transmit
//    input                         xmit_err,     // 
    input                  [ 1:0] dx_err,       // bit 0 - syncesc_recv, 1 - xmit_err  (valid @ xmit_err and later, reset by new command)
    
    input                  [15:0] ch_prdtl,    // Physical region descriptor table length (in entries, 0 is 0)
    input                         ch_c,        // Clear busy upon R_OK for this FIS
    input                         ch_b,        // Built-in self test command
    input                         ch_r,        // reset - may need to send SYNC escape before this command
    input                         ch_p,        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    input                         ch_w,        // Write: system memory -> device
    input                         ch_a,        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    input                   [4:0] ch_cfl,      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal,
                                               // maximal is 16 (0x10)
    input                  [11:0] dwords_sent // number of DWORDs transmitted (up to 2048)                                 

);
`include "includes/ahci_localparams.vh" // @SuppressThisWarning VEditor : Unused localparams
    reg                     [10:0] pgm_waddr;
//    wire                           pgm_ren;
//    wire                           pgm_regen;
    wire                           cond_met_w; // calculated from signals and program conditions decoder
    reg                     [10:0] pgm_jump_addr;
    reg                     [10:0] pgm_addr;
    wire                    [17:0] pgm_data;
    reg                            was_rst;
//    reg                            jump_r; 
    reg                      [2:0] fsm_jump;
    wire                           fsm_next;
    reg                            fsm_actions;     // processing actions
    reg                            fsm_act_busy;
    reg                      [1:0] fsm_transitions; // processing transitions
    reg                            fsm_preload;    // read first sequence data (2 cycles for regen)
    wire                     [6:0] precond_w = pgm_data[17:11];   // select what to use - cond_met_w valis after precond_w, same time as conditions
    reg                      [6:0] conditions;
    wire                           pre_jump_w =   (|async_pend_r) ? async_ackn : (cond_met_w & fsm_transitions[1]);
    wire                           fsm_act_done = get_fis_done || xmit_done;
    wire                           fsm_wait_act_w = pgm_data[16]; // this action requires waiting for done
    wire                           fsm_last_act_w = pgm_data[17];

    wire                           fsm_pre_act_w = fsm_actions && fsm_next; // use it as CS for generated actions (registered)
    
    reg                      [1:0] async_pend_r; // waiting to process cominit_got
    reg                            async_from_st; // chnge to multi-bit if there will be more sources for async transitions
    wire                           asynq_rq = cominit_got || pcmd_st_cleared;
    wire                           async_ackn = !fsm_preload && async_pend_r[0] && ((fsm_actions && !update_busy && !fsm_act_busy) || fsm_transitions[0]);   // OK to process async jump
    
    

    assign fsm_next = (fsm_preload || (fsm_actions && !update_busy && !fsm_act_busy) || fsm_transitions[0]) && !async_pend_r[0]; // quiet if received cominit is pending

    // Writing to the FSM program memory
    always @ (posedge aclk) begin
        if      (arst)   pgm_waddr <= 0;
        else if (pgm_wa) pgm_waddr <= pgm_ad[10:0];
        else if (pgm_wd) pgm_waddr <=  pgm_waddr + 1;
    end
    // Reset addresses - later use generated
    localparam LABEL_POR =        11'h000;
    localparam LABEL_HBA_RST =    11'h002;
    localparam LABEL_PORT_RST =   11'h004;
    localparam LABEL_COMINIT =    11'h006;
    localparam LABEL_ST_CLEARED = 11'h008;

    always @ (posedge mclk) begin
        if      (hba_rst)                                                    pgm_jump_addr <= (was_hba_rst || was_port_rst) ? (was_hba_rst? LABEL_HBA_RST:LABEL_PORT_RST) : LABEL_POR;
        else if (async_pend_r[1])                                            pgm_jump_addr <= async_from_st? LABEL_ST_CLEARED : LABEL_COMINIT;
        else if (fsm_transitions[0] && (!cond_met_w || !fsm_transitions[1])) pgm_jump_addr <= pgm_data[10:0];
        
        was_rst <= hba_rst;
               
        fsm_jump <= {fsm_jump[1:0], pre_jump_w | (was_rst & ~hba_rst)};
        
        if   (fsm_jump[0]) pgm_addr <= pgm_jump_addr;
        else if (fsm_next) pgm_addr <= pgm_addr + 1;
        
        if            (hba_rst) conditions <= 0; 
        if (fsm_transitions[0]) conditions <= precond_w;
        
        if      (hba_rst)                                   fsm_actions <= 0;
        else if (fsm_jump[2])                               fsm_actions <= 1;
        else if (fsm_last_act_w && fsm_next)                fsm_actions <= 0;
        
        
        
        if      (hba_rst || pre_jump_w)                     fsm_transitions <= 0;
        else if (fsm_last_act_w && fsm_actions && fsm_next) fsm_transitions <= 1;
        else                                                fsm_transitions <= {fsm_transitions[0],fsm_transitions[0]};
        
        if (hba_rst) fsm_preload <= 0;
        else         fsm_preload <= |fsm_jump[1:0];
        
        if      (hba_rst)       fsm_act_busy <= 0;
        else if (fsm_pre_act_w) fsm_act_busy <= fsm_wait_act_w;
        else if (fsm_act_done)  fsm_act_busy <= 0;
        
        if (pcmd_st_cleared) async_from_st <= 1;
        else if   (asynq_rq) async_from_st <= 0;
        
        if (hba_rst) async_pend_r <= 0;
        else async_pend_r <= {async_pend_r[0], asynq_rq | (async_pend_r[0] & ~async_ackn)};  
        
    end

/*
sequence = [{LBL:'POR',      ADR: 0x0,  ACT: NOP},
            {                           GOTO:'H:Init'},
            {LBL:'HBA_RST',  ADR: 0x2,  ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'PORT_RST', ADR: 0x4,  ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'COMINIT',  ADR: 0x6, ACT: NOP},
            {                           GOTO:'P:Cominit'},
            

*/

    ramp_var_w_var_r #(
        .REGISTERS(1),
        .LOG2WIDTH_WR(4),
        .LOG2WIDTH_RD(4)
    ) fsm_pgm_mem_i (
        .rclk     (mclk),      // input
        .raddr    (pgm_addr),  // input[10:0] 
        .ren      (fsm_next),  // input
        .regen    (fsm_next),  // input
        .data_out (pgm_data),  // output[17:0] 
        .wclk     (aclk),      // input
        .waddr    (pgm_waddr), // input[10:0] 
        .we       (pgm_wd),    // input
        .web      (8'hff),     // input[7:0] 
        .data_in  (pgm_ad)     // input[17:0] 
    );



/*
    output                        update_all,
    input                         update_busy, // valid same cycle as update_all


Notes:
 Implement sync esc request/ackn in TL (available in LL)
*/
endmodule

