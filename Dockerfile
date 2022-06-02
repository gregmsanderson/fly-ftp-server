ARG BASE_IMG=alpine:3.15

FROM $BASE_IMG AS pidproxy

# want pidproxy:
RUN apk add alpine-sdk \
 && git clone https://github.com/ZentriaMC/pidproxy.git \
 && cd pidproxy \
 && git checkout 193e5080e3e9b733a59e25d8f7ec84aee374b9bb \
 && sed -i 's/-mtune=generic/-mtune=native/g' Makefile \
 && make \
 && mv pidproxy /usr/bin/pidproxy \
 && cd .. \
 && rm -rf pidproxy \
 && apk del alpine-sdk

FROM $BASE_IMG

COPY --from=pidproxy /usr/bin/pidproxy /usr/bin/pidproxy
RUN apk add vsftpd tini

COPY conf/start_vsftpd.sh /bin/start_vsftpd.sh
COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf

# make sure can execute the script else get permission denied:
RUN chmod +x /bin/start_vsftpd.sh

# vsftpd fails to run without this as the conf is owned by the wrong user
RUN chown root /etc/vsftpd/vsftpd.conf

ENTRYPOINT ["/sbin/tini", "--", "/bin/start_vsftpd.sh"]