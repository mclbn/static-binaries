FROM centos:7

RUN yum install -y gcc make autoconf

COPY build.sh /
RUN chmod +x /build.sh

CMD /build.sh
