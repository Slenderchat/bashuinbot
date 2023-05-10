#!/bin/bash
if [ -n "$(/etc/dovecot/xml sel -t -v "name(/*[starts-with(name(), 'extract_cadastral_value')])" "$file")" ]
then
	WHAT="выписка о стоимости объекта недвижимого имущества"
	CLASS="'$(/etc/dovecot/xml sel -t -v "//common_data/type/value" "$file" | sed 's/ \+$//')'"
	if [ -z "$CLASS" ]
	then
		CLASS="'Неизвестный тип объекта'"
	else
		CLASS="'$CLASS'"
	fi
	NUMBER="'$(/etc/dovecot/xml sel -t -v "//common_data/cad_number" "$file" | sed 's/ \+$//')'"
	LOCATION="'$(/etc/dovecot/xml sel -t -v "//readable_address" "$file" | sed 's/ \+$//')'"
	COST="'$(/etc/dovecot/xml sel -t -v "//cost/value" "$file" | sed 's/ \+$//')'"
	COSTDATE="$(/etc/dovecot/xml sel -t -v "//date_available_information" "$file" | sed 's/ \+$//')"
	[ "$LOCATION" == "''" ] && LOCATION="NULL"
	[ "$COST" == "''" ] && COST="NULL"
	[ "$COSTDATE" == "''" ] && COSTDATE="NULL" || COSTDATE=$(date -d "$COSTDATE" "+%d %B %Y года")
	/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO objects (id, location, cost) VALUES ($NUMBER, $LOCATION, $COST) ON CONFLICT(id) DO UPDATE SET location = $LOCATION, cost = $COST"
	CAPTION="Поступила $WHAT:"
	CLASS="${CLASS//\'/}"
	CAPTION="$CAPTION ${CLASS,,} с кадастровым номером ${NUMBER//\'/}"
	if [ "$LOCATION" != "NULL" ]
	then
		if [ "$CLASS" == "Земельный участок" ]
		then
			CAPTION="$CAPTION, расположенный по адресу: ${LOCATION//\'/}"
		else
			CAPTION="$CAPTION, расположенное по адресу: ${LOCATION//\'/}"
		fi
	fi
	if [ "$COST" != "NULL" ]
	then
		if [ "$COSTDATE" != "NULL" ]
		then
			CAPTION="$CAPTION, стоимость на $COSTDATE: ${COST//\'/}"
		else
			CAPTION="$CAPTION, стоимость: ${COST//\'/}"
		fi
	else
			CAPTION="$CAPTION, стоимость: не определена"
	fi
	/etc/dovecot/curl -sF "chat_id=$CHATID" -F "media=[{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf)\"},{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf.sig)\", \"caption\": \"$CAPTION\"}]" -F "$(/etc/dovecot/basename "${file%.xml}".pdf)=@${file%.xml}.pdf" -F "$(/etc/dovecot/basename "${file%.xml}".pdf.sig)=@${file%.xml}.pdf.sig" "https://api.telegram.org/bot$TOKEN/sendMediaGroup" > /dev/null
fi
