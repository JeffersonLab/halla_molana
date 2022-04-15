#!/bin/bash

STARTGRP=$1;

##COPY LARGER ENV VAR NAMES TO COMPACT
MDBHOST=${MOLANA_DB_HOST}
MDBUSER=${MOLANA_DB_USER}
MDBPASS=${MOLANA_DB_PASS}
MDBNAME=${MOLANA_DB_NAME}
MROOTDR=${MOLLER_ROOTFILE_DIR}
ANALDIR=${MOLANA_DATADECODER_DIR}
RSLTDIR=${MOLANA_ONLINE_PUSH_DIR}

echo "=======> Starting updateGroupTypes.sh script for ${STARTGRP}" ;

if [[ -z $STARTGRP ]]; then
    mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT FLOOR(rundet_pcrex_group) FROM moller_run_details ORDER BY FLOOR(rundet_pcrex_group) ASC;" > GROUP_TYPE_UPDATE_LIST.txt
else
    echo "$STARTGRP" > GROUP_TYPE_UPDATE_LIST.txt
fi

while IFS=: read -r GROUPNUM; do

    GRPTYPE=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT rundet_type FROM moller_run_details WHERE FLOOR(rundet_pcrex_group) = ${GROUPNUM};");

    if [[ $(wc -l <<< "$GRPTYPE") -ge 2 ]]; then
        echo "More than two group type names specified for ${GROUPNUM}";
        echo "(Group: ${GROUPNUM}) more than two types found in moller_run_details... ${GRPTYPE}" >> GROUP_TYPE_ERRORS.txt;
        continue;
    elif [[ -z $GRPTYPE ]]; then
        echo "No group type returned for ${GROUPNUM}.";
        echo "(Group: ${GROUPNUM}) No group type returned from moller_run_details..." >> GROUPERRORS.txt;
        continue;
    elif [[ "$GRPTYPE" == "NULL" ]]; then
        echo "'NULL' group type returned from moller_run_details...";
        echo "(Group: ${GROUPNUM}) 'NULL' group type returned from moller_run_details..." >> GROUPERRORS.txt;
        continue;
    else
        echo "Group ${GROUPNUM}:${GRPTYPE}";
        GRPTYPE=$( echo "${GRPTYPE}" | paste -sd , );
        
        INGRPTB=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT id_group FROM pcrex_groups WHERE id_group = ${GROUPNUM};");

        if [[ -z $INGRPTB || "$INGRPTB" == "NULL" ]]; then 
            UDSTRING="INSERT INTO pcrex_groups(id_group,group_type) VALUES (${GROUPNUM},\"${GRPTYPE}\");"
        else
            UDSTRING="UPDATE pcrex_groups SET group_type=\"${GRPTYPE}\" WHERE id_group = ${GROUPNUM};"
        fi

        echo "${UDSTRING}";
        mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "${UDSTRING}"
    fi



done < GROUP_TYPE_UPDATE_LIST.txt

echo "Group type updating completed! :)";

rm GROUP_TYPE_UPDATE_LIST.txt;
