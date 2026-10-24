# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS runtime-base

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    cups \
    cups-filters \
  && rm -rf /var/lib/apt/lists/* \
  && useradd \
    --groups=lp,lpadmin \
    --create-home \
    --home-dir=/home/print \
    --shell=/bin/bash \
    print


FROM runtime-base AS splix-builder

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cups-ppdc \
    libcups2-dev \
    patch \
    unzip \
    wget \
  && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 build-splix.sh /usr/local/bin/build-splix
COPY splix-algo0x11-little-endian.patch /usr/local/share/

RUN /usr/local/bin/build-splix


FROM runtime-base

# Generate the initial configuration copied into the cups_data volume.
RUN /usr/sbin/cupsd \
  && while [ ! -f /run/cups/cupsd.pid ]; do sleep 1; done \
  && cupsctl --remote-admin --remote-any --share-printers \
  && kill "$(cat /run/cups/cupsd.pid)" \
  && sed -i '0,/^</s//DefaultEncryption IfRequested\n&/' /etc/cups/cupsd.conf \
  && echo 'ServerAlias *' >> /etc/cups/cupsd.conf

COPY --from=splix-builder /out/ /
COPY --chmod=755 entrypoint.sh /entrypoint.sh

EXPOSE 631

ENTRYPOINT ["/entrypoint.sh"]
