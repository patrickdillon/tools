FROM fedora:latest

COPY oc /root/bin/oc

COPY WWT-CA.pem /etc/pki/ca-trust/source/anchors/WWT-CA.pem
RUN update-ca-trust
ENV REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem 

RUN yum update -y && \
    yum install --setopt=tsflags=nodocs -y \
        jq \
        wget \
        asciinema \
        ncurses

RUN wget https://github.com/mikefarah/yq/releases/download/v4.15.1/yq_linux_amd64 -O /root/bin/yq &&\
    chmod +x /root/bin/yq
