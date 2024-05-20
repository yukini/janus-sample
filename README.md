---
created: 2024-05-20T17:32:19 (UTC +09:00)
tags: []
source: https://www.mikan-tech.net/entry/2020/05/02/173000
author: 
---

## 起動
```
sh ./exec.sh

```
ブラウザでアクセス https://localhost

## 終了
```
docker stop janus
```

# Janusで自前のWebRTCビデオチャットサーバー - みかんのゆるふわ技術ブログ
[Janusで自前のWebRTCビデオチャットサーバー - みかんのゆるふわ技術ブログ](https://www.mikan-tech.net/entry/2020/05/02/173000)

> ## Excerpt
> 最近、Microsoft TeamsやZoomなどのビデオ会議🖥がよく使われるようになってきていますね。 そんなビデオ会議システムを自前で用意したい！と思ったときに使えるオープンソースのソフトウェアに、Janusというものがあります。 janus.conf.meetecho.com JanusはGPLv3でライセンスされる、オープンソースのWebRTCサーバーです。 WebRTCは、ブラウザなどで利用できるリアルタイム通信技術で、今時のChromeやEdgeなど多くのブラウザで利用できます。 ビデオチャットや、普通のテキストチャット、ファイル転送などの通信がブラウザだけで利用できるので便利です…

---
最近、Microsoft TeamsやZoomなどのビデオ会議🖥がよく使われるようになってきていますね。 そんなビデオ会議システムを**自前で用意**したい！と思ったときに使えるオープンソースのソフトウェアに、**Janus**というものがあります。

[janus.conf.meetecho.com](https://janus.conf.meetecho.com/)

**Janus**はGPLv3でライセンスされる、オープンソースの**WebRTC**サーバーです。 **WebRTC**は、ブラウザなどで利用できるリアルタイム通信技術で、今時のChromeやEdgeなど多くのブラウザで利用できます。 ビデオチャットや、普通のテキストチャット、ファイル転送などの通信がブラウザだけで利用できるので便利です🥰

今回は、そのJanusをUbuntu 20.04 LTSサーバーにインストールしてみました。

**2020/10/08更新** 本家のインストール手順がアップデートされていたので、現時点での最新の手順を反映しました。

インストール手順は、Janusのソースコード中のREADME.mdに詳しく記載されていますので、基本的にそれに従うだけでインストールできます。

[github.com](https://github.com/meetecho/janus-gateway)

## 構成

実験用にローカル環境でのみ使うことを想定し、インターネットからは接続しません。

-   Ubuntu 20.04 LTS Server
-   Janus (commit: 3cfdf6f)

動作確認は、手持ちのWindows 10パソコンと、iPhoneの2台の間でビデオチャットしました。

## インストール

### 必要なパッケージのインストール

マニュアルに従って、必要なパッケージをインストールします。

```
$ sudo apt install libmicrohttpd-dev libjansson-dev \
        libssl-dev  libsofia-sip-ua-dev libglib2.0-dev \
        libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev \
        libconfig-dev pkg-config gengetopt libtool automake make
```

### libniceのビルド・インストール

libniceはUbuntu標準のものとは相性が悪いようで、ソースからビルドすることが推奨されています。手順に従って、ビルドしました。 もしUbuntu標準のものがインストール済みだった場合は、あらかじめ削除しておいてください。

libniceのビルドは以前はautotoolsを使っていましたが、いつの間にかmesonとninjaに移行したようです。 そのため、ビルドにはmesonとninjaも必要です。入っていなければインストールしてください。

```
$ sudo apt install meson ninja-build
```

次のようにしてソースを取ってきてビルドします。

```
$ cd ~
$ git clone https://gitlab.freedesktop.org/libnice/libnice
$ cd libnice
$ meson --prefix=/usr --libdir=lib build
$ ninja -C build
$ sudo ninja -C build install
```

手元のUbuntu 20.04マシンで試したところ、デフォルトではライブラリが`/usr/lib64`にインストールされましたが、`/usr/lib`にインストールしたいため`--libdir=lib`を付けました。

### libsrtpのビルド・インストール

続いてlibsrtpをインストールします。現時点では2.3.0が最新リリースでした。

```
$ cd ~
$ wget https://github.com/cisco/libsrtp/archive/v2.3.0.tar.gz
$ tar xfv v2.3.0.tar.gz
$ cd libsrtp-2.3.0
$ ./configure --prefix=/usr --enable-openssl
$ make shared_library &amp;&amp; sudo make install
```

`--enable-openssl`をつけてビルドすることが重要だそうです。

### (オプション)libwebsocketsのインストール

JanusはデフォルトではHTTP/HTTPSで音声や映像も送受信しますが、WebSocketを使いたい場合は、libwebsocketsをインストールしておく必要があります。 libwebsocketsを入れておくと、Janusのビルドシステムが検出してWebSocketサポート付きでビルドしてくれます。

libwebsocketsのビルドにはcmakeを使います。もし入っていなければインストールしましょう。

```
$ sudo apt install cmake
```

次のようにソースを取得してビルド、インストールします。

```
$ cd ~
$ git clone https://libwebsockets.org/repo/libwebsockets
$ cd libwebsockets
$ git checkout v3.2-stable
$ mkdir build
$ cd build
$ cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" ..
$ make &amp;&amp; sudo make install
```

cmakeのオプションにLWS\_MAX\_SMP=1を付けているのは、[Janusがデッドロックする問題を回避するため](https://github.com/meetecho/janus-gateway/issues/732)だそうです。

### Janusのビルド・インストール

最後に、Janusをインストールします。インストール先はマニュアルに倣って、`/opt/janus`とします。

```
$ cd ~
$ git clone https://github.com/meetecho/janus-gateway.git
$ cd janus-gateway
$ ./autogen.sh
$ ./configure --prefix=/opt/janus
$ make
$ sudo make install
```

続いて、Janusのconfigファイルを初期化します。

```
$ sudo make configs
```

configファイルを編集した後にこれを実行すると、編集が消えて初期状態に戻る😱ので、最初の1回だけ実行するように注意してください。

正しくインストールできたか確認しましょう。

```
$ cd /opt/janus
$ sudo ./bin/janus
```

ずらずら～っとメッセージが出て、エラー無く起動すればひとまずOKです。Warningはたくさん出ますが…。 CTRL-Cで終了できます。

スポンサーリンク

## セットアップ

Janusのインストールができたら早速使ってみたいものです。 幸い、Janusには様々なデモアプリが付属しているので、それを使ってみましょう。

デモアプリは、先ほどJanusのビルド・インストールの時にダウンロードしてきた`janus-gateway/`の中の`html/`フォルダに入っています。 これを、Webサーバーで配信しましょう。`Nginx`を使ってみることにします。

### Nginxのセットアップ

Nginxをインストールして、`janus-gateway/html`の中身をドキュメントルートにコピーします。

```
$ sudo apt install nginx
$ cd ~/janus-gateway
$ sudo cp -a html/* /var/www/html
```

これで、ブラウザで`http://<UbuntuサーバのIPアドレス>/`にアクセスすると、デモ画面が見られるはずです✨

![f:id:kimura_khs:20200502164526p:plain:w400](https://cdn-ak.f.st-hatena.com/images/fotolife/k/kimura_khs/20200502/20200502164526.png)

しかし、この時点ではビデオ通話のデモを開始しようとしても、エラーが出て使えないはずです。 （少なくともWindows 10のGoogle Chromeでは使えませんでした） 使うには、HTTPSを使う必要があります。

### HTTPSのセットアップ

セキュリティの都合上、ブラウザによりビデオ通話をするにはHTTPSでの暗号化が求められます🙅♀️ そのため、自己署名証明書で簡易的に暗号化してみましょう。 （公開サーバーでは自己署名証明書を使わないでください）

自己署名証明書を作るには、`make-ssl-cert`コマンドが便利です。

```
$ sudo apt-get install ssl-cert
$ sudo make-ssl-cert generate-default-snakeoil
```

これで、次の場所に自己署名証明書ができます。

-   `/etc/ssl/certs/ssl-cert-snakeoil.pem`
-   `/etc/ssl/private/ssl-cert-snakeoil.key`

これを使うようにNginxの設定を行います。

```
$ sudo vim /etc/nginx/sites-available/default
```

このファイルのいくつかの行のコメントアウトを外します。

```
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        listen 443 ssl default_server;         # コメントアウト外す
        listen [::]:443 ssl default_server;    # コメントアウト外す
        include snippets/snakeoil.conf;    # コメントアウト外す
        root /var/www/html;
        index index.html index.htm index.nginx-debian.html;
        server_name _;
        location / {
                try_files $uri $uri/ =404;
        }
}
```

設定を反映します。

```
$ sudo systemctl restart nginx.service
```

これで、HTTPSで配信されるようになりました。`https://<UbuntuサーバのIPアドレス>/`で先ほどと同じ画面が見られるか確認してください。 この時点では、まだビデオ通話はできません。

### JanusのHTTPSセットアップ

JanusはデフォルトでHTTPSがOFFになっているようです。設定ファイルを編集すると、有効にできます。次のファイルを編集します。

```
$ sudo vim /opt/janus/etc/janus/janus.transport.http.jcfg
```

変更点だけ以下に示します。他の行はそのままです。

```
general: {
        https = true         # 変更
        secure_port = 8089   # コメントアウト外す
}
certificates: {
        cert_pem = "/etc/ssl/certs/ssl-cert-snakeoil.pem"  # 変更
        cert_key = "/etc/ssl/private/ssl-cert-snakeoil.key"  # 変更
 }
```

できたら、動かしてみましょう。

```
$ sudo /opt/janus/bin/janus
(略)
HTTP webserver started (port 8088, /janus path listener)...
HTTPS webserver started (port 8089, /janus path listener)...
(略)
```

HTTPSも有効化されました🔑

スポンサーリンク

## 動作確認

いよいよビデオ通話の動作確認をしてみましょう。

先ほどの`sudo /opt/janus/bin/janus`でJanusサーバーを起動した状態で、`https://<UbuntuサーバのIPアドレス>/`にアクセスします。

![f:id:kimura_khs:20200502171523p:plain](https://cdn-ak.f.st-hatena.com/images/fotolife/k/kimura_khs/20200502/20200502171523.png)

上部のメニューから**Demos** → **Video Room**を選択し、Startボタンを押します。 ビデオ会議室での表示名の入力を求められます。

![f:id:kimura_khs:20200502171525p:plain](https://cdn-ak.f.st-hatena.com/images/fotolife/k/kimura_khs/20200502/20200502171525.png)

Windows 10パソコンのChromeと、iPhoneのSafariをビデオ会議に参加させてみました。映すものがなかったので、マグカップ☕️や時計🕰など手元にあったものを映しています。

遅延も少なく（おそらく数百ミリ秒以内）、とてもいい感じに動いています☺️

このデモアプリをカスタマイズして、独自のWeb会議画面を作ることもできます。いろんなことができそうなので、いろいろ試してみたいと思います。

### 追記(2020/8/15)

こちらにRaspberry Piでストリーミング配信する記事を書きました。あわせてぜひご覧ください。

[www.mikan-tech.net](https://www.mikan-tech.net/entry/raspi-janus-streaming)

### さらに追記(2020/8/28)

ストリーミング用ですが、独自の画面をVue.jsで作ってみました。独自の画面を作りたい方はぜひご参考に。

[www.mikan-tech.net](https://www.mikan-tech.net/entry/janus-vue-frontend-install)

[www.mikan-tech.net](https://www.mikan-tech.net/entry/janus-vue-frontend-create)

