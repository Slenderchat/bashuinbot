#!/bin/bash
INSPECT=$(mktemp)
SENDMAIL="/usr/sbin/sendmail -G -i"
SENDMAILARG="$*"
EX_TEMPFAIL=75
EX_UNAVAILABLE=69
trap 'rm -f $INSPECT' 0 1 2 3 15
stat "$INSPECT" > /dev/null || { echo "$INSPECT" does not exist; exit $EX_TEMPFAIL; }
cat > "$INSPECT" || { echo Cannot save mail to file; exit $EX_TEMPFAIL; }
removeReplyTo() {
	TEMP=$(mktemp)
	ISREPLYTO=0
	true > "$TEMP"
	while IFS= read -r LINE
	do
		if [ -n "$(echo "$LINE" | grep '^Reply-To: ')" ]
		then
			ISREPLYTO=1
		fi
		if [ $ISREPLYTO -eq 1 ] && [ -z "$(echo "$LINE" | grep '^Reply-To: ')" ] && [ -n "$(echo "$LINE" | grep '^.*: ')" ]
		then
			ISREPLYTO=0
		fi
		[ $ISREPLYTO -eq 0 ] && echo "$LINE" >> "$TEMP"
	done <"$1"
	cat "$TEMP" > "$1"
}
filter(){
	STATE=0
	while IFS= read -r line
	do
		if [ -z "$line" ]
		then
			break
		else
			if [ $STATE -eq 0 ]
			then
				TMP=$(echo "$line" | grep '^From: ')
				if [ -n "$TMP" ]
				then
					FROM=$TMP
					STATE=1
				fi
				continue
			else
				if [ -z "$(echo "$line" | grep '^.\+: ')" ] 
				then
					FROM="$FROM$line"
					continue
				fi
			fi
		fi
	done <"$INSPECT"
	if [ -n "$(echo "$FROM" | grep 'notyalta.ru')" ] && [ -z "$(echo "$FROM" | grep 'derkach@notyalta.ru')" ]
	then
		removeReplyTo "$INSPECT"
		sed -i "s/^From: /Sender: /" "$INSPECT"
		sed -i "/^To: /i Bcc: <derkach@notyalta.ru>\r\nFrom: =\?UTF-8\?B\?0J3QvtGC0LDRgNC40LDQu9GM0L3QsNGPINC60L7QvdGC0L7RgNCwIA==\?=\r\n =\?UTF-8\?B\?0JTQtdGA0LrQsNGH0LAg0JDQu9C10LrRgdC10Y8g\?=\r\n =\?UTF-8\?B\?0J7Qu9C10LPQvtCy0LjRh9Cw\?= <derkach@notyalta.ru>" "$INSPECT"
		SENDMAILARG="$SENDMAILARG derkach@notyalta.ru"
		return 0
	fi
	return 0
}
filter || { echo Message content rejected; exit $EX_UNAVAILABLE; }
$SENDMAIL $SENDMAILARG <"$INSPECT"
exit $?
