FROM ubuntu:jammy as unbound-build

WORKDIR /opt/unbound/

RUN ["apt-get", "update"]
RUN ["apt-get", "dist-upgrade", "-y"]
RUN ["apt-get", "install", "wget", "ca-certificates", "gpg", "-y"]
RUN ["wget", "--secure-protocol=TLSv1_3", "--https-only", "-O", "unbound.tar.gz", "https://www.nlnetlabs.nl/downloads/unbound/unbound-1.15.0.tar.gz"]
RUN ["wget", "--secure-protocol=TLSv1_3", "--https-only", "-O", "sig.asc", "https://www.nlnetlabs.nl/downloads/unbound/unbound-1.15.0.tar.gz.asc"]
RUN ["wget", "--secure-protocol=TLSv1_3", "--https-only", "-O", "SHA256SUMS", "https://www.nlnetlabs.nl/downloads/unbound/unbound-1.15.0.tar.gz.sha256"]

RUN echo "$(cat SHA256SUMS) unbound.tar.gz" | sha256sum -c -

ADD --chown=root:root unbound_pubkey.asc /opt/unbound/

RUN ["gpg", "--no-default-keyring", "--keyring", "unbound.keyring", "--import", "unbound_pubkey.asc"]
RUN ["gpg", "--no-default-keyring", "--keyring", "unbound.keyring", "--verify", "sig.asc", "unbound.tar.gz"]

RUN ["tar", "-xzf", "unbound.tar.gz"]

RUN ["rm", "-f", "unbound.tar.gz", "sig.asc", "unbound_pubkey.asc", "SHA256SUMS"]

WORKDIR /opt/unbound/unbound-1.15.0

RUN ["apt-get", "install", "gcc", "make", "libssl-dev", "libexpat1-dev", "dpkg-dev", "flex", "bison", "-y"]

RUN DEB_BUILD_MAINT_OPTIONS="hardening=+all" \
    CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS) $CPPFLAGS" \
    CFLAGS="$(dpkg-buildflags --get CFLAGS) $CPPFLAGS $CFLAGS" \
    CXXFLAGS="$(dpkg-buildflags --get CXXFLAGS) $CPPFLAGS $CXXFLAGS" \
    LDFLAGS="$(dpkg-buildflags --get LDFLAGS) -Wl,--as-needed $LDFLAGS" \
    ./configure \
    --prefix=/opt/unbound \
    --disable-flto \
    --disable-rpath \
    --enable-pie \
    --enable-relro-now \
    --with-chroot-dir=/opt/unbound

RUN ["make", "install"]

RUN ["rm", "-rf", "/opt/unbound/include", "/opt/unbound/lib", "/opt/unbound/share", "/opt/unbound/unbound-1.15.0", "/opt/unbound/etc/unbound/unbound.conf"]

FROM ubuntu:jammy as unbound

COPY --from=unbound-build /opt/unbound/ /opt/unbound/
ADD --chown=root:root bootstrap.sh /usr/local/sbin/bootstrap.sh

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install ca-certificates openssl bind9-host -y && \
    chmod +x /usr/local/sbin/bootstrap.sh && \
    mkdir /opt/unbound/dev/ && \
    mknod -m 0666 /opt/unbound/dev/random c 1 8 && \
    mknod -m 0666 /opt/unbound/dev/urandom c 1 9 && \
    mknod -m 0666 /opt/unbound/dev/zero c 1 5 && \
    adduser unbound --system --shell /usr/sbin/nologin --no-create-home --disabled-login && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*ubuntu.com*

ENV PATH=/opt/unbound/sbin:"$PATH"

ENTRYPOINT ["bootstrap.sh"]

EXPOSE 5353/udp
EXPOSE 5353/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD host -t A -p 5353 -W 5 google.com 127.0.0.1 || exit 1