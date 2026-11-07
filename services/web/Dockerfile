# syntax=docker/dockerfile:1
# NairaFlow web — hardened image (Project 1, Day 7)
#  - nginx-unprivileged: runs as user 101 (not root) and listens on 8080,
#    because non-root users can't bind ports below 1024.
#  - Pin by digest in the Day 7 "pin" step.
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.27-alpine@sha256:65e3e85dbaed8ba248841d9d58a899b6197106c23cb0ff1a132b7bfe0547e4c0
FROM ${NGINX_IMAGE}
COPY --chmod=0444 nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=0444 index.html /usr/share/nginx/html/index.html
EXPOSE 8080
