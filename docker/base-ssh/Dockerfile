FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenSSH server and JDK 17
RUN apt-get update && apt-get install -y \
    openssh-server \
    openjdk-17-jdk \
    unzip \
    curl \
    python3 \
    sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd \
    && echo 'root:root' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
