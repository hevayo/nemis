FROM ubuntu:22.04

RUN apt update && apt install openssh-server sudo -y

RUN useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 nemis

RUN echo 'nemis:123456' | chpasswd

RUN service ssh start

EXPOSE 22
EXPOSE 9443
EXPOSE 9444
EXPOSE 8243

CMD ["/usr/sbin/sshd","-D"]
