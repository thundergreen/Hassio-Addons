ARG BUILD_FROM
FROM $BUILD_FROM AS BUILD

ENV LANG C.UTF-8
ENV COMMIT_SHA '0884f7c141551bc5c2d259b230f415107aeebf85'

RUN apk add --no-cache git=2.24.1-r0 npm=12.15.0-r1
# hadolint ignore=DL3003
RUN git clone https://github.com/Hypfer/ICantBelieveItsNotValetudo.git -b master /app && \
    cd app && git checkout $COMMIT_SHA

WORKDIR /app
RUN npm install

COPY run.sh /
RUN chmod a+x /run.sh
CMD [ "/run.sh" ]
