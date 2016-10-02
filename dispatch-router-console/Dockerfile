########################################################################
#                     Qpid Dispatch Router Console                     #
########################################################################

FROM fedora:24

MAINTAINER Rich Lucente <rlucente@redhat.com>

LABEL vendor="Red Hat"
LABEL version="0.1"
LABEL description="Qpid Dispatch Router Console"

RUN    dnf -y update \
    && dnf -y install tomcat unzip \
    && dnf -y clean all \
    && cd /tmp \
    && curl -L -O https://github.com/apache/qpid-dispatch/archive/master.zip \
    && unzip -q master.zip \
    && mkdir -p /var/lib/tomcat/webapps/dispatch \
    && cp -r qpid-dispatch-master/console/stand-alone/* /var/lib/tomcat/webapps/dispatch \
    && rm -fr /tmp/qpid-dispatch-master /tmp/master.zip \
    && chown -R 1000:1000 \
           /usr/share/tomcat \
           /etc/tomcat \
           /usr/share/java/tomcat \
           /var/log/tomcat \
           /var/cache/tomcat/temp \
           /var/lib/tomcat/webapps \
           /var/cache/tomcat/work

USER 1000

EXPOSE 8080

CMD /usr/libexec/tomcat/server start

