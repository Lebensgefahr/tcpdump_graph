#!/usr/bin/bash

set -e

ARRAY=()
OPTS=($@)
IMAGE_PATH="/var/www/web"
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

function getContainerList(){
  sshRun "if docker >/dev/null 2>&1; then docker inspect --format='{{.Name}}:{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \$(docker ps -qa)|sed 's/^\///'; fi"
}

function tcpDump(){
  local VAR="$1"
  if $CMODE; then
    IFNAME="$(getIfByContainerName "$VAR")"
  else
    IFNAME="$VAR"
  fi
  sudo tcpdump -ltnni "$IFNAME" ip and '(udp or tcp and not tcp[tcpflags]&tcp-rst != 0 )'
}

function runTcpDump(){
  sshRun "$(declare -f tcpDump getIfByContainerName); CMODE="$CMODE"; tcpDump "$VAR""
}

function on_exit() {
  cat "${STR[@]}" > "$DUMP" && 
  ./create_dgraph.pl "$CONTAINERSLIST" "$DUMP" "$DUMP".dot &&
#  neato -Kfdp -Tjpg -o "$IMAGE_PATH"/"$DUMP".jpg "$DUMP".dot && 
  neato -Kfdp -Tpdf -o "$IMAGE_PATH"/"$DUMP".pdf "$DUMP".dot && 
  rm -f "${STR[@]}" "$CONTAINERSLIST" "$DUMP".dot "$DUMP"
}

usage(){

cat <<EOF
Usage: ${BASH_SOURCE[0]} -H <host_ip> -U <ssh_username> [-c|-i] <containers_names|interface_names>
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
                    CMODE=true
                    ((++i))
                    add_to_array ARRAY
                    ;;
            -U|--user)
                    ((++i))
                    USER="${OPTS[$i]}"
                    ;;
            -H|--host)
                    ((++i))
                    HOST="${OPTS[$i]}"
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

getContainerList > "$CONTAINERSLIST"

for VAR in ${ARRAY[@]}; do
  STR+=($VAR.dump)
  runTcpDump "$VAR" > "$VAR".dump &
done

wait
