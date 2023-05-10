#!/bin/bash

export LANG="ru_RU.UTF-8"

ISVEDOMSTVO=0
ISDATA=0
ISFILES=0

exec 100>"/tmp/uinbot.lock" || exit 1

while read -r -d $'\n' LINE
do
	if [ $ISVEDOMSTVO -eq 0 ]
	then
		ENCSTR="$(echo "$LINE" | /etc/dovecot/sed -nE 's/Subject: =\?utf-8\?[bBqQ]\?(.+?)\?=/\1/p')"
		if [ -n "$ENCSTR" ]
		then
			if [ -n "$(echo "$ENCSTR" | /etc/dovecot/sed -nE '/^=..=/p')" ]
			then
				DECSTR="$(echo "$ENCSTR" | /etc/dovecot/qprint -d)"
			else
				DECSTR="$(echo "$ENCSTR" | /etc/dovecot/openssl base64 -d)"
			fi
			if echo "$DECSTR" | /etc/dovecot/grep -q 'Завершено *Vedomstvo'
			then
				ISVEDOMSTVO=1
			fi
		fi
	fi
	if [ $ISVEDOMSTVO -eq 1 ] && [ $ISDATA -eq 0 ]
	then
		if [ -n "$(echo "$LINE" | /etc/dovecot/sed -nE "s/^\r*\n*$/1/p")" ]
		then
			ISDATA=1
			continue
		fi
	fi
	if [ $ISDATA -eq 1 ]
	then
		DATA="$DATA$LINE"
	fi
done

{ [ $ISVEDOMSTVO -eq 0 ] || [ $ISDATA -eq 0 ]; } && exit 0

DECDATA="$(echo "$DATA" | /etc/dovecot/openssl base64 -d)"
URL="$(echo "$DECDATA" | /etc/dovecot/sed -nE 's/.*href="(.*?)".*/\1/p')"
VEDOMSTVO="$(echo "$DECDATA" | /etc/dovecot/sed -nE 's/.*Обработка обращения (.*?) завершена.*/\1/p')"

trap 'rm -rf /tmp/uinbot.lock $VEDOMSTVO $VEDOMSTVO.zip;' 0 1 2 3 15
/etc/dovecot/flock -w 3598 100 || exit 1

/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO vedomstvo (vedomstvo) VALUES ('$VEDOMSTVO') ON CONFLICT DO NOTHING" || { echo "Ошибка при обращении к БД: 1-$?"; exit 1; }

/etc/dovecot/curl --no-progress-meter -kLo "$VEDOMSTVO.zip" --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 YaBrowser/22.11.3.818 Yowser/2.5 Safari/537.36" "$URL" || { echo "Ошибка при скачивании файла: $?"; exit 2; }

/etc/dovecot/mkdir -p "$VEDOMSTVO" || { echo "Ошибка при создании директории для распаковки: $?"; exit 3;}
/etc/dovecot/unzip -qod "$VEDOMSTVO" "$VEDOMSTVO.zip" || { echo "Ошибка при распаковке файлов: $?"; exit 4;}

if [ $ISFILES ]
then
	for file in "$VEDOMSTVO"/*.xml
	do
		if echo "$file" | /etc/dovecot/grep -q "╨н╨Я"
		then
			continue
		fi
		#Выписка о правоустанавливающих
		source /etc/dovecot/rosreestr_about/about_document.sh
		#Выписка об объекте
		source /etc/dovecot/rosreestr_about/about_object.sh
		#Выписка после регистрации
		source /etc/dovecot/rosreestr_about/about_reg.sh
		#Выписка о дееспособности
		source /etc/dovecot/rosreestr_about/about_legalcapacity.sh
		#Выписка о стоимости объекта недвижимого имущества
		source /etc/dovecot/rosreestr_about/about_cost.sh
	done
fi

exit 0
