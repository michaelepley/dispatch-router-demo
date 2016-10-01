#!/bin/bash

POOL=
# This should be a valid pool id that includes the following channels:
#
#     a-mq-clients-1-for-rhel-7-server-beta-rpms
#     rhel-7-server-rpms
#     rhel-7-server-extras-rpms
#     rhel-7-server-optional-rpms
#     rhel-7-server-ose-3.2-rpms
#
# If you're a Red Hat employee, the script will try to automatically
# discover the pool id

if [ "x`whoami`" != "xroot" ]
then
    echo
    echo "*** Must be root to run this script ***"
    echo
    exit 1
fi

# automatically determine pool id if missing
if [ "x$POOL" = "x" ]
then
    POOL=`sudo subscription-manager list --available --all | \
        grep 'Subscription Name\|Pool ID\|System Type' | \
        grep -A2 Employee | grep -B2 Virtual | grep 'Pool ID' | \
        rev | cut -d' ' -f1 | rev`
fi

if [ "x$POOL" = "x" ]
then
    echo
    echo "*** No valid pool id found ***"
    echo
    exit 1
fi

# subscribe to the necessary channels
sudo subscription-manager attach --pool=${POOL}
sudo subscription-manager repos --disable='*'
sudo subscription-manager repos \
        --enable=a-mq-clients-1-for-rhel-7-server-beta-rpms \
        --enable=rhel-7-server-rpms \
        --enable=rhel-7-server-extras-rpms \
        --enable=rhel-7-server-optional-rpms \
        --enable=rhel-7-server-ose-3.2-rpms
sudo yum -y install python-qpid-proton
sudo yum clean all
