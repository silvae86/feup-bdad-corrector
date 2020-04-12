FROM schemacrawler/schemacrawler:v15.05.01
USER root
RUN apk add sqlite
RUN apk add util-linux
USER schcrwlr
ENV RUNDIR "/bdad"
WORKDIR "$RUNDIR"
COPY ./check.sh "$RUNDIR"
COPY ./schemacrawler.config.properties "$RUNDIR"
RUN ./check.sh -h
ENTRYPOINT ["./check.sh"]
