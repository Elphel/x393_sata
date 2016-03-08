#!/bin/sh
#http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
if [ -z "$1" ]
    then
        echo "You need to specify instllation root"
        exit 1
fi
install -d -v $1/usr/local/verilog/
install -d -v $1/usr/local/bin/
install -v -m 0755 py393sata/*.py $1/usr/local/bin/
install -v -m 0644 x393_sata.bit $1/usr/local/verilog/

exit 0