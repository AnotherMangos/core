FROM ubuntu:14.04

ENV BOOST_ROOT="/boost_1_61_0"

RUN apt-get update && \
    apt-get install -y python-software-properties software-properties-common && \
    apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    lxc \
    iptables &&\
    add-apt-repository -y ppa:george-edison55/cmake-3.x && \
    apt-get update && \
    apt-get remove -y cmake cmake-data && \
    apt-get install -y curl wget build-essential gcc g++ automake git-core autoconf make patch libmysql++-dev \
                       libtool libssl-dev grep binutils zlibc libc6 libbz2-dev cmake mysql-client && \
    echo "Installing Boost..." && \
    wget --quiet https://sourceforge.net/projects/boost/files/boost/1.61.0/boost_1_61_0.tar.gz && \
    tar -xzf /boost_1_61_0.tar.gz && \
    rm /boost_1_61_0.tar.gz && \
    cd $BOOST_ROOT && \
    ./bootstrap.sh && \
    (./b2 || true) && \
    curl -sSL https://get.docker.com/ | sh &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/

RUN echo "[client]\nprotocol=tcp\n" > /etc/mysql/conf.d/protocol.cnf && \
    wget -q -O- https://japaric.github.io/trust/install.sh | sh -s -- --git casey/just --target x86_64-unknown-linux-musl --to /bin


COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
