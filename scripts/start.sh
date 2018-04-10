#!/bin/sh

set -e

signal_handler() {
    # stop the appserver and adminserver
    echo "Stopping asbroker1 appserver"
    asbman -stop -name asbroker1
    echo "Stopping admin server"
    proadsv -stop

    # graceful shutdown so exit with 0
    exit 0
}
# trap SIGTERM and call the handler to cleanup processes
trap 'signal_handler' SIGTERM SIGINT

# first start the admin server
echo "Starting admin server"
proadsv -start

# next start asbroker1
echo "Starting appserver"
asbman -start -name asbroker1

# get appserver pid 
pid=`ps aux|grep '[I]D=AppServer'|awk '{print $2}'`
if [ -z "${pid}" ]
then
  echo "ERROR: Appserver failed to start!"
  exit 1
fi
echo "Appserver running as pid: ${pid}"

# keep tailing log file until appserver process exits
tail --pid=${pid} -f asbroker1.server.log & wait ${!}

# things didn't go well
exit 1
