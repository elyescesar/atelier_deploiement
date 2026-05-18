FROM public.ecr.aws/amazonlinux/amazonlinux:2023

RUN dnf install -y wget && \
    wget -qO /etc/yum.repos.d/mongodb-org-6.0.repo https://repo.mongodb.org/yum/amazon/2023/mongodb-org/6.0/mongodb-org-6.0.repo && \
    dnf install -y mongodb-org && \
    dnf clean all

RUN mkdir -p /data/db

EXPOSE 27017

CMD ["mongod", "--bind_ip_all"]
