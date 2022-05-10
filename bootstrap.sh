#!/usr/bin/env bash

SOURCE_CONFIG=/unbound/unbound.conf
DEST_CONFIG=/opt/unbound/etc/unbound/unbound.conf

echo "Bootstrapping unbound..."

if [ ! -f "$SOURCE_CONFIG" ]; then
    echo "ERROR: No unbound config file found at $SOURCE_CONFIG"
    echo "ERROR: You must mount a config file to launch unbound."
    exit 1
fi

cp "$SOURCE_CONFIG" "$DEST_CONFIG"
CP_STATUS=$?

if [ $CP_STATUS -ne 0 ]; then
    echo "ERROR: Unable to copy file at $SOURCE_CONFIG (are sufficient permissions set?)"
    exit 1
fi

chown root:root "$DEST_CONFIG"
chmod 440 "$DEST_CONFIG"

unbound-checkconf "$DEST_CONFIG"
CHECKCONF_STATUS=$?

if [ $CHECKCONF_STATUS -ne 0 ]; then
    echo "ERROR: $SOURCE_CONFIG is not a valid config file."
    exit 1
fi

UNBOUND_VERBOSITY=""

if [ "$1" == "-v" ]; then
    UNBOUND_VERBOSITY="-vvv"
fi

echo "Starting unbound..."
unbound -d $UNBOUND_VERBOSITY

UNBOUND_STATUS=$?
echo "Unbound exited with code $UNBOUND_STATUS"