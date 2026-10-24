# syntax=docker/dockerfile:1

ARG DEBIAN_RELEASE=bookworm-slim
ARG SPLIX_VERSION=2.0.2
ARG SPLIX_DISABLE_THREADS=1

FROM debian:${DEBIAN_RELEASE} AS splix-builder

ARG SPLIX_VERSION

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cups-ppdc \
    libcups2-dev \
    patch \
    unzip \
    wget \
  && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 build-splix.sh /usr/local/bin/build-splix
COPY splix-algo0x11-little-endian.patch /usr/local/share/

ARG SPLIX_DISABLE_THREADS

RUN SPLIX_VERSION="${SPLIX_VERSION}" \
  SPLIX_DISABLE_THREADS="${SPLIX_DISABLE_THREADS}" \
  /usr/local/bin/build-splix


FROM debian:${DEBIAN_RELEASE}

# Copying from the builder first makes BuildKit finish that stage before it
# starts the runtime package installation. This avoids running both apt-get
# processes concurrently on memory-constrained Raspberry Pis.
COPY --from=splix-builder /out/ /

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    cups \
    cups-filters \
    usbutils \
  && rm -rf /var/lib/apt/lists/* \
  && useradd \
    --groups=lp,lpadmin \
    --create-home \
    --home-dir=/home/print \
    --shell=/bin/bash \
    print

# Generate the initial configuration copied into the cups_data volume.
RUN /usr/sbin/cupsd \
  && while [ ! -f /run/cups/cupsd.pid ]; do sleep 1; done \
  && cupsctl --remote-admin --remote-any --share-printers \
  && kill "$(cat /run/cups/cupsd.pid)" \
  && sed -i '0,/^</s//DefaultEncryption IfRequested\n&/' /etc/cups/cupsd.conf \
  && echo 'ServerAlias *' >> /etc/cups/cupsd.conf

COPY --chmod=755 entrypoint.sh /entrypoint.sh

EXPOSE 631

ENTRYPOINT ["/entrypoint.sh"]
