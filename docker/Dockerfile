FROM ubuntu:20.04
RUN apt update && apt install openssh-client openssl openjdk-8-jdk -y
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin
VOLUME /mnt/bigdata
WORKDIR /mnt/bigdata
CMD ["tail","-f","/dev/null"]
