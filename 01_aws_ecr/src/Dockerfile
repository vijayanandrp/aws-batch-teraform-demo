FROM amazon/aws-cli:latest

#FROM amazonlinux:latest

#RUN yum -y install java
#RUN amazon-linux-extras install epel -y
#RUN sudo yum update
#RUN sudo yum -y install which unzip

RUN sudo yum install -y tar gzip pigz

ADD encrypt_decrypt_service.sh /usr/local/bin/encrypt_decrypt_service.sh
WORKDIR /tmp
USER nobody


ENTRYPOINT ["/usr/local/bin/encrypt_decrypt_service.sh"]
