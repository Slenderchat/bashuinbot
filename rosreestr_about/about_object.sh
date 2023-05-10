#!/bin/bash
if [ -n "$(/etc/dovecot/xml sel -t -v "name(/*[starts-with(name(), 'extract_about_property')])" "$file")" ]
then
	WHAT="выписка об объекте недвижимости"
	CLASS="$(/etc/dovecot/xml sel -t -v "name(/*[starts-with(name(), 'extract_about_property')])" "$file")"
	if [ "$CLASS" == "extract_about_property_room" ]
	then
		CLASS="'Помещение'"
	elif [ "$CLASS" == "extract_about_property_build" ]
	then
		CLASS="'Здание'"
	elif [ "$CLASS" == "extract_about_property_land" ]
	then
		CLASS="'Земельный участок'"
	else
		CLASS="'Неизвестный тип'"
	fi
	PURPOSE="$(/etc/dovecot/xml sel -t -v "//params/purpose/value" "$file")"
	if echo "$PURPOSE" | grep -iq "нежилое"
	then
		PURPOSE="'Нежилое'"
	elif echo "$PURPOSE" | grep -iq "жилое"
	then
		PURPOSE="'Жилое'"
	else
		PURPOSE="NULL"
	fi
	TYPE="'$(/etc/dovecot/xml sel -t -v "//params/name" "$file" | sed 's/ \+$//')'"
	NUMBER="'$(/etc/dovecot/xml sel -t -v "//common_data/cad_number" "$file" | sed 's/ \+$//')'"
	LOCATION="'$(/etc/dovecot/xml sel -t -v "//readable_address" "$file" | sed 's/ \+$//')'"
	COST="'$(/etc/dovecot/xml sel -t -v "//cost/value" "$file" | sed 's/ \+$//')'"
	[ "$TYPE" == "''" ] && TYPE="NULL"
	[ "$LOCATION" == "''" ] && LOCATION="NULL"
	[ "$COST" == "''" ] && COST="NULL"
	readarray -t OWNERS < <(/etc/dovecot/xml sel -t -m "//right_records/right_record/right_holders/right_holder/individual" -o "'" -v "surname" -o " " -v "name" -o " " -v "patronymic" -o "'" -n "$file")
	/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO objects (id, kind, location, cost, class, purpose) VALUES ($NUMBER, $TYPE, $LOCATION, $COST, $CLASS, $PURPOSE) ON CONFLICT(id) DO UPDATE SET kind = $TYPE, location = $LOCATION, cost = $COST, class = $CLASS, purpose = $PURPOSE"
	for OWNER in "${OWNERS[@]}"
	do
		/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO subjects (name) VALUES ($OWNER) ON CONFLICT DO NOTHING"
		/etc/dovecot/psql -q uinbot uinbot -c "INSERT INTO object_owners (object, owner) SELECT $NUMBER, $OWNER WHERE NOT EXISTS(SELECT 1 FROM object_owners WHERE object = $NUMBER AND owner = $OWNER)"
	done
	CAPTION="Поступила $WHAT:"
	[ "$PURPOSE" == "NULL" ] || { PURPOSE="${PURPOSE,,}"; PURPOSE="${PURPOSE//\'/}"; CAPTION="$CAPTION $PURPOSE"; }
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
	/etc/dovecot/curl -sF "chat_id=$CHATID" -F "media=[{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf)\"},{\"type\": \"document\", \"media\": \"attach://$(/etc/dovecot/basename "${file%.xml}".pdf.sig)\", \"caption\": \"$CAPTION\"}]" -F "$(/etc/dovecot/basename "${file%.xml}".pdf)=@${file%.xml}.pdf" -F "$(/etc/dovecot/basename "${file%.xml}".pdf.sig)=@${file%.xml}.pdf.sig" "https://api.telegram.org/bot$TOKEN/sendMediaGroup" > /dev/null
fi
