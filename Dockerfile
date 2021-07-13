from debian:9

RUN apt update
RUN apt-get -y install git php python3 curl gawk python3-lxml
RUN mkdir /Software
RUN cd /Software && git clone https://github.com/gerw/mathbin
ENV PATH=$PATH:/Software/mathbin
RUN mkdir /data
WORKDIR /data
