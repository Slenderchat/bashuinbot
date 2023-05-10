#!/bin/bash

export LANG="ru_RU.UTF-8"

ISUIN=0
ISDATE=0
ISDATA=0
DATA=

UIN=
VEDOMSTVO=
SUM=
DATE=
NUMLINES=

pushToDB() {
	for ((i=1;i<=NUMLINES;i++))
	do
		tUIN=$(echo "$UIN" | /etc/dovecot/sed "${i}q;d")
		tSUM=$(echo "$SUM" | /etc/dovecot/sed "${i}q;d")
		tSUM=$(echo "$tSUM" | /etc/dovecot/sed -nE 's/,// ; s/\..*//p')
		/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO uins (id, sum) VALUES ('$tUIN', '$tSUM') ON CONFLICT DO NOTHING"
		/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO vedomstvo_uins (vedomstvo, uin) SELECT '$VEDOMSTVO', '$tUIN' WHERE NOT EXISTS(SELECT 1 FROM vedomstvo_uins WHERE vedomstvo = '$VEDOMSTVO' AND uin = '$tUIN')"
	done
}

pushToTG() {
	DATE=$(echo "$DATE" | /etc/dovecot/sed -nE 's/[A-Za-z]*, *([0-9].*) \+.*/\1/p')
	DATE=$(LANG=ru_RU.UTF-8 /etc/dovecot/date -d "$DATE" '+%A %d.%m.%Y в %H:%m')
	readarray -t OBJECTS < <(/etc/dovecot/psql -q uinbot uinbot -c "COPY (SELECT object FROM vedomstvo_objects WHERE vedomstvo = '$VEDOMSTVO') TO STDOUT")
	if [ ${#OBJECTS[@]} -gt 0 ]
	then
		RESULT="Поступили УИН по следующим объектам:"
		i=1
		for OBJECT in "${OBJECTS[@]}"
		do
			LOCATION=$(/etc/dovecot/psql -q uinbot uinbot -c "COPY (SELECT location FROM objects WHERE id = '$OBJECT') TO STDOUT")
			[ "$LOCATION" = "\N" ] && LOCATION=""
			if [ -n "$LOCATION" ]
			then
				RESULT="$(printf '%b' "$RESULT\n$i. $OBJECT, адрес: $LOCATION")"
			else
				RESULT="$(printf '%b' "$RESULT\n$i. $OBJECT, адрес: нет информации об адресе")"
			fi
			RESULT="$(printf '%b' "$RESULT, правообладатели:")"
			readarray -t SUBJECTS < <(/etc/dovecot/psql -q uinbot uinbot -c "COPY (SELECT owner FROM object_owners WHERE object = '${OBJECTS[0]}') TO STDOUT")
			ii=1
			nSUBJECTS=${#SUBJECTS[@]}
			if [ ${#SUBJECTS[@]} -gt 0 ]
			then
				for SUBJECT in "${SUBJECTS[@]}"
				do
					if [ $i == "$nSUBJECTS" ]
					then
						RESULT=$(printf '%b' "$RESULT\n$i.$ii. $SUBJECT.")
					else
						RESULT=$(printf '%b' "$RESULT\n$i.$ii. $SUBJECT;")
					fi
					((ii++))
				done
			else
				RESULT=$(printf '%b' "$RESULT\n$i.$ii. нет информации о правообладателях")
			fi
			((i++))
		done
		/etc/dovecot/curl -sd "chat_id=$CHATID" --data-urlencode "text=$RESULT" "https://api.telegram.org/bot$TOKEN/sendMessage" > /dev/null
	fi
	for ((i=1;i<=NUMLINES;i++))
	do
		tUIN=$(echo "$UIN" | /etc/dovecot/sed "${i}q;d")
		tSUM=$(echo "$SUM" | /etc/dovecot/sed "${i}q;d")
		tSUM=$(echo "$tSUM" | /etc/dovecot/sed -nE 's/,// ; s/\..*//p')
		/etc/dovecot/curl -sd "chat_id=$CHATID" --data-urlencode "text=$tUIN" "https://api.telegram.org/bot$TOKEN/sendMessage" > /dev/null
		sleep 0.1
		/etc/dovecot/curl -sd "chat_id=$CHATID" --data-urlencode "text=$tSUM" "https://api.telegram.org/bot$TOKEN/sendMessage" > /dev/null
		sleep 0.1
	done
}

exec 100>/tmp/uinbot.lock || exit 1
while read -r -d $'\n' LINE
do
	if [ $ISDATE -eq 0 ]
	then
		DATE=$(echo "$LINE" | /etc/dovecot/sed -nE "s/Date: (.+)/\1/p;")
		if [ -n "$DATE" ]
		then
			ISDATE=1
			continue
		fi
	fi
	if [ $ISUIN -eq 0 ]
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
			if echo "$DECSTR" | /etc/dovecot/grep -q 'УИН *по'
			then
				ISUIN=1
			fi
		fi
	fi
	if [ $ISUIN -eq 1 ] && [ $ISDATE -eq 1 ] && [ $ISDATA -eq 0 ]
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
{ [ $ISUIN -eq 0 ] || [ $ISDATE -eq 0 ] || [ $ISDATA -eq 0 ]; } && exit 0
DECDATA="$(echo "$DATA" | /etc/dovecot/openssl base64 -d)"
UIN="$(echo "$DECDATA" | /etc/dovecot/grep -oE '([0-9]{20})')"
NUMLINES=$(echo "$UIN" | /etc/dovecot/wc -l)
VEDOMSTVO="$(echo "$DECDATA" | /etc/dovecot/sed -nE 's/.*<p>По обращению (.*?) сформирована квитанция.*/\1/p')"
SUM="$(echo "$DECDATA" | /etc/dovecot/grep -oE '([0-9,]*\.[0-9]{2} руб\.)')"
if [ -n "$UIN" ] && [ -n "$VEDOMSTVO" ]
then
	trap 'rm -f /tmp/uinbot.lock' 0 1 2 3 15
	/etc/dovecot/flock -w 3598 100 || exit 1
	pushToDB
	pushToTG
fi
exit 0
