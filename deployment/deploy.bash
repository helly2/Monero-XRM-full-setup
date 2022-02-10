#!/bin/bash
echo "This assumes that you are doing a green-field install.  If you're not, please exit in the next 15 seconds."
sleep 15
echo "Continuing install, this will prompt you for your password if you're not already running as root and you didn't enable passwordless sudo.  Please do not run me as root!"
if [[ `whoami` == "root" ]]; then
    echo "You ran me as root! Do not run me as root!"
    exit 1
fi
ROOT_SQL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
CURUSER=$(whoami)
sudo timedatectl set-timezone Etc/UTC
sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo --preserve-env=DEBIAN_FRONTEND apt-get -y upgrade
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOT_SQL_PASS"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOT_SQL_PASS"
echo -e "[client]\nuser=root\npassword=$ROOT_SQL_PASS" | sudo tee /root/.my.cnf
DEBIAN_FRONTEND=noninteractive sudo --preserve-env=DEBIAN_FRONTEND apt-get -y install libcap2-bin git python python-virtualenv python3-virtualenv curl ntp build-essential screen cmake pkg-config libboost-all-dev libevent-dev libunbound-dev libminiupnpc-dev libunwind8-dev liblzma-dev libldns-dev libexpat1-dev mysql-server lmdb-utils libzmq3-dev libsodium-dev
cd ~
git clone https://github.com/helly2/nodejs-pool.git
sudo apt-get install -y ntp
sudo timedatectl set-ntp on
sudo service ntp restart
cd /usr/local/src
sudo git clone https://github.com/monero-project/monero.git
cd monero
sudo git checkout v0.17.2.3
sudo git submodule update --init
USE_SINGLE_BUILDDIR=1 sudo --preserve-env=USE_SINGLE_BUILDDIR make -j$(nproc) release || USE_SINGLE_BUILDDIR=1 sudo --preserve-env=USE_SINGLE_BUILDDIR make release || exit 0
sudo cp ~/Monero-XRM-pool-full-setup-guide/deployment/monero.service /lib/systemd/system/
sudo useradd -m monerodaemon -d /home/monerodaemon
sudo systemctl daemon-reload
sudo systemctl enable monero
sudo systemctl start monero
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install v14.17.3
nvm alias default v14.17.3
cd ~/Monero-XRM-pool-full-setup-guide
npm install
npm install -g pm2
openssl req -subj "/C=IT/ST=Pool/L=Daemon/O=Mining Pool/CN=mining.pool" -newkey rsa:2048 -nodes -keyout cert.key -x509 -out cert.pem -days 36500
mkdir ~/pool_db/
sed -r "s/(\"db_storage_path\": ).*/\1\"\/home\/$CURUSER\/pool_db\/\",/" config_example.json > config.json
cd ~
git clone https://github.com/MoneroOcean/moneroocean-gui.git
cd moneroocean-gui
DEBIAN_FRONTEND=noninteractive sudo --preserve-env=DEBIAN_FRONTEND sudo apt install -y gconf-service libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 ca-certificates fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils
apt install -y libx11-xcb1 libxcomposite-dev libxcursor-dev libxcursor-dev libxi-dev libxtst-dev libcups2-dev libxss-dev libxrandr-dev libatk1.0-0 libatk-bridge2.0-0
npm install -g uglifycss uglify-js html-minifier
npm install -D critical@latest
./build.sh
cd build
sudo ln -s `pwd` /var/www
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
sudo cp ~/nodejs-pool/deployment/caddyfile /etc/caddy/Caddyfile
sudo service caddy restart
cd ~
sudo env PATH=$PATH:`pwd`/.nvm/versions/node/v14.17.3/bin `pwd`/.nvm/versions/node/v14.17.3/lib/node_modules/pm2/bin/pm2 startup systemd -u $CURUSER --hp `pwd`
cd ~/Monero-XRM-pool-full-setup-guide
sudo chown -R $CURUSER ~/.pm2
echo "Installing pm2-logrotate in the background!"
pm2 install pm2-logrotate &
sudo mysql -u root --password=$ROOT_SQL_PASS < deployment/base.sql
sudo mysql -u root --password=$ROOT_SQL_PASS pool -e "INSERT INTO pool.config (module, item, item_value, item_type, Item_desc) VALUES ('api', 'authKey', '`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`', 'string', 'Auth key sent with all Websocket frames for validation.')"
sudo mysql -u root --password=$ROOT_SQL_PASS pool -e "INSERT INTO pool.config (module, item, item_value, item_type, Item_desc) VALUES ('api', 'secKey', '`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`', 'string', 'HMAC key for Passwords.  JWT Secret Key.  Changing this will invalidate all current logins.')"
pm2 start init.js --name=api --log-date-format="YYYY-MM-DD HH:mm Z" -- --module=api
bash ~/nodejs-pool/deployment/install_lmdb_tools.sh
echo "You're setup!  Please read the rest of the readme for the remainder of your setup and configuration.  These steps include: Setting your Fee Address, Pool Address, Global Domain, and the Mailgun setup!"
