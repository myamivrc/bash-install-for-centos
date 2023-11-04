# うるせぇ！みゃみーさんはMisskeyでもRHEL系を使うんだ！
Ubuntuという専門外なOSで日々Misskeyの運営に四苦八苦しているみゃみーさん。  
ついにMisskeyをRHEL系で動かすことを決意しました。  
  
つまるところNodejs、依存関係を置き換えればこっちのものです。  
動作も確認したのでこちらに公開しますね。  
(スクリプト版は誠意開発中です)
  
スペシャルサンクス  
手順を作成するにあたりまして以下の手順書を参考に作成させていただきました。  
ここに感謝を申し上げます。  
・Misskey Hub Ubuntu版Misskeyインストール方法詳説  
https://misskey-hub.net/docs/install/ubuntu-manual.html

## 動作検証環境
・Red Hat Enterprise Linux 8.7  
・Rocky Linux 8.7  
  
# 作業手順は執筆中です！！！まだ実行しないでください！

## 作業手順
### ミスキーユーザを作成
```
sudo adduser misskey
```

### curlをインストール  
```
sudo yum install -y curl
```

### nodejsをインストール  
```
curl -sL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
```
```
sudo yum install -y nodejs
```
※警告文が出るが気にせず待つ

### Node.jsがインストールされたので、バージョンを確認する。  
```
node -v
```  
### corepackを有効化※corepackってなんだよって人はgoogleでcorepackで調べて♡
```
sudo corepack enable
```
### ぽすとぐれをいんすとーる
```
sudo yum install -y @postgresql
```
### ぽすとぐれを初期化
```
sudo /usr/bin/postgresql-setup --initdb
```
### postgressqlを起動＆立ち上げっぱなし＆状態確認（activeならOK）
```
systemctl start postgresql
systemctl enable postgresql
systemctl status postgresql
```

### postgresqlにあくせす～
```
sudo -u postgres psql
```

### みすきーようユーザを作ろう
```
CREATE ROLE misskey LOGIN PASSWORD 'hoge';  
```

### みすきーようデータベースさくせい～
```
CREATE DATABASE mk1 OWNER misskey;
```

### ぽすとぐれおわり～
```
¥q
```

### postgresqlのpeerを切るために設定ファイルを開く(これを切り忘れるとマイグレーションが出来ない場合がある)
```
vi /var/lib/pgsql/data/pg_hba.conf
```
その後設定ファイルの一番したに行き、peerとidentとなっている個所をすべてmd5に書き換える

### postgresqlを再起動してpostgresの作業終わり
```
sudo systemctl restart postgresql
```

### epelのインストール(certbotのインストールに必要)
```
sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
```
### rpmFusionのインストール(FFmpegのインストールに必要)
```
sudo dnf install -y "https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm"
```

### ffmpegの前提であるSDL2が入っているリポジトリをON
```
yum install dnf-plugins-core;
```
```
yum config-manager --set-enabled powertools;
```

### めんどくせぇ！止められねぇ！必要インストールスイッチオン！
```
sudo dnf install -y nano jq gnupg2 ca-certificates redhat-lsb-core certbot firewalld git ffmpeg
```

### RHEL系民はfirewalldを使おうね♡
```
sudo systemctl start firewalld
sudo systemctl enable firewalld
```

### お好みでcloudflare用インストール
```
python3-certbot-dns-cloudflare　
sudo apt install -y curl ca-certificates gnupg2 lsb-release
```

### Redisをインストール！
```
sudo dnf module install redis:6
```

### Redisを起動＆立ち上げっぱなし＆状態確認（activeならOK）
```
sudo systemctl start redis
sudo systemctl enable redis
sudo systemctl status redis
```

### もういっちょredisの動作確認(PONGが帰ってくればOK)
```
redis-cli ping
```


### リポジトリを作成(ツールは適当に読み替えてくれや)
``
sudo vi /etc/yum.repos.d/nginx.repo
``  
#### 実行後以下を記入
```
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
```

### Nginx用リポジトリを有効  
```
sudo yum-config-manager --enable nginx-mainline
```

### nginxインストール  
```
sudo yum install -y nginx
```

### nginx起動三姉妹  
```
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```

### nginx君ちゃんと動いてるよね・・・？
```
curl http://localhost
```

### 怒涛のfirewalldポート開け
```
sudo firewall-cmd --add-port=80/tcp --zone=public --permanent
sudo firewall-cmd --add-port=443/tcp --zone=public --permanent
```

### とどめのリロード
```
sudo firewall-cmd --reload
```

### misskeyインストールの時間だあああああああ
```
sudo su - misskey
```

### misskeyファイルを準備
```
git clone -b master https://github.com/misskey-dev/misskey.git --recurse-submodules
```
```
cd misskey
```
```
git checkout master
```

### 設定ファイル記入  
```
vi .config/default.yml
```

### 以下を記入する
```
# ● Misskeyを公開するURL
url: https://example.tld/
# ポートを3000とする。
port: 3000

# ● PostgreSQLの設定。
db:
  host: localhost
  port: 5432
  db  : mk1 # 〇 PostgreSQLのデータベース名
  user: misskey # 〇 PostgreSQLのユーザー名
  pass: hoge # ● PostgreSQLのパスワード

# 　 Redisの設定。
redis:
  host: localhost
  port: 6379

# 　 IDタイプの設定。
id: 'aid'

# 　 syslog
syslog:
  host: localhost
  port: 514
```

### いったんMisskeyユーザの作業終了
```
exit
```

### 参考URLをもとにかきかき(検証環境の時は2つ目のserverを消してね)  
```
sudo vi /etc/nginx/conf.d/misskey.conf
```

参考URL：https://misskey-hub.net/docs/admin/nginx.html

### nginxの設定ファイルテスト～  
```
sudo nginx -t
```  

### みすきー準備  
```
pnpm run init
```

### くらえ！渾身のMisskeyスタート！！！  
```
NODE_ENV=production pnpm run start
```
## もしもFork元にご迷惑おかけしていたら  
もともと実行スクリプトを参考にさせていただこうと思いフォークをしているにゃ。  
そのためみゃみーさんの手違いでフォークもとにご迷惑をおかけしてしまったら大変申し訳ないにゃ・・・  
その時はお手数ですが以下のご連絡お願いしますにゃ・・・
>　@myami@myamisskey.ddo.jp
