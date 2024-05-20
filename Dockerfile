FROM ubuntu:24.04

ENV libsrtp_ver=2.6.0

RUN apt update && \
    apt install -y build-essential vim wget curl sudo lsof git systemctl 

RUN apt install -y libmicrohttpd-dev libjansson-dev \
    libssl-dev libsofia-sip-ua-dev libglib2.0-dev \
    libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev \
    libconfig-dev pkg-config libtool automake 

RUN apt install -y meson ninja-build cmake 
RUN apt install -y ssl-cert nginx 
RUN apt install -y supervisor 

WORKDIR /root 

RUN git clone https://gitlab.freedesktop.org/libnice/libnice && \
    cd libnice && \
    meson --prefix=/usr build && ninja -C build && sudo ninja -C build install 

RUN wget https://github.com/cisco/libsrtp/archive/v${libsrtp_ver}.tar.gz && \
    tar xfv v${libsrtp_ver}.tar.gz && \
    cd libsrtp-${libsrtp_ver} && \
    ./configure --prefix=/usr --enable-openssl && \
    make shared_library && sudo make install 

RUN git clone https://libwebsockets.org/repo/libwebsockets && \
    cd libwebsockets && \
    mkdir build && \
    cd build && \
    cmake -DLWS_MAX_SMP=1 -DLWS_WITHOUT_EXTENSIONS=0 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" .. && \
    make && sudo make install 

RUN git clone https://github.com/meetecho/janus-gateway.git && \
    cd janus-gateway && \
    sh autogen.sh && \
    ./configure --prefix=/opt/janus && \
    make && \
    make install && \
    make configs 

RUN cp -a /root/janus-gateway/html/* /var/www/html 
RUN make-ssl-cert generate-default-snakeoil 

COPY conf/nginx.default.conf /etc/nginx/sites-available/default
COPY conf/janus.transport.http.jcfg /opt/janus/etc/janus/janus.transport.http.jcfg

# Supervisorの設定ファイルを作成
RUN mkdir -p /etc/supervisor/conf.d
COPY conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# デフォルトのコマンド
CMD ["/usr/bin/supervisord"]
