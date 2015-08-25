import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue

import timescale

class SataHostDriver(BusDriver):
    '''
    shall drive sata_host interface
    '''
    _signals = ['al_cmd_in', 'al_cmd_val_in', 'al_cmd_out',
                # shadow regs inputs
                'al_sh_data_in', 'al_sh_data_val_in', 'al_sh_data_strobe_in', 
                'al_sh_feature_in', 'al_sh_feature_val_in', 'al_sh_lba_lo_in', 
                'al_sh_lba_lo_val_in', 'al_sh_lba_hi_in', 'al_sh_lba_hi_val_in', 
                'al_sh_count_in', 'al_sh_count_val_in', 'al_sh_command_in', 
                'al_sh_command_val_in', 'al_sh_dev_in', 'al_sh_dev_val_in', 
                'al_sh_control_in', 'al_sh_control_val_in', 'al_sh_dma_id_lo_in', 
                'al_sh_dma_id_lo_val_in', 'al_sh_dma_id_hi_in', 'al_sh_dma_id_hi_val_in', 
                'al_sh_buf_off_in', 'al_sh_buf_off_val_in', 'al_sh_tran_cnt_in', 
                'al_sh_tran_cnt_val_in', 'al_sh_autoact_in', 'al_sh_autoact_val_in', 
                'al_sh_inter_in', 'al_sh_inter_val_in', 'al_sh_dir_in', 
                'al_sh_dir_val_in', 'al_sh_dma_cnt_in', 'al_sh_dma_cnt_val_in', 
                'al_sh_notif_in', 'al_sh_notif_val_in', 'al_sh_port_in', 
                'al_sh_port_val_in',
                # shadow regs outputs
                'sh_data_val_out', 'sh_data_out', 'sh_control_out', 
                'sh_feature_out', 'sh_lba_out', 'sh_count_out', 
                'sh_command_out', 'sh_err_out', 'sh_status_out', 
                'sh_estatus_out', 'sh_dev_out', 'sh_port_out', 
                'sh_inter_out', 'sh_dir_out', 'sh_dma_id_out', 
                'sh_dma_off_out', 'sh_dma_cnt_out', 'sh_tran_cnt_out', 
                'sh_notif_out', 'sh_autoact_out']

    def __init__(self, entity, name, clk):
        BusDriver.__init__(self, entity, name, clk)

        # initial interface states
        self.bus.al_cmd_in.setimmediatevalue(0)
        self.bus.al_cmd_val_in.setimmediatevalue(0)
        self.bus.al_cmd_out.setimmediatevalue(0)
        
        self.bus.al_sh_data_in.setimmediatevalue(0)
        self.bus.al_sh_data_val_in.setimmediatevalue(0)
        self.bus.al_sh_data_strobe_in.setimmediatevalue(0)
        self.bus.al_sh_feature_in.setimmediatevalue(0)
        self.bus.al_sh_feature_val_in.setimmediatevalue(0)
        self.bus.al_sh_lba_lo_in.setimmediatevalue(0)
        self.bus.al_sh_lba_lo_val_in.setimmediatevalue(0)
        self.bus.al_sh_lba_hi_in.setimmediatevalue(0)
        self.bus.al_sh_lba_hi_val_in.setimmediatevalue(0)
        self.bus.al_sh_count_in.setimmediatevalue(0)
        self.bus.al_sh_count_val_in.setimmediatevalue(0)
        self.bus.al_sh_command_in.setimmediatevalue(0)
        self.bus.al_sh_command_val_in.setimmediatevalue(0)
        self.bus.al_sh_dev_in.setimmediatevalue(0)
        self.bus.al_sh_dev_val_in.setimmediatevalue(0)
        self.bus.al_sh_control_in.setimmediatevalue(0)
        self.bus.al_sh_control_val_in.setimmediatevalue(0)
        self.bus.al_sh_dma_id_lo_in.setimmediatevalue(0)
        self.bus.al_sh_dma_id_lo_val_in.setimmediatevalue(0)
        self.bus.al_sh_dma_id_hi_in.setimmediatevalue(0)
        self.bus.al_sh_dma_id_hi_val_in.setimmediatevalue(0)
        self.bus.al_sh_buf_off_in.setimmediatevalue(0)
        self.bus.al_sh_buf_off_val_in.setimmediatevalue(0)
        self.bus.al_sh_tran_cnt_in.setimmediatevalue(0)
        self.bus.al_sh_tran_cnt_val_in.setimmediatevalue(0)
        self.bus.al_sh_autoact_in.setimmediatevalue(0)
        self.bus.al_sh_autoact_val_in.setimmediatevalue(0)
        self.bus.al_sh_inter_in.setimmediatevalue(0)
        self.bus.al_sh_inter_val_in.setimmediatevalue(0)
        self.bus.al_sh_dir_in.setimmediatevalue(0)
        self.bus.al_sh_dir_val_in.setimmediatevalue(0)
        self.bus.al_sh_dma_cnt_in.setimmediatevalue(0)
        self.bus.al_sh_dma_cnt_val_in.setimmediatevalue(0)
        self.bus.al_sh_notif_in.setimmediatevalue(0)
        self.bus.al_sh_notif_val_in.setimmediatevalue(0)
        self.bus.al_sh_port_in.setimmediatevalue(0)
        self.bus.al_sh_port_val_in.setimmediatevalue(0)

    @cocotb.coroutine
    def getCmd(self):
        ''' get the value of al_cmd register '''
        raise ReturnValue(self.bus.al_cmd_out & 7 ) # get the last 3 bits

    @cocotb.coroutine
    def setCmd(self, cmd_type, cmd_port, cmd_val):
        self.bus.al_cmd_in      <= ((cmd_type << 5) + (cmd_port << 1) + (cmd_val)) << 3
        self.bus.al_cmd_val_in  <= 1
        yield RisingEdge(self.clock)
        self.bus.al_cmd_val_in  <= 0
        
    @cocotb.coroutine
    def getReg(self, addr):
        if addr == 0:
            raise ReturnValue(self.bus.sh_data_out)
        elif addr == 1:
            raise ReturnValue(self.bus.sh_feature_out)
        elif addr == 2:
            raise ReturnValue(self.bus.sh_lba_out)
        elif addr == 3:                
            raise ReturnValue(self.bus.sh_lba_out << 24)
        elif addr == 4:                
            raise ReturnValue(self.bus.sh_count_out)
        elif addr == 5:                
            raise ReturnValue(self.bus.sh_command_out)
        elif addr == 6:                
            raise ReturnValue(self.bus.sh_dev_out)
        elif addr == 7:                
            raise ReturnValue(self.bus.sh_control_out)
        elif addr == 8:                
            raise ReturnValue(self.bus.sh_dma_id_out)
        elif addr == 9:                
            raise ReturnValue(self.bus.sh_dma_id_out << 32)
        elif addr == 10:               
            raise ReturnValue(self.bus.sh_dma_off_out)
        elif addr == 11:               
            raise ReturnValue(self.bus.sh_tran_cnt_out)
        elif addr == 12:               
            raise ReturnValue(self.bus.sh_autoact_out)
        elif addr == 13:               
            raise ReturnValue(self.bus.sh_inter_out)
        elif addr == 14:               
            raise ReturnValue(self.bus.sh_dir_out)
        elif addr == 15:               
            raise ReturnValue(self.bus.al_cmd_out)
        elif addr == 16:               
            raise ReturnValue(self.bus.sh_err_out)
        elif addr == 17:               
            raise ReturnValue(self.bus.sh_status_out)
        elif addr == 18:               
            raise ReturnValue(self.bus.sh_estatus_out)
        elif addr == 19:               
            raise ReturnValue(self.bus.sh_port_out)
        elif addr == 20:               
            raise ReturnValue(self.bus.sh_dma_cnt_out)
        elif addr == 21:               
            raise ReturnValue(self.bus.sh_notif_out)
        else:
            raise ReturnValue(0)

    @cocotb.coroutine
    def setReg(self, addr, data):
        if addr == 0:
            self.bus.al_sh_data_in          <= data
            self.bus.al_sh_data_val_in      <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_data_in          <= 0
            self.bus.al_sh_data_val_in      <= 0
        elif addr == 1:
            self.bus.al_sh_feature_in       <= data
            self.bus.al_sh_feature_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_feature_in       <= 0
            self.bus.al_sh_feature_val_in   <= 0
        elif addr == 2:
            self.bus.al_sh_lba_lo_in        <= data
            self.bus.al_sh_lba_lo_val_in    <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_lba_lo_in        <= 0
            self.bus.al_sh_lba_lo_val_in    <= 0
        elif addr == 3:                
            self.bus.al_sh_lba_hi_in        <= data
            self.bus.al_sh_lba_hi_val_in    <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_lba_hi_in        <= 0
            self.bus.al_sh_lba_hi_val_in    <= 0
        elif addr == 4:                
            self.bus.al_sh_count_in         <= data
            self.bus.al_sh_count_val_in     <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_count_in         <= 0
            self.bus.al_sh_count_val_in     <= 0
        elif addr == 5:                
            self.bus.al_sh_command_in       <= data
            self.bus.al_sh_command_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_command_in       <= 0
            self.bus.al_sh_command_val_in   <= 0
        elif addr == 6:                
            self.bus.al_sh_dev_in           <= data
            self.bus.al_sh_dev_val_in       <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dev_in           <= 0
            self.bus.al_sh_dev_val_in       <= 0
        elif addr == 7:                
            self.bus.al_sh_control_in       <= data
            self.bus.al_sh_control_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_control_in       <= 0
            self.bus.al_sh_control_val_in   <= 0
        elif addr == 8:                
            self.bus.al_sh_dma_id_lo_in     <= data
            self.bus.al_sh_dma_id_lo_val_in <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dma_id_lo_in     <= 0
            self.bus.al_sh_dma_id_lo_val_in <= 0
        elif addr == 9:                
            self.bus.al_sh_dma_id_hi_in     <= data
            self.bus.al_sh_dma_id_hi_val_in <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dma_id_hi_in     <= 0
            self.bus.al_sh_dma_id_hi_val_in <= 0
        elif addr == 10:               
            self.bus.al_sh_dma_off_in       <= data
            self.bus.al_sh_dma_off_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dma_off_in       <= 0
            self.bus.al_sh_dma_off_val_in   <= 0
        elif addr == 11:               
            self.bus.al_sh_tran_cnt_in      <= data
            self.bus.al_sh_tran_cnt_val_in  <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_tran_cnt_in      <= 0
            self.bus.al_sh_tran_cnt_val_in  <= 0
        elif addr == 12:               
            self.bus.al_sh_autoact_in       <= data
            self.bus.al_sh_autoact_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_autoact_in       <= 0
            self.bus.al_sh_autoact_val_in   <= 0
        elif addr == 13:               
            self.bus.al_sh_inter_in         <= data
            self.bus.al_sh_inter_val_in     <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_inter_in         <= 0
            self.bus.al_sh_inter_val_in     <= 0
        elif addr == 14:               
            self.bus.al_sh_dir_in           <= data
            self.bus.al_sh_dir_val_in       <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dir_in           <= 0
            self.bus.al_sh_dir_val_in       <= 0
        elif addr == 19:               
            self.bus.al_sh_port_in          <= data
            self.bus.al_sh_port_val_in      <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_port_in          <= 0
            self.bus.al_sh_port_val_in      <= 0
        elif addr == 20:               
            self.bus.al_sh_dma_cnt_in       <= data
            self.bus.al_sh_dma_cnt_val_in   <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_dma_cnt_in       <= 0
            self.bus.al_sh_dma_cnt_val_in   <= 0
        elif addr == 21:               
            self.bus.al_sh_notif_in         <= data
            self.bus.al_sh_notif_val_in     <= 1
            yield RisingEdge(self.clock)
            self.bus.al_sh_notif_in         <= 0
            self.bus.al_sh_notif_val_in     <= 0

