FROM fedora:latest

COPY WWT-CA.pem /etc/pki/ca-trust/source/anchors/WWT-CA.pem
RUN update-ca-trust
ENV REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem 

RUN dnf update -y && \
    dnf install --setopt=tsflags=nodocs -y \
        jq \
        wget \
        asciinema \
        ncurses \
        tree  \
        unzip \
        less

RUN wget https://github.com/mikefarah/yq/releases/download/v4.32.1/yq_linux_amd64 -O /root/bin/yq &&\
    chmod +x /root/bin/yq

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install -b /bin && \
    rm -rf ./aws awscliv2.zip
