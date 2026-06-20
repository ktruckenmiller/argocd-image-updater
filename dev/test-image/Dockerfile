FROM alpine:3.20
ARG GIT_SHA=0000000000000000000000000000000000000000
ARG SOURCE_BUST=0
RUN echo "demo-app ${GIT_SHA} ${SOURCE_BUST}" > /version.txt
CMD ["/bin/sh", "-c", "cat /version.txt && sleep infinity"]
