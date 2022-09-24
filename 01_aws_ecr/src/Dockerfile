FROM amazon/aws-cli:latest

RUN uname -a
RUN yum install gcc openssl-devel bzip2-devel libffi-devel gzip make -y
RUN yum install -y tar gzip pigz openssl

ADD encrypt_decrypt_service.sh /usr/local/bin/encrypt_decrypt_service.sh
WORKDIR /tmp
USER nobody


ENTRYPOINT ["/usr/local/bin/encrypt_decrypt_service.sh"]
