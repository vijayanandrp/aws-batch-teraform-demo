FROM amazon/aws-cli:latest

RUN uname -a
RUN yum install gcc openssl-devel bzip2-devel libffi-devel gzip make -y
RUN yum install -y tar gzip pigz openssl

ADD fetch_and_run.sh /usr/local/bin/fetch_and_run.sh

RUN chmod +x /usr/local/bin/fetch_and_run.sh

WORKDIR /tmp

ENTRYPOINT ["/usr/local/bin/fetch_and_run.sh"]
