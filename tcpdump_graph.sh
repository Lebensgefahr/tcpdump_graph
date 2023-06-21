#!/usr/bin/bash

set -e

CONTAINERS=()
HOSTS=()
OPTS=($@)
IMAGE_PATH="./"
CONTAINERSLIST="containers.list"
DUMP="dump.txt"

function is_a_key(){
  KEY="$1"
  if [[ "$KEY" =~ ^- ]]; then
    return 1
  else
    return 0
  fi
}

function add_to_array(){
  declare -n AR="$1"
  while [[ $i -lt ${#OPTS[@]} ]]; do
    if is_a_key "${OPTS[$i]}"; then
      AR+=(${OPTS[$i]})
      ((i++))
    else
      ((i--))
      break
    fi
  done
}

function sshRun(){
  COMMAND="$@"
  ssh -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=no \
      "$USER@$HOST" "$COMMAND"
}

function getIfByContainerName(){
  local CONTAINER="$1"
  local IFNAME
  local IFNUM
  IFNUM="$(docker exec -i "$CONTAINER" cat /sys/class/net/eth0/iflink|sed 's/\r//g')"
  IFNAME="$(/usr/sbin/ip link show | sed -n 's/'$IFNUM': \(.*\)@.*/\1/p')"
  echo "$IFNAME"
}

function getNetworkList(){
  sshRun "if docker >/dev/null 2>&1; then docker network inspect --format='{{range .Containers}}{{.Name}}:{{println (index (split .IPv4Address \"/\") 0)}}{{end}}' \$(docker network ls -q); fi"
}
function getServiceList(){
  sshRun "if docker >/dev/null 2>&1; then docker service inspect --format='{{.Spec.Name}}:{{range .Endpoint.VirtualIPs}}{{.Addr}},{{end}}' \$(docker service ls -q)|sed 's|/24||g'; fi"
}
function getContainerList(){
  sshRun "if docker >/dev/null 2>&1; then docker inspect --format='{{.Name}}:{{range.NetworkSettings.Networks}}{{.IPAddress}},{{end}}' \$(docker ps -qa)|sed 's/^\///'; fi"
}

function tcpDump(){
  local CONTAINER="$1"
#  docker run -i --net container:"$CONTAINER" nicolaka/netshoot tcpdump -ltnni any ip and '(udp or tcp and not tcp[tcpflags]&tcp-rst != 0 )'
  docker run --rm --net container:"$CONTAINER" nicolaka/netshoot tcpdump -ltnni any ip and '(udp or tcp and not tcp[tcpflags]&tcp-rst != 0 )'
}

function runTcpDump(){
  sshRun "$(declare -f tcpDump getIfByContainerName); tcpDump "$CONTAINER""
}

function on_exit() {
  cat "${STR[@]}" > "$DUMP" && 
  ./create_dgraph.pl "$CONTAINERSLIST" "$DUMP" "$DUMP".dot &&
#  neato -Kfdp -Tjpg -o "$IMAGE_PATH"/"$DUMP".jpg "$DUMP".dot && 
  neato -Kfdp -Tpdf -o "$IMAGE_PATH"/"$DUMP".pdf "$DUMP".dot \
  &&  rm -f "${STR[@]}" "$CONTAINERSLIST" "$DUMP".dot "$DUMP"
#  &&  rm -f "${STR[@]}" "$DUMP".dot "$DUMP"
}

usage(){

cat <<EOF
Usage: ${BASH_SOURCE[0]} -H <host_ip> -U <ssh_username> [-c|-i] <container_names|interface_names>
Scripts to visualize tcpdump out.
OPTIONS:
  -H, --host              host IP to run tcpdump
  -U, --user              username to connect through ssh
  -c, --containers        container names.
  -i, --interfaces        list of interface names or any
  -h, --help              Usage info
EOF

}

for((i=0; i < ${#OPTS[@]}; i++)); do
 key=${OPTS[$i]}
    case ${key} in
            -c|--containers)
                    ((++i))
                    add_to_array CONTAINERS
                    ;;
            -U|--user)
                    ((++i))
                    USER="${OPTS[$i]}"
                    ;;
            -M|--manager)
                    ((++i))
                    MANAGER="${OPTS[$i]}"
                    ;;
            -H|--host)
                    ((++i))
                    add_to_array HOSTS
#                    HOST="${OPTS[$i]}"
                    ;;
            -i|--interfaces)
                    CMODE=false
                    ((++i))
                    add_to_array ARRAY
                    ;;
            -h|--help)
                    usage
                    exit 0
                    ;;
            *)
                    echo "Error: unknown option" >&2
                    exit 1
                    ;;
    esac
done


trap on_exit EXIT

HOST=$MANAGER

if [[ -n "$MANAGER" ]]; then
  getServiceList >> "$CONTAINERSLIST"
fi

for HOST in ${HOSTS[@]}; do
  echo $HOST
  getContainerList >> "$CONTAINERSLIST"
  getNetworkList >> "$CONTAINERSLIST"
done

for CONTAINER in ${CONTAINERS[@]}; do
  STR+=($CONTAINER.dump)
  runTcpDump "$CONTAINER" > "$CONTAINER".dump &
done

wait

