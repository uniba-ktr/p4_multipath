import socket
import sys

if len(sys.argv) == 1:
    ip = '10.0.4.2'
    port = 1234
else:
    exit(1)

# UDP socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
 
server_address = (ip, port)
s.bind(server_address)
print("Ctrl+c to exit")

while True:
    print("RUNS: ")
    data, address = s.recvfrom(4096)
    print("\n\n Server received: ", data.decode('utf-8'), "\n\n")
