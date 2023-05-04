#!/usr/bin/env python3
import argparse
import sys
import socket
import random
import struct

from scapy.all import *

def main():

    if len(sys.argv)<3:
        print('2 arguments: <dest> <message>')
        exit(1)

    addr = socket.gethostbyname(sys.argv[1])
    iface = "eth0"

    print("send on %s to %s" % (iface, str(addr)))
    pkt =  Ether(src=get_if_hwaddr(iface), dst='00:00:00:00:04:02')
    pkt = pkt /IP(dst=addr) / UDP(dport=1234, sport=random.randint(49100,65000)) / sys.argv[2]
    pkt.show2()
    sendp(pkt, iface=iface, verbose=False)

if __name__ == '__main__':
    main()