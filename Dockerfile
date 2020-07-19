FROM alpine:3.8

# awscli kubectl 
RUN apk --no-cache add jq bash py3-setuptools openssl curl tar gzip ca-certificates dpkg git\
    && pip3 install awscli 
    
RUN curl -L -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.16.8/bin/linux/amd64/kubectl \
    && chmod +x /usr/bin/kubectl \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 10 \
    && mkdir /work

WORKDIR /work
COPY *.sh /work/
RUN chmod +x /work/*.sh

