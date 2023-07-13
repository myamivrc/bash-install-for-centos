#!/bin/bash
# Copyright 2023 aqz/tamaina, joinmisskey
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice
# shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#バージョン　本家は3.0.0
version="0.0.1";

#ご挨拶
tput setaf 4;
echo "";
echo "Misskey auto setup for CentOS";
echo " v$version";
echo "";

#OS確認
tput setaf 2;
echo "Check: Linux;"
#Linuxかどうかのチェック
if [ "$(command -v uname)" ]; then
	if [ "$(uname -s)" == "Linux" ]; then
		tput setaf 7;
		echo "	OK.";
		#RedHat・CentOSのバージョンファイルチェック(RedHat・CentOSの確認)
		if ! [ -f "/etc/redhat-release" ]; then
			echo "	Warning: This script has been tested on RedHat or CentOS and may not work on other distributions.";
		fi
	else
		tput setaf 1;
		echo "	NG.";
		exit 1;
	fi
else
	tput setaf 1;
	echo "	NG.";
	exit 1;
fi
#OS確認終了
#rootの確認
tput setaf 2;
echo "Check: root user;";
#whoamiでrootと出ればsudoもしくはsuで実行されている。
if [ "$(whoami)" != 'root' ]; then
	tput setaf 1;
	echo "	NG. This script must be run as root.";
	exit 1;
else
	tput setaf 7;
	echo "	OK. I am root user.";
fi
#rootの確認終了
#アーキテクチャの確認
tput setaf 2;
echo "Check: arch;";
case $(uname -m) in
	x86_64)
		tput setaf 7;
		echo "	x86_64 (amd64)";
		arch=amd64;
		;;
	aarch64)
		tput setaf 7;
		echo "	aarch64 (arm64)";
		arch=arm64;
		;;
	*)
		tput setaf 1;
		echo "	NG. $(uname -m) is unsupported architecture.";
		exit 1;
		;;
esac
#アーキテクチャの確認終了

#導入条件のアンケート
tput setaf 3;
echo "";
echo "Install Method";
tput setaf 7;
#systemdかdockerか
echo "Do you use systemd to run Misskey?:";
echo "Y = To use systemd / n = To use docker"
read -r -p "[Y/n] > " yn
case "$yn" in
	[Nn]|[Nn][Oo])
		echo "Use Docker.";
		method=docker;

		echo "Determine the local IP of this computer as docker host.";
		echo "The IPs that are supposed to be available are as follows (the result of hostname -I)";
		echo "	$(hostname -I)"
		read -r -p "> " -e -i "$(hostname -I | cut -f1 -d' ')" docker_host_ip;

		echo "The host name of docker host to bind with 'docker run --add-host='.";
		read -r -p "> " -e -i "docker_host" misskey_localhost;
		;;
	*)
		echo "Use Systemd.";
		method=systemd;
		#メモ systemdはここでlocalhostをぶっこんでる
		misskey_localhost=localhost
		;;
esac
#systemdかdockerか終了
#docker向け追加質問
if [ $method == "docker" ]; then
	if [ $arch == "amd64" ]; then
		echo "Do you use image from Docker Hub?:";
		echo "Y = To use Docker Hub image / N = To build Docker image in this machine"
		read -r -p "[Y/n] > " yn
		case "$yn" in
			[Nn]|[Nn][Oo])
				echo "Build docker image (local/misskey:latest).";
				method=docker;
				docker_repository="local/misskey:latest"
				;;
			*)
				echo "Use Docker Hub image.";
				method=docker_hub;
				echo "Enter repository:tag of Docker Hub image:"
				read -r -p "> " -e -i "misskey/misskey:latest" docker_repository;
				;;
		esac
	else
		echo "We should build docker manually because this is arm64 machine.";
		method=docker;
		docker_repository="local/misskey:latest"
	fi

fi
#docker向け追加質問終了
#Misskeyのセッティングアンケート
tput setaf 3;
echo "Misskey setting";
tput setaf 7;
misskey_directory=misskey

#どのMisskeyを使う？(リポジトリ選択)※Systemd向け
if [ $method != "docker_hub" ]; then
	echo "Repository url where you want to install:"
	read -r -p "> " -e -i "https://github.com/misskey-dev/misskey.git" repository;
	echo "The name of a new directory to clone:"
	read -r -p "> " -e -i "misskey" misskey_directory;
	echo "Branch or Tag"
	read -r -p "> " -e -i "master" branch;
fi
#どのMisskeyを使う？終了
#Misskeyの実行ユーザは？
tput setaf 3;
echo "";
echo "Enter the name of user with which you want to execute Misskey:";
tput setaf 7;
read -r -p "> " -e -i "misskey" misskey_user;
#Misskeyの実行ユーザは？終了

#Misskeyを動かすドメインは？
tput setaf 3;
echo "";
echo "Enter host where you want to install Misskey:";
tput setaf 7;
read -r -p "> " -e -i "example.com" host;
tput setaf 7;
hostarr=(${host//./ });
echo "OK, let's install $host!";
#Misskeyを動かすドメインは？終了

#nginxのアンケート
tput setaf 3;
echo "";
echo "Nginx setting";
tput setaf 7;
#nginxを使う？
echo "Do you want to setup nginx?:";
read -r -p "[Y/n] > " yn
case "$yn" in
	[Nn]|[Nn][Oo])
		#nginxは使わない
		echo "Nginx and Let's encrypt certificate will not be installed.";
		echo "You should open ports manually.";
		nginx_local=false;
		cloudflare=false;
		certbot=false;

		#Misskeyはどのポートで動かす？
		echo "Misskey port: ";
		read -r -p "> " -e -i "3000" misskey_port;
		;;
	*)
		#nginxを使う
		echo "Nginx will be installed on this computer.";
		echo "Port 80 and 443 will be opened by modifying iptables.";
		nginx_local=true;

		tput setaf 3;
		echo "";
		
		#ポート変更はツールで変更する？
		tput setaf 7;
		echo "Do you want it to open ports, to setup ufw or iptables?:";
		echo "u = To setup ufw / i = To setup iptables / N = Not to open ports";

		read -r -p "[u/i/N] > " yn2
		case "$yn2" in
			[Uu])
				echo "OK, it will use ufw.";
				ufw=true
				iptables=false
				echo "SSH port: ";
				read -r -p "> " -e -i "22" ssh_port;
				;;
			[Ii])
				echo "OK, it will use iptables.";
				ufw=false
				iptables=true
				echo "SSH port: ";
				read -r -p "> " -e -i "22" ssh_port;
				;;
			*)
				echo "OK, you should open ports manually.";
				ufw=false
				iptables=false
				;;
			esac
		#ポート変更はツールで変更する？終了

		#cartbotの設定
		tput setaf 3;
		echo "";
		echo "Certbot setting";
		tput setaf 7;
		#cartbotを使ってHTTPS化する？
		echo "Do you want it to setup certbot to connect with https?:";

		read -r -p "[Y/n] > " yn2
		case "$yn2" in
			[Nn]|[Nn][Oo])
				certbot=false
				echo "OK, you don't setup certbot.";
				;;
			*)
				certbot=true
				echo "OK, you want to setup certbot.";
				#endregion
				;;
			esac
		#cartbotの設定終了

		#cloudflareの設定（後で検証する）
		tput setaf 3;
		echo "";
		echo "Cloudflare setting";
		tput setaf 7;
		echo "Do you use Cloudflare?:";

		read -r -p "[Y/n] > " yn2
		case "$yn2" in
			[Nn]|[Nn][Oo])
				echo "OK, you don't use Cloudflare.";
				echo "Let's encrypt certificate will be installed using the method without Cloudflare.";
				echo "";
				echo "Make sure that your DNS is configured to this machine.";
				cloudflare=false

				if $certbot; then
					echo "";
					echo "Enter Email address to register Let's Encrypt certificate";
					read -r -p "> " cf_mail;
				fi
				;;
			*)
				cloudflare=true
				echo "OK, you want to use Cloudflare. Let's set up Cloudflare.";
				echo "";
				echo "Make sure that Cloudflare DNS is configured and is in proxy mode.";
				echo "";
				echo "Enter Email address you registered to Cloudflare:";
				read -r -p "> " cf_mail;
				echo "Open https://dash.cloudflare.com/profile/api-tokens to get Global API Key and enter here it.";
				echo "Cloudflare API Key: ";
				read -r -p "> " cf_key;

				mkdir -p /etc/cloudflare;
				cat > /etc/cloudflare/cloudflare.ini <<-_EOF
				dns_cloudflare_email = $cf_mail
				dns_cloudflare_api_key = $cf_key
				_EOF

				chmod 600 /etc/cloudflare/cloudflare.ini;
				;;
			esac
		#cloudflareの設定終了
		#nginxを使う人向けのMisskeyはどのポートで動かす？
		echo "Tell me which port Misskey will watch: ";
		echo "Misskey port: ";
		read -r -p "> " -e -i "3000" misskey_port;
		;;
esac

#postgresのアンケート
tput setaf 3;
echo "";
echo "Database (PostgreSQL) setting";
tput setaf 7;
#postgresをここでインストールするかい？
echo "Do you want to install postgres locally?:";
echo "(If you have run this script before in this computer, choose n and enter values you have set.)"
read -r -p "[Y/n] > " yn
case "$yn" in
	[Nn]|[Nn][Oo])
		#しないならもともとの接続情報を教えてよ
		echo "You should prepare postgres manually until database is created.";
		db_local=false;

		echo "Database host: ";
		read -r -p "> " -e -i "$misskey_localhost" db_host;
		echo "Database port:";
		read -r -p "> " -e -i "5432" db_port;
		;;
	*)
		#するならこっちで接続情報決めとくかんね
		echo "PostgreSQL will be installed on this computer at $misskey_localhost:5432.";
		db_local=true;

		db_host=$misskey_localhost;
		db_port=5432;
		;;
esac
#postgresのID(または登録するID)を教えて？
echo "Database user name: ";
read -r -p "> " -e -i "misskey" db_user;
echo "Database user password: ";
read -r -p "> " db_pass;
echo "Database name:";
read -r -p "> " -e -i "mk1" db_name;
#postgresのアンケート終了

#redisのアンケート
tput setaf 3;
echo "";
echo "Redis setting";
tput setaf 7;
#redisのインストールするかい？
echo "Do you want to install redis locally?:";
echo "(If you have run this script before in this computer, choose n and enter values you have set.)"
read -r -p "[Y/n] > " yn
case "$yn" in
	[Nn]|[Nn][Oo])
		#しないならもともとの接続情報を教えてよ
		echo "You should prepare Redis manually.";
		redis_local=false;

		echo "Redis host:";
		read -r -p "> " -e -i "$misskey_localhost" redis_host;
		echo "Redis port:";
		read -r -p "> " -e -i "6379" redis_port;
		;;
	*)
		#するならこっちで接続情報決めとくかんね
		echo "Redis will be installed on this computer at $misskey_localhost:6379.";
		redis_local=true;

		redis_host=$misskey_localhost;
		redis_port=6379;
		;;
esac

#redisのパスワードを教えてよ
echo "Redis password:";
read -r -p "> " redis_pass;

tput setaf 7;
echo "";
echo "OK. It will automatically install what you need. This will take some time.";
echo "";
#redisのアンケート終了

set -eu;

#メモリーの空き確認
tput setaf 2;
echo "Check: Memory;"
#メモリーの情報取得
mem_all=$(free -t --si -g | tail -n 1);
mem_allarr=(${mem_all//\\t/ });
if [ "${mem_allarr[1]}" -ge 3 ]; then
	tput setaf 7;
	echo "	OK. This computer has ${mem_allarr[1]}GB RAM.";
else
	tput setaf 1;
	echo "	NG. This computer doesn't have enough RAM (>= 2GB, Current ${mem_allarr[1]}GB).";
	tput setaf 7;
	mem_swap=$(free | tail -n 1);
	mem_swaparr=(${mem_swap//\\t/ });
	#スワップ領域がなかったら作ろうとしているらしい(ここに質問を入れるかは脳内で議論中)
	if [ "${mem_swaparr[1]}" -eq 0 ]; then
		if [ "${mem_allarr[1]}" -ge 2 ]; then
			echo "	Swap will be made (1M x 1024).";
			dd if=/dev/zero of=/swap bs=1M count=1024;
		else
			echo "	Swap will be made (1M x 2048).";
			dd if=/dev/zero of=/swap bs=1M count=2048;
		fi
		mkswap /swap;
		swapon /swap;
		echo "/swap none swap sw 0" >> /etc/fstab;
		free -t;
	else
		#スワップ領域が足りなかったら終わりです。お疲れ様でした。	
		echo "  Add more swaps!";
		exit 1;
	fi
fi
#メモリーの空き確認終了

#ユーザの作成
tput setaf 3;
echo "Process: add misskey user ($misskey_user);";
tput setaf 7;
#ユーザの存在確認
if cut -d: -f1 /etc/passwd | grep -q -x "$misskey_user"; then
	#ユーザあるじゃん
	echo "$misskey_user exists already. No user will be created.";
else
	#ユーザないじゃん作るね
	useradd -m -U -s /bin/bash "$misskey_user";
fi
echo "misskey_user=\"$misskey_user\"" > /root/.misskey.env
echo "version=\"$version\"" >> /root/.misskey.env
m_uid=$(id -u "$misskey_user")
#ユーザの作成終了


#インストール開始、ここがみゃみーさんの腕の見せどころ
tput setaf 3;
echo "Process: apt install #1;";
tput setaf 7;
#まずは全体的にアップデート
dnf update -y;

#epelのインストール(certbotのインストールに必要)
sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm";

#rpmFusionのインストール(FFmpegのインストールに必要)
sudo dnf install -y "https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm"

#必要ソフトのインストール
#メモ：（抜いたもの：apt-transport-https、software-properties-common、build-essential、uidmap。理由:RedHat環境には不要なため）
sudo dnf install -y curl nano jq gnupg2 ca-certificates redhat-lsb-core$($nginx_local && echo " yum-utils")$($nginx_local && echo " certbot")$($nginx_local && ($ufw && echo " ufw" || $iptables && echo " iptables-services"))$($cloudflare && echo " python3-certbot-dns-cloudflare")$([ $method != "docker_hub" ] && echo " git")$([ $method == "systemd" ] && echo " ffmpeg");

#Systemd向け設定
if [ $method != "docker_hub" ]; then
	#ミスキーユーザーに切り替え
	su "$misskey_user" << MKEOF
	set -eu;
	cd ~;
	tput setaf 3;
	echo "Process: git clone;";
	tput setaf 7;
	if [ -e "./$misskey_directory" ]; then
		if [ -f "./$misskey_directory" ]; then
			rm "./$misskey_directory";
		else
			rm -rf "./$misskey_directory";
		fi
	fi
	#ミスキーをClone
	git clone -b "$branch" --depth 1 --recursive "$repository" "$misskey_directory";
	MKEOF
#ここからDockerむけせっていー
else
	#ミスキーユーザーに切り替え
	su "$misskey_user" << MKEOF
	set -eu;
	cd ~;
	if [ -e "./$misskey_directory" ]; then
		if [ -f "./$misskey_directory" ]; then
			rm "./$misskey_directory";
		fi
	else
		mkdir "./$misskey_directory"
	fi
	if [ -e "./$misskey_directory/.config" ]; then
		if [ -f "./$misskey_directory/.config" ]; then
			rm "./$misskey_directory/.config";
		fi
	else
		mkdir "./$misskey_directory/.config"
	fi
	MKEOF
fi
#ミスキーのymlを準備
tput setaf 3;
echo "Process: write default.yml;";
tput setaf 7;
#region work with misskey user
su "$misskey_user" << MKEOF
set -eu;
cd ~;

tput setaf 3;
echo "Process: create default.yml;"
tput setaf 7;

#ミスキーのymlを編集ここから
cat > "$misskey_directory/.config/default.yml" << _EOF
url: https://$host
port: $misskey_port

# PostgreSQL
db:
  host: '$db_host'
  port: $db_port
  db  : '$db_name'
  user: '$db_user'
  pass: '$db_pass'

# Redis
redis:
  host: '$redis_host'
  port: $redis_port
  pass: '$redis_pass'

# ID type
id: 'aid'

# Sign to ActivityPub GET request (default: true)
signToActivityPubGet: true

proxyBypassHosts:
  - api.deepl.com
  - api-free.deepl.com
  - www.recaptcha.net
  - hcaptcha.com
  - challenges.cloudflare.com
  - summaly.arkjp.net
_EOF
MKEOF
#ミスキーのymlを編集ここまで
#ポート準備
if $nginx_local; then
	if $ufw; then
		tput setaf 3;
		echo "Process: port open by ufw;"
		tput setaf 7;

		ufw limit $ssh_port/tcp;
		ufw default deny;
		ufw allow 80;
		ufw allow 443;
		ufw --force enable;
		ufw status;
	elif $iptables; then
		tput setaf 3;
		echo "Process: port open by iptables;"
		tput setaf 7;

		grep -q -x -e "-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT" /etc/iptables/rules.v4 || iptables -I INPUT -p tcp --dport 80 -j ACCEPT;
		grep -q -x -e "-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT" /etc/iptables/rules.v4 || iptables -I INPUT -p tcp --dport 443 -j ACCEPT;
		grep -q -x -e "-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT" /etc/iptables/rules.v6 || ip6tables -I INPUT -p tcp --dport 80 -j ACCEPT;
		grep -q -x -e "-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT" /etc/iptables/rules.v6 || ip6tables -I INPUT -p tcp --dport 443 -j ACCEPT;

		netfilter-persistent save;
		netfilter-persistent reload;
	fi
#nginx準備
	tput setaf 3;
	echo "Process: prepare nginx;"
	tput setaf 7;

#nginxのリポジトリ準備をしますよー
cat > "/etc/yum.repos.d/nginx.repo" << _EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
_EOF
	#リポジトリおーん
	sudo yum-config-manager -y --enable nginx-mainline;
	
fi

#systemd向けのーどじぇーえす！
if [ $method == "systemd" ]; then
	tput setaf 3;
	echo "Process: prepare node.js;"
	tput setaf 7;
	curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -;
else
#Dockerいんすとーる！！
	tput setaf 3;
	echo "Process: prepare docker;"
	tput setaf 7;
	#Dockerリポジトリおーん！
	sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo;
fi

#redisぷりぱら！
if $redis_local; then
	tput setaf 3;
	echo "Process: prepare redis;"
	tput setaf 7;
	#特にないです(動画投稿者)
	echo "OK";
fi

tput setaf 3;
echo "Process: apt install #2;"
tput setaf 7;
sudo dnf update -y;
#メモ：ここでnginxをインストール
sudo dnf install -y$([ $method == "systemd" ] && echo " nodejs" || echo " docker-ce docker-ce-cli containerd.iodocker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin")$($redis_local && echo " redis")$($nginx_local && echo " nginx");

#corepack準備(systemd限定)
if [ $method == "systemd" ]; then
	tput setaf 3;
	echo "Process: corepack enable;"
	tput setaf 7;
	#corepack(yarnとかnpmのパッケージマネージャーを管理するソフト)をおーん！
	corepack enable;
fi

#インストールやつのバージョン表示！
echo "Display: Versions;"
if [ $method == "systemd" ]; then
	echo "node";
	node -v;
	echo "corepack";
	corepack -v;
else
	echo "docker";
	docker --version;
fi
if $redis_local; then
	echo "redis";
	redis-server --version;
fi
if $nginx_local; then
	echo "nginx";
	nginx -v;
fi
#バージョン表示終了！

#redisのデーモン準備
if $redis_local; then
	tput setaf 3;
	echo "Process: daemon activate: redis;"
	tput setaf 7;
	#redis起動！
	systemctl start redis-server;
	#redis常駐！
	systemctl enable redis-server;
fi

#nginxのデーモン準備
#region nginx_setup
if $nginx_local; then
tput setaf 3;
echo "Process: create nginx config;"
tput setaf 7;

#nginxの設定値になにか書き込んでるよかわいいね。
cat > "/etc/nginx/conf.d/$host.conf" << NGEOF
# nginx configuration for Misskey
# Created by joinmisskey/bash-install v$version

# For WebSocket
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

proxy_cache_path /tmp/nginx_cache levels=1:2 keys_zone=cache1:16m max_size=1g inactive=720m use_temp_path=off;

server {
    listen 80;
    listen [::]:80;
    server_name $host;

    # For SSL domain validation
    root /var/www/html;
    location /.well-known/acme-challenge/ { allow all; }
    location /.well-known/pki-validation/ { allow all; }

NGEOF
#書き込みここまで

#certbot準備
if $certbot; then
tput setaf 3;
echo "Process: add nginx config (certbot-1);"
tput setaf 7;
cat >> "/etc/nginx/conf.d/$host.conf" << NGEOF
	# with https
    location / { return 301 https://\$server_name\$request_uri; }
}
NGEOF

#certbotでHTTPS化やってみた！
tput setaf 3;
echo "Process: prepare certificate;"
tput setaf 7;
nginx -t;
#ここ謎リスタート
systemctl restart nginx;

#Certbotサーバに情報を発射！
if $cloudflare; then
	certbot certonly -t -n --agree-tos --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory $([ ${#hostarr[*]} -eq 2 ] && echo " -d $host -d *.$host" || echo " -d $host") -m "$cf_mail";
else
	mkdir -p /var/www/html;
	certbot certonly -t -n --agree-tos --webroot --webroot-path /var/www/html $([ ${#hostarr[*]} -eq 2 ] && echo " -d $host" || echo " -d $host") -m "$cf_mail";
fi

#certbotの情報をnginxに入れてみた！
tput setaf 3;
echo "Process: add nginx config (certbot-2);"
tput setaf 7;
cat >> "/etc/nginx/conf.d/$host.conf" << NGEOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $host;

    ssl_session_timeout 1d;
    ssl_session_cache shared:ssl_session_cache:10m;
    ssl_session_tickets off;

    # To use Let's Encrypt certificate
    ssl_certificate     /etc/letsencrypt/live/$host/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$host/privkey.pem;

    # SSL protocol settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_stapling on;
    ssl_stapling_verify on;
NGEOF
fi

#nginxにMisskeyの情報を入れてみた！
tput setaf 3;
echo "Process: add nginx config;"
tput setaf 7;
cat >> "/etc/nginx/conf.d/$host.conf" << NGEOF
    # Change to your upload limit
    client_max_body_size 80m;

    # Proxy to Node
    location / {
        proxy_pass http://127.0.0.1:$misskey_port;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_redirect off;

$($cloudflare || echo "        # If it's behind another reverse proxy or CDN, remove the following.")
$($cloudflare || echo "        proxy_set_header X-Real-IP \$remote_addr;")
$($cloudflare || echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;")
$($cloudflare || echo "        proxy_set_header X-Forwarded-Proto https;")

        # For WebSocket
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        # Cache settings
        proxy_cache cache1;
        proxy_cache_lock on;
        proxy_cache_use_stale updating;
		proxy_force_ranges on;
        add_header X-Cache \$upstream_cache_status;
    }
}
NGEOF
#以上nginxにMisskeyの情報を入れてみましたがいかがでしたか？

#設定が間違っていないかの確認
nginx -t;

tput setaf 3;
echo "Process: daemon activate: nginx;"
tput setaf 7;

#nginx再起動！
systemctl restart nginx;
#nginx常駐化！
systemctl enable nginx;

tput setaf 2;
#nginxが動いてるかの確認。ドキドキワクワク
echo "Check: localhost returns nginx;";
tput setaf 7;
if curl http://localhost | grep -q nginx; then
	echo "	OK.";
else
	tput setaf 1;
	echo "	NG.";
	exit 1;
fi

fi
#postgresのいんすころーる
if $db_local; then
	tput setaf 3;
	echo "Process: install postgres;"
	tput setaf 7;
	apt -qq install -y postgresql-common;
	sh /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -i -v 15;

	tput setaf 3;
	echo "Process: create user and database on postgres;"
	tput setaf 7;
	sudo -iu postgres psql -c "CREATE ROLE $db_user LOGIN CREATEDB PASSWORD '$db_pass';" -c "CREATE DATABASE $db_name OWNER $db_user;"
fi
#docker準備
#region docker setting
if [ $method != "systemd" ]; then
	#region enable rootless docker
	tput setaf 3;
	echo "Process: use rootless docker;"
	tput setaf 7;

	systemctl disable --now docker.service docker.socket
	loginctl enable-linger "$misskey_user"
	sleep 5
	su "$misskey_user" <<-MKEOF
	set -eu;
	cd ~;
	export XDG_RUNTIME_DIR=/run/user/$m_uid;
	export DOCKER_HOST=unix:///run/user/$m_uid/docker.sock;
	systemctl --user --no-pager

	dockerd-rootless-setuptool.sh install

	tput setaf 2;
	echo "Check: docker setup;";
	tput setaf 7;
	docker ps;
	MKEOF
	#endregion

	#region modify postgres confs
	if $db_local; then
		tput setaf 3;
		echo "Process: modify postgres confs;"
		tput setaf 7;
		pg_hba=$(sudo -iu postgres psql -t -P format=unaligned -c 'show hba_file')
		pg_conf=$(sudo -iu postgres psql -t -P format=unaligned -c 'show config_file')
		[[ $(ip addr | grep "$docker_host_ip") =~ /([0-9]+) ]] && subnet=${BASH_REMATCH[1]};

		hba_text="host $db_name $db_user $docker_host_ip/$subnet md5"
		if ! grep "$hba_text" "$pg_hba"; then
			echo "$hba_text" >> "$pg_hba";
		fi

		pgconf_search="#listen_addresses = 'localhost'"
		pgconf_text="listen_addresses = '$docker_host_ip'"
		if grep "$pgconf_search" "$pg_conf"; then
			sed -i'.mkmoded' -e "s/$pgconf_search/$pgconf_text/g" "$pg_conf";
		elif grep "$pgconf_text" "$pg_conf"; then
			echo "	skip"
		else
			echo "Please edit postgresql.conf to set [listen_addresses = '$docker_host_ip'] by your hand."
			read -r -p "Enter the editor command and press Enter key > " -e -i "nano" editorcmd
			$editorcmd "$pg_conf";
		fi

		systemctl restart postgresql;
	fi
	#endregion
fi
#endregion
#redis準備
#region modify redis conf
if $redis_local; then
	tput setaf 3;
	echo "Process: modify redis confs;"
	tput setaf 7;
	if [ -f /etc/redis/redis.conf ]; then
		echo "requirepass $redis_pass" > /etc/redis/misskey.conf
		[ $method != "systemd" ] && echo "bind $docker_host_ip" >> /etc/redis/misskey.conf

		if ! grep "include /etc/redis/misskey.conf" /etc/redis/redis.conf; then
			echo "include /etc/redis/misskey.conf" >> /etc/redis/redis.conf;
		else
			echo "	skip"
		fi
	else
		echo "Couldn't find /etc/redis/redis.conf."
		echo "Please modify redis config in another shell like following."
		echo ""
		echo "requirepass $redis_pass"
		[ $method != "systemd" ] && echo "bind $docker_host_ip"
		echo ""
		read -r -p "Press Enter key to continue> "
	fi
	systemctl restart redis-server;
fi
#endregion
#Misskey(Systemd)準備
if [ $method == "systemd" ]; then
#region systemd
#region work with misskey user
su "$misskey_user" << MKEOF;
set -eu;
cd ~
cd "$misskey_directory";

tput setaf 3;
echo "Process: install npm packages;"
tput setaf 7;
NODE_ENV=production pnpm install --frozen-lockfile;

tput setaf 3;
echo "Process: build misskey;"
tput setaf 7;
NODE_OPTIONS=--max_old_space_size=3072 NODE_ENV=production pnpm run build;

tput setaf 3;
echo "Process: initialize database;"
tput setaf 7;
NODE_OPTIONS=--max_old_space_size=3072 pnpm run init;

tput setaf 3;
echo "Check: If Misskey starts correctly;"
tput setaf 7;
if NODE_ENV=production timeout 40 npm start 2> /dev/null | grep -q "Now listening on port"; then
	echo "	OK.";
else
	tput setaf 1;
	echo "	NG.";
fi
MKEOF
#endregion
#Misskeyのデーモン準備
tput setaf 3;
echo "Process: create misskey daemon;"
tput setaf 7;
cat > "/etc/systemd/system/$host.service" << _EOF
[Unit]
Description=Misskey daemon

[Service]
Type=simple
User=$misskey_user
ExecStart=$(command -v npm) start
WorkingDirectory=/home/$misskey_user/$misskey_directory
Environment="NODE_ENV=production"
TimeoutSec=60
StandardOutput=journal
StandardError=journal
SyslogIdentifier="$host"
Restart=always

[Install]
WantedBy=multi-user.target
_EOF

#Misskey起動！
systemctl daemon-reload;
systemctl enable "$host";
systemctl start "$host";
systemctl status "$host" --no-pager;

#endregion
#Misskey(Docker)準備
elif [ $method == "docker" ]; then
#region docker build
tput setaf 3;
echo "Process: build docker image;"
tput setaf 7;

sudo -iu "$misskey_user" XDG_RUNTIME_DIR=/run/user/$m_uid DOCKER_HOST=unix:///run/user/$m_uid/docker.sock docker build -t $docker_repository "/home/$misskey_user/$misskey_directory";
#endregion
fi

echo "";

#MisskeyのDocker向け最終準備
if [ $method != "systemd" ]; then
	tput setaf 2;
	tput bold;
	echo "ALL MISSKEY INSTALLATION PROCESSES ARE COMPLETE!";
	echo "Now all we need to do is run docker run."
	tput setaf 7;
	echo "Watch the screen."
	echo "When it shows \"Now listening on port $misskey_port on https://$host\","
	echo "press Ctrl+C to exit logs and jump to https://$host/ and continue setting up your instance.";
	echo ""
	echo "This script version is v$version.";
	echo "Please follow @joinmisskey@misskey.io to address bugs and updates.";
	echo ""
	read -r -p "Press Enter key to execute docker run> ";
	echo ""
	tput setaf 3;
	echo "Process: docker run;"
	tput setaf 7;
	docker_container=$(sudo -iu "$misskey_user" XDG_RUNTIME_DIR=/run/user/$m_uid DOCKER_HOST=unix:///run/user/$m_uid/docker.sock docker run -d -p $misskey_port:$misskey_port --add-host=$misskey_localhost:$docker_host_ip -v "/home/$misskey_user/$misskey_directory/files":/misskey/files -v "/home/$misskey_user/$misskey_directory/.config/default.yml":/misskey/.config/default.yml:ro --restart unless-stopped -t "$docker_repository");
	echo "$docker_container";

	#Misskeyのユーザーに切り替えー
	su "$misskey_user" << MKEOF
	set -eu;
	cd ~;

	#Misskey(Docker)の環境ファイルの準備をしますよー
	tput setaf 3;
	echo "Process: create .misskey-docker.env;"
	tput setaf 7;

#Misskey(Docker)の環境ファイルに情報をぶっこむ
cat > ".misskey-docker.env" << _EOF
method="$method"
host="$host"
misskey_port=$misskey_port
misskey_directory="$misskey_directory"
misskey_localhost="$misskey_localhost"
docker_host_ip=$docker_host_ip
docker_repository="$docker_repository"
docker_container="$docker_container"
version="$version"
_EOF
MKEOF

	sudo -iu "$misskey_user" XDG_RUNTIME_DIR=/run/user/$m_uid DOCKER_HOST=unix:///run/user/$m_uid/docker.sock docker logs -f $docker_container;

#ここからSystemdの人向け最終準備ー
else

	#MisskeyのIDに切り替えー
	su "$misskey_user" << MKEOF
	set -eu;
	cd ~;

	#Misskeyの環境ファイルの準備をしますよー
	tput setaf 3;
	echo "Process: create .misskey.env;"
	tput setaf 7;

#Misskeyの環境ファイルに情報をぶっこむ
cat > ".misskey.env" << _EOF
host="$host"
misskey_port=$misskey_port
misskey_directory="$misskey_directory"
misskey_localhost="$misskey_localhost"
version="$version"
_EOF
MKEOF

	#最後のご挨拶
	tput setaf 2;
	tput bold;
	echo "ALL MISSKEY INSTALLATION PROCESSES ARE COMPLETE!";
	echo "Jump to https://$host/ and continue setting up your instance.";
	tput setaf 7;
	echo "This script version is v$version.";
	echo "Please follow @joinmisskey@misskey.io to address bugs and updates.";
fi
