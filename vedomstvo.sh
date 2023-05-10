#!/bin/bash

export LANG="ru_RU.UTF-8"

export PGPASSWORD='XZL9tA2LaE63fpDyaE23PIZuFxSgrEYj' 

TMPFILE="/tmp/vedomstvo.tmp"
LOCKFILE="/tmp/uinbot.lock"

exec 100>"$LOCKFILE" || exit 1
exec 101>"$TMPFILE" || exit 2

trap 'rm -rf $LOCKFILE $TMPFILE;' 0 1 2 3 15
/etc/dovecot/flock -w 3598 101 || exit 3

while read -r -d $'\n' LINE
do
	echo "$LINE"
done | /etc/dovecot/sed -n "/<html>/,/<\/html>/p" | /etc/dovecot/qprint -d >&101
if /etc/dovecot/grep -q "о государственном кадастровом учете и (или) государственной регистрации прав" "$TMPFILE"
then
	URL=$(/etc/dovecot/sed -z 's/.*a href="\(.*\)".*/\1\n/' "$TMPFILE")
	FILENAME=$(/etc/dovecot/curl --no-progress-meter -kLI --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 YaBrowser/22.11.3.818 Yowser/2.5 Safari/537.36" "$URL" | /etc/dovecot/grep "Content-Disposition:" | /etc/dovecot/sed "s/.*filename=\(.*\)$/\1/" | /etc/dovecot/tr -d '\n\r')
	FILENAME=${FILENAME%.*}
	[ -z "$FILENAME" ] && { echo "Ошибка при запросе к серверу Росреестра: $?"; exit 4; }
	/etc/dovecot/flock -w 3598 100 || exit 5
	trap 'rm -rf $LOCKFILE $TMPFILE $FILENAME $FILENAME.zip;' 0 1 2 3 15
	/etc/dovecot/curl --no-progress-meter -kLOJ --clobber --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 YaBrowser/22.11.3.818 Yowser/2.5 Safari/537.36" "$URL" || { echo "Ошибка при скачивании файла: $?"; exit 6; }
	/etc/dovecot/mkdir -p "$FILENAME" || { echo "Ошибка при создании директории для распаковки: $?"; exit 7;}
	/etc/dovecot/unzip -qod "$FILENAME" "$FILENAME.zip" || { echo "Ошибка при распаковке файлов: $?"; exit 8;}
	for FILE in "$FILENAME"/*.html
	do
		VEDOMSTVO="$(/etc/dovecot/basename "$FILE" | sed "s/.*\(Vedomstvo.*[0-9]\{6\}\).*/\1/")"
		/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO vedomstvo (vedomstvo) VALUES ('$VEDOMSTVO') ON CONFLICT DO NOTHING"
		readarray -t OBJECTS < <(/etc/dovecot/grep "Кадастровый номер:" "$FILE" | /etc/dovecot/sed "s/.*Кадастровый номер: \(.*\)<.*/\1/")
		for OBJECT in "${OBJECTS[@]}"
		do
			/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO objects (id) VALUES ('$OBJECT') ON CONFLICT DO NOTHING"
			/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO vedomstvo_objects (vedomstvo, object) SELECT '$VEDOMSTVO', '$OBJECT' WHERE NOT EXISTS(SELECT 1 FROM vedomstvo_objects WHERE vedomstvo = '$VEDOMSTVO' AND object = '$OBJECT')"
		done
	done
fi
exit 0
