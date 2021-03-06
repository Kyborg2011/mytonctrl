#!/bin/sh
set -e

# Проверить sudo
if [ "$(id -u)" != "0" ]; then
	echo "Please run script as root"
	exit 1
fi

# Цвета
COLOR='\033[93m'
ENDC='\033[0m'

# Генерация порта для валидатора
ip=$(curl --silent ifconfig.me)
echo -e "${COLOR}[1/6]${ENDC} Generating validator connection port"
port=$(shuf -i 2000-65000 -n 1)
addr=${ip}:${port}
echo "${port}" > /tmp/vport.txt

# Создать переменные
dbPath=/var/ton-work/db
logPath=/var/ton-work/log
validatorAppPath=/usr/bin/ton/validator-engine/validator-engine
validatorConfig=/usr/bin/ton/validator-engine/ton-global.config.json

# Подготовить папки валидатора
echo -e "${COLOR}[2/6]${ENDC} Preparing the validator folder"
rm -rf ${dbPath}
mkdir -p ${dbPath}

# Создать пользователя
echo -e "${COLOR}[3/6]${ENDC} Creating user 'validator'"
result=$(cat /etc/passwd)
if echo ${result} | grep 'validator'; then
	echo "user 'validator' exists"
else
	/usr/sbin/useradd -d /dev/null -s /dev/null validator
fi

# Проверка первого запуска валидатора
configPath=${dbPath}/config.json
#rm -f ${configPath} &&

# Первый запуск валидатора
echo -e "${COLOR}[4/6]${ENDC} Creating config file"
${validatorAppPath} -C ${validatorConfig} --db ${dbPath} --ip ${addr} -l ${logPath}

# Сменить права на нужные директории
chown -R validator:validator /var/ton-work

# Создать копию конфигурации во времянной папке
cp -r ${configPath} /tmp/vconfig.json
chmod 777 /tmp/vconfig.json

# Прописать автозагрузку в cron
echo -e "${COLOR}[5/6]${ENDC} Registering CRON autoload task 'validator'"
cmd="${validatorAppPath} -d -C ${validatorConfig} --db ${dbPath} --ip ${addr} -l ${logPath}"
cronText="@reboot /bin/sleep 60 && ${cmd}"
echo "${cronText}" > mycron && crontab -u validator mycron && rm mycron

# Конец
echo -e "${COLOR}[6/6]${ENDC} Validator configuration completed"
