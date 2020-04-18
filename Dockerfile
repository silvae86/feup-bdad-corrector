FROM schemacrawler/schemacrawler:v15.05.01

USER root

RUN mkdir -p /bdad
RUN mkdir -p /feup-bdad-corrector

RUN apk add sqlite
RUN apk add util-linux

COPY ./check.sh /feup-bdad-corrector/check.sh
COPY ./schemacrawler.config.properties /feup-bdad-corrector

RUN chown -R schcrwlr /feup-bdad-corrector
USER schcrwlr


RUN /feup-bdad-corrector/check.sh -h
ENTRYPOINT ["/feup-bdad-corrector/check.sh"]
