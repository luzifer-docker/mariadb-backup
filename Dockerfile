FROM mariadb:10.11

RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends percona-toolkit \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/

VOLUME ["/data"]

ENTRYPOINT ["/bin/bash"]
CMD ["/usr/local/bin/backup.sh"]
