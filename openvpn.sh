#!/bin/bash
LANG=C
LC_ALL=C

STAT=$(stat /tmp/openvpn-status.stat --format=%Y)

if [ $? -ge 1 ]; then
	echo "DOWN"
fi

DATE=$(date +%s)

if [ $(($DATE - $STAT)) -gt 10 ]; then
	echo "DOWN"
else
	echo " UP "
fi

