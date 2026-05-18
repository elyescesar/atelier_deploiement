FROM public.ecr.aws/amazonlinux/amazonlinux:2023

ARG MONGO_VERSION=6.0.16

RUN dnf install -y tar gzip curl && dnf clean all && \
    (curl -fSL "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon2023-${MONGO_VERSION}.tgz" -o /tmp/mongo.tgz || \
     curl -fSL "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon2-${MONGO_VERSION}.tgz" -o /tmp/mongo.tgz) && \
    tar -xzf /tmp/mongo.tgz -C /opt && \
    mv /opt/mongodb-linux-x86_64-* /opt/mongodb && \
    ln -sf /opt/mongodb/bin/* /usr/local/bin/ && \
    rm -f /tmp/mongo.tgz

RUN mkdir -p /data/db

EXPOSE 27017

CMD ["mongod", "--bind_ip_all"]
