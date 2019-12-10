#!/bin/sh

set -e

signal_handler() {
    echo "Stopping container"
    # stop the appserver and adminserver
    echo "Stopping asbroker1 appserver"
    asbman -stop -name asbroker1
    echo "Stopping name server NS1"
    nsman -stop -name NS1
    echo "Stopping admin server"
    proadsv -stop

    # graceful shutdown so exit with 0
    exit 0
}
# trap SIGTERM and call the handler to cleanup processes
trap 'signal_handler' SIGTERM SIGINT

# first start the admin server
echo "Starting admin server"
proadsv -port ${ADMINSERVER_PORT} -start

RETRIES=0
while true
do
  if [ "${RETRIES}" -gt 10 ]
  then
    echo "$(date +%F_%T) ERROR: AdminServer didn't start so exiting."
    exit 1
  fi

  if proadsv -query; then
    break;
  fi

  sleep 1
  RETRIES=$((RETRIES+1))
done

# let the nameserver auto start with the admin server
# then the nameserver NS1
echo "Starting name server NS1"
nsman -port ${ADMINSERVER_PORT} -start -name NS1

RETRIES=0
while true
do
  if [ "${RETRIES}" -gt 10 ]
  then
    echo "$(date +%F_%T) ERROR: NameServer didn't start so exiting."
    exit 1
  fi

  if nsman -query -name NS1; then
    break;
  fi

  sleep 1
  RETRIES=$((RETRIES+1))
done

# next start asbroker1
echo "Starting appserver"
asbman -port ${ADMINSERVER_PORT} -start -name asbroker1

# get appserver pid 
echo "Waiting for appserver to start..."

RETRIES=0
while true
do
  if [ "${RETRIES}" -gt 10 ]
  then
    break
  fi

  pid=`ps aux|grep '[I]D=AppServer'|awk '{print $2}'`
  if [ ! -z "${pid}" ]
  then
    case "${pid}" in
      ''|*[!0-9]*) continue ;;
      *) break ;;
    esac
  fi
  sleep 1
  RETRIES=$((RETRIES+1))
done
# did we get the pid?
if [ -z "${pid}" ]
then
  echo "$(date +%F_%T) ERROR: AppServer process not found exiting."
  exit 1
fi

echo "Appserver running as pid: ${pid}"

# keep tailing log file until appserver process exits
tail --pid=${pid} -f NS1.ns.log admserv.log asbroker1.broker.log asbroker1.server.log & wait ${!}

# things didn't go well
exit 1
