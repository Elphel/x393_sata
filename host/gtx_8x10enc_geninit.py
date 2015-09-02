mem7f = []
for i in range(0x80):
    mem7f.append(0);

i = 0
for line in open('gtx_8x10enc_init_stub.v').readlines(): 
    addr = int('0b' + line.split()[0], 2)
    a = int('0b' + line.split()[1], 2)
    b = int('0b' + line.split()[2], 2)
    mem7f[addr >> 3] = (((mem7f[addr >> 3] << 16) + b) << 16) + a
    i += 1

for i in range(0x80):
    print ', .INIT_%02X\t(256\'h%064X)' % (i, mem7f[i])
