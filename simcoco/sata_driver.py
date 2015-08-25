import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue

class SataHalfWord(BusDriver):
    ''' Every 8 bits -> 10 on phy line ''' 
    def __init__(self, data, control):
        self.data       = [].append(data)
        self.control    = [].append(control)

class SataPhyDriver(BusDriver):
    _signals = ['txp_out', 'txn_out', 'rxp_in', 'rxp_out']

    def __init__(self, entity, name, clock, gen):
        ''' The clock shall be serial '''
        BusDriver.__init__(self, entity, name, clock)

        # outcoming elecidle flag
        self.txelecidle = 1
        # queue of *parallel* values to send
        self.sq = []
        # stream trace of received parallel values
        self.rq = []
        # sata generation (~ clock frequency)
        self.gen = gen

        self.driveBit(0)

    # Queues management section
    def addHalfWord(self, hword):
        self.sq = self.sq.append(hword)

    # elecidle management section
    def setElecIdle(self):
        self.txelecidle = 1

    def unsetElecIdle(self):
        self.txelecidle = 0

    # Data send section
    def driveBit(self, value):
        if txelecidle: 
            self.bus.txp_out.setimmediatevalue('z')
            self.bus.txn_out.setimmediatevalue('z')
        elif value == 1:
            self.bus.txp_out.setimmediatevalue(1)
            self.bus.txn_out.setimmediatevalue(0)
        elif value == 0:
            self.bus.txp_out.setimmediatevalue(0)
            self.bus.txn_out.setimmediatevalue(1)
        else:
            self.bus.txp_out.setimmediatevalue(value)
            self.bus.txn_out.setimmediatevalue(value)
        yield RisingEdge(self.clock)

    def serial(self, parallel):
        for i in range(9, -1, -1):
            value = '{0:b}'.format(parallel)[i]
            driveBit(value)
        
    def sendQueue(self):
        for hword in self.sq:
            serial(self, hword)

class SataPhyMonitor(BusMonitor):
    _signals = ['txp_out', 'txn_out', 'rxp_in', 'rxp_out']

    def __init__(self, *args, **kwargs):
        BusMOnitor.__init__(self, *arggs, **kwargs)

    # Data receive section
    def getBit(self)
        yield RisingEdge(self.clock)
        return self.bus.txp_out.getValue()

    def getHalfWord(self):
        hword = ''
        for i in range(9, -1, -1):
            hword.append(getBit)
        return hword

    def alignReciever(self):
        ''' look for a comma character in a bitstream 
            returns running disparity value, when comma occurs '''
        # get an initial hword
        hword = ''
        for i in range(9, -1, -1):
            hword.append(getBit)
        # shift until we meet a comma
        while True:
            if hword == '0011111010':
                disparity = 1
                break
            elif hword == '1100000101':
                disparity = 0
                break
            else
                hword.pop(1)
                hword.append(getBit)
        return disparity

    def decodeHalfWord(self):
        pass

    # oob
    def monitorElecidle(self):




