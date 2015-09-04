# left_column[9] = disparity
# left_column[8] = conrtol
# left_column[7:0] = decoded 8
# right column[9:0] = encoded 10 in correct order : abcdefgh. Need to flip it, because gtx spits out flipped data with flipped bit order
#

mem7f = []
for i in range(0x80):
    mem7f.append(0);

filecontent = {}
for line in open('gtx_10x8dec_init_stub.v').readlines(): 
    address_flipped_str = line.split()[1];
    address_str         = address_flipped_str[::-1]
    address             = int('0b' + address_str, 2)
    # retrieve everything but disparity - highest bit
    value               = int('0b' + line.split()[0][1:], 2)
    # retrieve disparity
    disparity           = int('0b' + line.split()[0][0], 2)
    # if disparity = 1 -> flag positive disparity, 0 -> flag negative one
    disp_pos = 1 if disparity == 1 else 0
    disp_neg = 1 if disparity == 0 else 0

    if address_str in filecontent:
        disp_pos = 1 if filecontent[address_str][1] == 1 or disp_pos else 0
        disp_neg = 1 if filecontent[address_str][2] == 1 or disp_neg else 0

    filecontent[address_str] = [address, disp_pos, disp_neg, value];


for key in filecontent:
    (address, disp_pos, disp_neg, value) = filecontent[key]
#    if address == 0x2aa:
#        print '2AA: ADDR>>4 = %X' % (address >> 4),' ADDR = ', bin(address), ' POS DISP = ', bin(disp_pos), ' NEG DISP = ', bin(disp_neg), ' VALUE = ', bin(value)
#    print 'ADDR = ', bin(address), ' POS DISP = ', bin(disp_pos), ' NEG DISP = ', bin(disp_neg), ' VALUE = ', bin(value)
    to_mem = (disp_pos << 10) + (disp_neg << 9) + value
    mem7f[address >> 4] = mem7f[address >> 4] + (to_mem << ((address % 16) * 16))
#    if (address >> 4) == 0x2a:
#        print '2AA: ADDR = %X, to mem = %X, total = %X ' % ((address ),to_mem, mem7f[address >> 4])#, ' ADDR = ', bin(address), ' POS DISP = ', bin(disp_pos), ' NEG DISP = ', bin(disp_neg), ' VALUE = ', bin(value)
#    if addr == 0x2aa:
#        print "FLIPPED ADDR %s " % address_flipped_str, "ADDR %x " % addr, "ADDR7f %x " % (addr >> 4), "VALUE %x " % a

for i in range(0x80):
    print ', .INIT_%02X\t(256\'h%064X)' % (i, mem7f[i])
