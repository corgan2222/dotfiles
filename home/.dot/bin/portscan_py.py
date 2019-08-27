#!/usr/bin/env python3
import argparse , socket , sys , logging
from datetime import datetime
 
SOCKET_STATES = {
    0: "open",
    11: "firewalled",
    111: "closed",
}
 
def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("hostname", metavar="HOSTNAME",
                        help="define the hostname to be checked")
    parser.add_argument("start_port", type=int, metavar="START_PORT",
                        help="define the start port")
    parser.add_argument("end_port", type=int, metavar="END_PORT",
                        help="define the end port")
    parser.add_argument("-a", "--all-ports", action="store_true",
                        help="shows all (default is show only open ports)")
    parser.add_argument("-l", "--logfile", type=str, 
                        help="if set i will write an logfile (you have to set an logfile incl path)")
    parser.add_argument("-t", "--timeout", type=int, default=3, 
                        help=("set the TIMEOUT for socket operations (default is 3 seconds)"))
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="set debug mode (set --all-ports)")
    args = parser.parse_args()
     
    if args.end_port < args.start_port:
        sys.exit("END_PORT must be higher then START_PORT")
 
    if 0 < args.start_port <= 65535 and 0 < args.end_port <= 65535:
        return args
    else:
        sys.exit("The Portrange must between 1-65535")
 
def get_ip_address(hostname):
    try:
        return socket.gethostbyname(hostname)
    except socket.error as err:
        # print (str(err))
        print ('Hostname could not be resolved. Exiting')
        sys.exit(4)
 
def check_port(ip, port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            result = s.connect_ex((ip, port))
            return SOCKET_STATES.get(result, result)
    except KeyboardInterrupt:
        sys.exit(1)
    except socket.gaierror:
        print ('Hostname could not be resolved. Exiting')
        sys.exit(3)
    except socket.error:
        print ("Couldn't connect to server")
        sys.exit(2)
 
def write_log(entry,state):
    if state in ['info', 'warning', 'critical','error']:
        log_method = getattr(logging,state)
        log_method(str(entry))
 
def scan_ports(remote_host, start_port, end_port, logfile , debug=False, show_all=False):
    ip = get_ip_address(remote_host)
    # Print Banner
    print ("-" * 90)
    print ("please wait, scanning remote host {0} , takes some time !".format(ip))
    print ("-" * 90)
    print ("\n")
 
    t_start = datetime.now()
    for port in range(start_port, end_port + 1):
        if debug:
            print ("\n--> check port {0} on ip {1}\n".format(port, ip))
        port_state = check_port(ip, port)
        if logfile:
            write_log ("--> check port {0} on ip {1} its {2}".format(port, ip, port_state),"info")
        if port_state == "open" or show_all or debug:
            print ("Port {0: >5}: {1: >10}".format(port, port_state))
    duration = datetime.now() - t_start
 
    print ("\n")
    print ("-" * 90)
    print ("scanning completed in : {0}".format(duration))
 
if __name__ == '__main__':
    args = parse_args()
    socket.setdefaulttimeout(int(args.timeout))
    logging.basicConfig(format='%(asctime)s | %(levelname)s | %(message)s',filename=args.logfile,filemode='w',level=logging.DEBUG)
    scan_ports(remote_host=args.hostname,
               start_port=args.start_port, end_port=args.end_port,
               debug=args.verbose, show_all=args.all_ports,logfile=args.logfile)