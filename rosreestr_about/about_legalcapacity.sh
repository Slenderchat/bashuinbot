#!/bin/bash
if [ -n "$(/etc/dovecot/xml sel -t -v "name(/*[starts-with(name(), 'exract_notice_absence_request_info')])" "$file")" ] && [ "$(/etc/dovecot/xml sel -t -v "//view_request_info" "$file")" == "о признании правообладателя недееспособным или ограниченно дееспособным" ]
then
	WHAT="выписка о дееспособности"
	SUBJECT="$(/etc/dovecot/xml sel -t -v "//right_holders" "$file" | sed -nE "s/;.*//p")"
	LEGALCAPACITY="$(/etc/dovecot/xml sel -t -v "//incapacity" "$file")"
	LEGALCAPACITY="${LEGALCAPACITY,,}"
	if [ -z "$LEGALCAPACITY" ]
	then
		LEGALCAPACITY="NULL"
		TGCAPACITY="сведения отсутствуют"
	else
		if [ "$LEGALCAPACITY" == "не поступало" ]
		then
			LEGALCAPACITY="TRUE"
			TGCAPACITY="дееспособность не ограничена"
		else
			LEGALCAPACITY="FALSE"
			TGCAPACITY="ДЕЕСПОСОБНОСТЬ ОГРАНИЧЕНА"
		fi
	fi
	/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO subjects (name, legalcapacity) VALUES ('$SUBJECT', $LEGALCAPACITY) ON CONFLICT(name) DO UPDATE SET legalcapacity = $LEGALCAPACITY"
	/etc/dovecot/curl -sF "chat_id=$CHATID" -F "media=[{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf)\"},{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf.sig)\", \"caption\": \"Поступила $WHAT, относительно $SUBJECT: $TGCAPACITY\"}]" -F "$(/etc/dovecot/basename "${file%.xml}".pdf)=@${file%.xml}.pdf" -F "$(/etc/dovecot/basename "${file%.xml}".pdf.sig)=@${file%.xml}.pdf.sig" "https://api.telegram.org/bot$TOKEN/sendMediaGroup" > /dev/null
fi
