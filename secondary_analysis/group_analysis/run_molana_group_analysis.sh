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

rm -f GROUPERRORS.txt
touch GROUPERRORS.txt
rm -r GROUPLIST.txt
rm -f *.png

[ -d "${RSLTDIR}/group" ] && echo "run_molana_analysis() ==> Specified analysis files directory exists." || mkdir "${RSLTDIR}/group"

## WE CAN SPECIFY A SINGLE GROUP OR LET IT AUTOMATICALLY POPULATE ALL GROUPS
if [[ -z "${1}" ]]; then
    mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT FLOOR(rundet_pcrex_group) FROM moller_run_details WHERE rundet_type LIKE 'beam_pol%' OR rundet_type = 'false_asym' OR rundet_type = 'spin_dance' ORDER BY FLOOR(rundet_pcrex_group) ASC;" > GROUPLIST.txt
else
    echo "${1}" >> GROUPLIST.txt
fi

## START ON THE LIST OF GROUPS
while IFS=: read -r GROUPNUM; do
#    if(( GROUPNUM < 1000 )); then #EXCLUDE PREX2 GROUPS
#    if(( GROUPNUM < 3000 )); then #EXCLUDE CREX GROUPS
    if(( GROUPNUM < 3100 )); then #PROCESS SBS GROUPS ONLY
            continue; 
    fi

    echo "Returned group number: ${GROUPNUM}";

    rm -f ${RSLTDIR}/group/group_${GROUPNUM}/*.png;


    GRPTYPE=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT group_type FROM pcrex_groups WHERE id_group = ${GROUPNUM};")

    ##IF GROUP TYPE DOESN'T EXIST IN DATABASE CHECK AGAINST RUN DATABASE
    if [[ -z $GRPTYPE || "$GRPTYPE" ==  "NULL" ]]; then
        echo "Group type doesn't exist in 'pcrex_groups' data table. Running updateGroupTypes.sh script for ${GROUPNUM}...";
        ./updateGroupTypes.sh ${GROUPNUM};
        GRPTYPE=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT group_type FROM pcrex_groups WHERE id_group = ${GROUPNUM};")
    fi

    echo "Group type: " ${GRPTYPE};


    ### LET'S CHECK TO MAKE SURE THAT ALL THE REGISTERED ANPOW FOR THE PREX & CREX RUNS MATCH WITHIN GROUPS
    NUMAPOW=$( mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT run_anpow FROM moller_run, moller_run_details where id_rundet = id_run and rundet_pcrex_group = ${GROUPNUM};");

    echo "Number of analyzing powers during grouping: " $(wc -l <<< "$NUMAPOW");

    #ANPOW ERRORS
    if [[ $(wc -l <<< "$NUMAPOW") -ge 2 ]]; then
        echo "More than two analyzing powers... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) more than two analyzing powers found in moller_run..." >> GROUPERRORS.txt;
        echo "Run command: SELECT DISTINCT run_anpow FROM moller_run, moller_run_details where id_rundet = id_run and rundet_pcrex_group = ${GROUPNUM};" >> GROUPERRORS.txt
        continue;
    elif [[ -z $NUMAPOW ]]; then
        echo "No analyzing power returned... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) no anpow returned from moller_run..." >> GROUPERRORS.txt;
        continue;
    elif [[ "$NUMAPOW" == "NULL" ]]; then
        echo "NULL analyzing power returned... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) NULL anpow returned from moller_run..." >> GROUPERRORS.txt;
        continue;
    else
        echo "Setting analyzing power...";
        echo "ANPOWER: ${NUMAPOW}";
        ANPOWER=$( echo "${NUMAPOW}" | paste -sd , );
        mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "UPDATE pcrex_groups SET group_anpow = ${ANPOWER} WHERE id_group = ${GROUPNUM};"
    fi


    TGTUSED=$( mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT set_target FROM moller_settings, moller_run_details where id_set_run = id_rundet and rundet_pcrex_group = ${GROUPNUM};");

    echo "Number of targets during grouping: " $(wc -l <<< "$TGTUSED");

    #NUMBER OF TARGET ERRORS
    if [[ $(wc -l <<< "$TGTUSED") -ge 2 ]]; then
        echo "(Group: ${GROUPNUM}) more than two targets found in moller_settings...";
        echo "(Group: ${GROUPNUM}) more than two analyzing powers found in moller_settings..." >> GROUPERRORS.txt;
    elif [[ -z $TGTUSED ]]; then
        echo "(Group: ${GROUPNUM}) No targets returned from moller_settings...";
        echo "(Group: ${GROUPNUM}) No targets returned from moller_settings moller_settings..." >> GROUPERRORS.txt;        
    elif [[ "$TGTUSED" == "NULL" ]]; then
        echo "(Group: ${GROUPNUM}) NULL targets returned from moller_settings...";
        echo "(Group: ${GROUPNUM}) NULL targets returned from moller_settings..." >> GROUPERRORS.txt;        
    else
        echo "Writing target to pcrex_group table...";
        echo "TGTUSED: ${TGTUSED}";
        TGTUSED=$( echo "${TGTUSED}" | paste -sd , );
        echo "UPDATE pcrex_groups SET group_target = ${TGTUSED} WHERE id_group = ${GROUPNUM};";
        mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "UPDATE pcrex_groups SET group_target = ${TGTUSED} WHERE id_group = ${GROUPNUM};"        
    fi


    TARGPOL=$( mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT DISTINCT run_ptarg FROM moller_run, moller_run_details where id_rundet = id_run and rundet_pcrex_group = ${GROUPNUM};")

    echo "Number of target polarizations: " $(wc -l <<< "$TARGPOL");

    if [[ $(wc -l <<< "$TARGPOL") -ge 2 ]]; then
        echo "More than two analyzing powers... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) more than two analyzing powers found in moller_run..." >> GROUPERRORS.txt;
        continue;
    elif [[ -z $TARGPOL ]]; then
        echo "No analyzing power returned... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) no anpow returned from moller_run..." >> GROUPERRORS.txt;
        continue;
    elif [[ "$TARGPOL" == "NULL" ]]; then
        echo "NULL analyzing power returned... skipping group analysis.";
        echo "(Group: ${GROUPNUM}) NULL anpow returned from moller_run..." >> GROUPERRORS.txt;
        continue;
    else
        echo "Setting target polarization...";
        echo "POLTARG: ${TARGPOL}";
        POLTARG=$TARGPOL;
    fi


    if [[ "$GRPTYPE" == "beam_pol" || "$GRPTYPE" == "beam_pol_sys" || "$GRPTYPE" == "spin_dance" || "$GRPTYPE" == "false_asym" || "$GRPTYPE" == "pita_scan" ]]; then

        GRPRUNS=$( mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT id_rundet FROM moller_run_details WHERE FLOOR(rundet_pcrex_group) = ${GROUPNUM} ORDER BY id_rundet ASC;" | paste -sd ,)

        echo "Runs for group: ${GRPRUNS}";
        root -b -l -q "molana_group_pol.C+(\""${GRPRUNS}"\","${GROUPNUM}","${POLTARG}","${ANPOWER}")"
        MOLANAGROUPRETURN=$?;
        echo "Analysis returned: $MOLANAGROUPRETURN";
 
        if [[ "$MOLANAGROUPRETURN" != "100" ]]; then
             echo "(Group: ${GROUPNUM}) MOLANA Group Analysis did not return code '100'" >> GROUPERRORS.txt;
             continue;
        fi

        if [ ! -d "${RSLTDIR}/group/group_${GROUPNUM}" ]; then mkdir ${RSLTDIR}/group/group_${GROUPNUM}; fi

        ./run_generate_group_asym_plots.sh ${GROUPNUM};

        mv *Group-${GROUPNUM}*.png  ${RSLTDIR}/group/group_${GROUPNUM}/
   
    fi

done < GROUPLIST.txt




###############################################################################
# AGGREATED PLOTS FOR PREX2 AND CREX
# REPRODUCE AGGREGATED PLOTS AFTER NEW ANALYSIS
#[ -d "${RSLTDIR}/aggregated" ] && echo "run_molana_analysis() ==> Specified analysis files directory exists." || mkdir "${RSLTDIR}/aggregated"
#root -l -b -q gatherGroupData.C
#rm ${RSLTDIR}/aggregated/aggregated_crex*.png
#mv aggregated_crex*.png ${RSLTDIR}/aggregated/
###############################################################################

