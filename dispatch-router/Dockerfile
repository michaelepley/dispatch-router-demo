########################################################################
#                         Qpid Dispatch Router                         #
########################################################################

FROM fedora:24

MAINTAINER Rich Lucente <rlucente@redhat.com>

LABEL vendor="Red Hat"
LABEL version="0.1"
LABEL description="Qpid Dispatch Router"

ENV QDROUTER_CONF /etc/qpid-dispatch/qdrouterd.conf

RUN    dnf -y update \
    && dnf -y install qpid-dispatch-router qpid-dispatch-tools \
                      qpid-dispatch-docs python-websockify \
    && dnf -y clean all

USER 1000

EXPOSE 5000 5673 6000

CMD /usr/sbin/qdrouterd --config=${QDROUTER_CONF}

