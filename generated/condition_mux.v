/*******************************************************************************
 * Module: condition_mux
 * Date:2016-01-22  
 * Author: auto-generated file, see ahci_fsm_sequence.py
 * Description: Select condition
 *******************************************************************************/

`timescale 1ns/1ps

module condition_mux (
    input        clk,
    input [ 7:0] sel,
    output       condition,
    input        ST_NB_ND,
    input        PXCI0_NOT_CMDTOISSUE,
    input        PCTI_CTBAR_XCZ,
    input        PCTI_XCZ,
    input        NST_D2HR,
    input        NPD_NCA,
    input        CHW_DMAA,
    input        SCTL_DET_CHANGED_TO_4,
    input        SCTL_DET_CHANGED_TO_1,
    input        PXSSTS_DET_NE_3,
    input        PXSSTS_DET_EQ_1,
    input        NPCMD_FRE,
    input        FIS_OK,
    input        FIS_ERR,
    input        FIS_FERR,
    input        FIS_EXTRA,
    input        FIS_FIRST_INVALID,
    input        FR_D2HR,
    input        FIS_DATA,
    input        FIS_ANY,
    input        NB_ND_D2HR_PIO,
    input        D2HR,
    input        SDB,
    input        DMA_ACT,
    input        DMA_SETUP,
    input        BIST_ACT_FE,
    input        BIST_ACT,
    input        PIO_SETUP,
    input        NB_ND,
    input        TFD_STS_ERR,
    input        FIS_I,
    input        PIO_I,
    input        NPD,
    input        PIOX,
    input        XFER0,
    input        PIOX_XFER0,
    input        CTBAA_CTBAP,
    input        CTBAP,
    input        CTBA_B,
    input        CTBA_C,
    input        TX_ERR,
    input        SYNCESC_ERR,
    input        DMA_PRD_IRQ_PEND,
    input        X_RDY_COLLISION);

    wire [44:0] masked;
    reg  [ 5:0] cond_r;

    assign condition = |cond_r;

    assign masked[ 0] = ST_NB_ND               && sel[ 2] && sel[ 1] && sel[ 0];
    assign masked[ 1] = PXCI0_NOT_CMDTOISSUE   && sel[ 3] && sel[ 1] && sel[ 0];
    assign masked[ 2] = PCTI_CTBAR_XCZ         && sel[ 4] && sel[ 1] && sel[ 0];
    assign masked[ 3] = PCTI_XCZ               && sel[ 5] && sel[ 1] && sel[ 0];
    assign masked[ 4] = NST_D2HR               && sel[ 6] && sel[ 1] && sel[ 0];
    assign masked[ 5] = NPD_NCA                && sel[ 7] && sel[ 1] && sel[ 0];
    assign masked[ 6] = CHW_DMAA               && sel[ 3] && sel[ 2] && sel[ 0];
    assign masked[ 7] = SCTL_DET_CHANGED_TO_4  && sel[ 4] && sel[ 2] && sel[ 0];
    assign masked[ 8] = SCTL_DET_CHANGED_TO_1  && sel[ 5] && sel[ 2] && sel[ 0];
    assign masked[ 9] = PXSSTS_DET_NE_3        && sel[ 6] && sel[ 2] && sel[ 0];
    assign masked[10] = PXSSTS_DET_EQ_1        && sel[ 7] && sel[ 2] && sel[ 0];
    assign masked[11] = NPCMD_FRE              && sel[ 4] && sel[ 3] && sel[ 0];
    assign masked[12] = FIS_OK                 && sel[ 5] && sel[ 3] && sel[ 0];
    assign masked[13] = FIS_ERR                && sel[ 6] && sel[ 3] && sel[ 0];
    assign masked[14] = FIS_FERR               && sel[ 7] && sel[ 3] && sel[ 0];
    assign masked[15] = FIS_EXTRA              && sel[ 5] && sel[ 4] && sel[ 0];
    assign masked[16] = FIS_FIRST_INVALID      && sel[ 6] && sel[ 4] && sel[ 0];
    assign masked[17] = FR_D2HR                && sel[ 7] && sel[ 4] && sel[ 0];
    assign masked[18] = FIS_DATA               && sel[ 6] && sel[ 5] && sel[ 0];
    assign masked[19] = FIS_ANY                && sel[ 7] && sel[ 5] && sel[ 0];
    assign masked[20] = NB_ND_D2HR_PIO         && sel[ 7] && sel[ 6] && sel[ 0];
    assign masked[21] = D2HR                   && sel[ 3] && sel[ 2] && sel[ 1];
    assign masked[22] = SDB                    && sel[ 4] && sel[ 2] && sel[ 1];
    assign masked[23] = DMA_ACT                && sel[ 5] && sel[ 2] && sel[ 1];
    assign masked[24] = DMA_SETUP              && sel[ 6] && sel[ 2] && sel[ 1];
    assign masked[25] = BIST_ACT_FE            && sel[ 7] && sel[ 2] && sel[ 1];
    assign masked[26] = BIST_ACT               && sel[ 4] && sel[ 3] && sel[ 1];
    assign masked[27] = PIO_SETUP              && sel[ 5] && sel[ 3] && sel[ 1];
    assign masked[28] = NB_ND                  && sel[ 6] && sel[ 3] && sel[ 1];
    assign masked[29] = TFD_STS_ERR            && sel[ 7] && sel[ 3] && sel[ 1];
    assign masked[30] = FIS_I                  && sel[ 5] && sel[ 4] && sel[ 1];
    assign masked[31] = PIO_I                  && sel[ 6] && sel[ 4] && sel[ 1];
    assign masked[32] = NPD                    && sel[ 7] && sel[ 4] && sel[ 1];
    assign masked[33] = PIOX                   && sel[ 6] && sel[ 5] && sel[ 1];
    assign masked[34] = XFER0                  && sel[ 7] && sel[ 5] && sel[ 1];
    assign masked[35] = PIOX_XFER0             && sel[ 7] && sel[ 6] && sel[ 1];
    assign masked[36] = CTBAA_CTBAP            && sel[ 4] && sel[ 3] && sel[ 2];
    assign masked[37] = CTBAP                  && sel[ 5] && sel[ 3] && sel[ 2];
    assign masked[38] = CTBA_B                 && sel[ 6] && sel[ 3] && sel[ 2];
    assign masked[39] = CTBA_C                 && sel[ 7] && sel[ 3] && sel[ 2];
    assign masked[40] = TX_ERR                 && sel[ 5] && sel[ 4] && sel[ 2];
    assign masked[41] = SYNCESC_ERR            && sel[ 6] && sel[ 4] && sel[ 2];
    assign masked[42] = DMA_PRD_IRQ_PEND       && sel[ 7] && sel[ 4] && sel[ 2];
    assign masked[43] = X_RDY_COLLISION        && sel[ 6] && sel[ 5] && sel[ 2];
    assign masked[44] = !(|sel); // always TRUE condition (sel ==0)

    always @(posedge clk) begin
        cond_r[ 0] <= |masked[ 7: 0];
        cond_r[ 1] <= |masked[15: 8];
        cond_r[ 2] <= |masked[23:16];
        cond_r[ 3] <= |masked[31:24];
        cond_r[ 4] <= |masked[39:32];
        cond_r[ 5] <= |masked[44:40];
    end
endmodule
