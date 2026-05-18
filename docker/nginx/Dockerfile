FROM public.ecr.aws/amazonlinux/amazonlinux:2023

RUN dnf install -y nginx && dnf clean all

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
