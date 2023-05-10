#!/bin/bash
if [ -n "$(/etc/dovecot/xml sel -t -m extract_about_contents_documents_title -f "$file")" ]
then
	WHAT="выписка о содержании правоустанавливающих документов"
	NUMBER="$(/etc/dovecot/xml sel -t -v "//common_data/cad_number" "$file")"
	LOCATION="$(/etc/dovecot/xml sel -t -v "//readable_address" "$file")"
	/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO objects (id, location) VALUES ('$NUMBER', '$LOCATION') ON CONFLICT(id) DO UPDATE SET location = '$LOCATION'"
	/etc/dovecot/curl -sF "chat_id=$CHATID" -F "media=[{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf)\"},{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf.sig)\", \"caption\": \"Поступила $WHAT, относительно объекта с кадастровым номером: $NUMBER, расположенным по адресу: $LOCATION\"}]" -F "$(/etc/dovecot/basename "${file%.xml}".pdf)=@${file%.xml}.pdf" -F "$(/etc/dovecot/basename "${file%.xml}".pdf.sig)=@${file%.xml}.pdf.sig" "https://api.telegram.org/bot$TOKEN/sendMediaGroup" > /dev/null
fi
