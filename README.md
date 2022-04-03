# tcpdump_graph
Scripts to visualize tcpdump out.

## Description

It uses tcpdump out for making a graph of network connections with graphviz package. It works for TCP only right now.
Default tcpdump filter  do not capture tcp flags with RST flag to show unsuccessful connections.  
Bidirectional arrow shows successful connections. Each arrow has a digit of packets count. For docker containers it will add a container name. Make shure you have a docker on a target host.
Example diagram in pdf format is included.

## Usage
You should have ssh access to the target host with private key authorization. 

To run tcpdump on all interfaces of the target host:
```
./tcpdump_graph.sh -H 192.168.1.3 -U blitzkrieg -i any
```
You can specify many interfaces:

```
./tcpdump_graph.sh -H 192.168.1.3 -U blitzkrieg -i eth0 eth1 eth2
```

or 

```
./tcpdump_graph.sh -H 192.168.1.3 -U blitzkrieg -i eth0 -i eth1 -i eth2
```
When it runs for the docker host it will try to get a list of containers with its IP's.

## Example:
```
./tcpdump_graph.sh -H 192.168.1.3 -U blitzkrieg -c nginx rabbitmq
```
or

```
./tcpdump_graph.sh -H 192.168.1.3 -U blitzkrieg -c nginx -c rabbitmq
```

You can't use -i and -c keys at the same time.



## Options:
```
-H, --host              host IP to run tcpdump
-U, --user		username to connect through ssh
-c, --containers        containers name.
-i, --interfaces        list of interface names or any
```

