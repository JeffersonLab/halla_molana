#!/bin/bash

CFGFILE="molana_analysis_configuration.dat"

##COPY LARGER ENV VAR NAMES TO COMPACT
MDBHOST=${MOLANA_DB_HOST}
MDBUSER=${MOLANA_DB_USER}
MDBPASS=${MOLANA_DB_PASS}
MDBNAME=${MOLANA_DB_NAME}
MROOTDR=${MOLLER_ROOTFILE_DIR}
ANALDIR=${MOLANA_DATADECODER_DIR}
RSLTDIR=${MOLANA_ONLINE_PUSH_DIR}
RWFLDIR=${MOLLER_DATA_DIR}

BATCH=           #Are we running in batch mode?
START=           #Start analysis at [run]
ENDAT=           #End analysis at [run]
FORCE=false      #Force configuration settings over used database settings
ISBLEED=         #Is it a bleedthrough run?
MAKENEW=false    #Make new molana files?
ANALPOW=0.77777  #Default anpow if not in database and not forced to config
TARGDEF=0.08005  #Default tarpol if not in database and not forced to config ... there should probably be a line for this in moller_run_details to cross-check.
CHRGPED=0        #Default qped if notin database and not forced to config ... there should probably be a line for this in the moller_run_details to cross-check.
DEADTAU=0.00001572  #Deadtime tau: fraction lost per khz.
#DEADTAU=0.0000  #Deadtime tau: TURN DEADTIME OFF WITH TAU=0
FORCEAP=false    #Force analyzing power
FORCEQP=false    #Force charge pedestal
FORCETP=false    #Force target polarization
FORCEDT=false    #Force dead time correction value
LEDMODE=false    #Sets analyzer to look for moller_led_*.root data file

function printhelp(){

echo -e "     -r | --run      )  Sets start and end values for a single run analysis.\n"

echo -e "     -b | --bleed    )  Explicity forces bleedthrough analysis on runs where beam is "
echo -e "                        assured as off.\n"

echo -e "     -f | --forcecfg )  Forces analysis to use ALL configuration file values rather than "
echo -e "                        values on database record. This should be used if we want to "
echo -e "                        update analysis with new values. These values WILL REPLACE "
echo -e "                        values used in the database.\n"

echo -e "     --forceanpow    )  Forces only the analyzing power specified in the molana "
echo -e "                        configuration file to be used. Other values will be taken "
echo -e "                        from the database history. If the database contains a NULL or "
echo -e "                        empty value the script will default to the configuration file.\n"

echo -e "     --forceqped     )  Forces only the charge pedestal specified in the molana "
echo -e "                        configuration file to be used. Other values will be taken "
echo -e "                        from the database history. If the database contains a NULL or "
echo -e "                        empty value the script will default to the configuration file.\n"

echo -e "     --forcetargpol  )  Forces only the target polarization specified in the molana "
echo -e "                        configuration file to be used. Other values will be taken "
echo -e "                        from the database history. If the database contains a NULL or "
echo -e "                        empty value the script will default to the configuration file.\n"

echo -e "     -n | --newfile  )  Forces creation of new molana data/increments files. Whould be"
echo -e "                        used if the Molana reader or the molana increments file structure"
echo -e "                        needs to be updated.\n"

echo -e "     --createconfig  )  Quickly creates a configuration file [molana.cfg] based on the "
echo -e "                        most recent successfully analyzed run if the file does not exist.\n"

echo -e "     --checkconfig   )  Will print your configuration file on the screen for quick analysis. "
echo -e "                        If this pops up blank then run --createconfig for new config file.\n"

echo -e "     -a | --anpow    )  Run as --anpow='0.xxxx' to replace the value after the equals sign"
echo -e "                        in the configuration file. You could also do this by hand via"
echo -e "                        something like nano or gedit if you desired.\n"

echo -e "     -q | --qped     )  Run as --qped='0.xxxx' to replace the value after the equals sign"
echo -e "                        in the configuration file. You could also do this by hand via"
echo -e "                        something like nano or gedit if you desired.\n"

echo -e "     -p | --targpol  )  Run as --targpol='0.xxxx' to replace the value after the equals sign"
echo -e "                        in the configuration file. You could also do this by hand via"
echo -e "                        something like nano or gedit if you desired.\n"

#NOT YET FULLY IMPLEMENTED
echo -e "     -c | --comment  )  TODO: Will insert small comment into the database for the runs being"
echo -e "                        analyzed. This will most likely be a VARCHAR(48) and part of cfg file."
echo -e "                        Should be run as --comment='short comment with no commas'."

echo -e "     --batchstart    )  Sets BATCH=true and assigns a batch start number. Start number"
echo -e "                        must be smaller than end number. Failure to enter both --batchstart "
echo -e "                        and --batchend will result in an exit.\n"

echo -e "     --batchend      )  Sets BATCH=true and assigns a batch start number. Start number"
echo -e "                        must be smaller than end number. Failure to enter both --batchstart "
echo -e "                        and --batchend will result in an exit.\n"

echo -e "     --ledmode       )  Use this flag if DAQ was run in LED mode. Creates increments file and"
echo -e "                        then terminates the rest of the analysis. Perhaps plot ADCs???\n"

echo -e "     --pulmode       )  Use this flaf if DAQ was run in LED pulser mode. Creates increments"
echo -e "                        and then terminates.\n"

echo -e "     -h | --help     )  Prints the help. Duh."

exit;

}

function setforce(){
    FORCE=true;
}
function setforceap(){
    FORCEAP=true;
}
function setforceqp(){
    FORCEQP=true;
}
function setforcetp(){
    FORCETP=true;
}

function checkconfig(){
    if [[ -f "${CFGFILE}" ]]; then
        echo " ";
        cat ${CFGFILE}
        echo -e "\n${CFGFILE} file exists.";
    else
        echo -e "\nWARNING! ${CFGFILE} does not exist.";
        echo -e "Run with option --createconfig to create new molana_analysis.cfg file.";
        echo -e "After which you can run a command to change a value or edit the file by hand.\n";
    fi
    exit;
}

function createconfig(){
    rm -f ${CFGFILE};
    local LASTRUNN=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT id_run FROM moller_run WHERE run_anpow IS NOT NULL AND run_qpedused IS NOT NULL AND run_ptarg > 0. AND run_ptarg IS NOT NULL ORDER BY id_run DESC LIMIT 1;")
    local LASTANPW=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_anpow FROM moller_run WHERE id_run = ${LASTRUNN};")
    local LASTQPED=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_qpedused FROM moller_run WHERE id_run = ${LASTRUNN};")
    local LASTPTAR=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_ptarg FROM moller_run WHERE id_run = ${LASTRUNN};")
    CFLINE1="CFGAPOW=${LASTANPW}";
    CFLINE2="CFGQPED=${LASTQPED}";
    CFLINE3="CFGPTAR=${LASTPTAR}";
    echo -e "${CFLINE1}\n${CFLINE2}\n${CFLINE3}" >> ${CFGFILE};
    exit;
}

function changeconfig(){
    case "$1" in
    'CFGAPOW')
    echo "Changing ${1} to ${2}"
    ;;
    'CFGQPED')
    echo "Changing ${1} to ${2}"
    ;;
    'CFGPTAR')
    echo "Changing ${1} to ${2}"
    ;;
    esac
}

function validatebatch(){
    if [[ -z "${START}" || -z "${ENDAT}" ]]; then
        echo -e "Error. Bad batch setup. Starting run and/or ending run is NULL. Exiting... \n"
        exit;
    fi
    if [[ ${START} > ${ENDAT} ]]; then
        echo -e "Error. Starting run is GREATER THAN ending run. Learn to count. :) Exiting... \n"
        exit;
    fi
    echo "Starting run ${START} and ending run ${ENDAT}."
}


while true; do
  case "$1" in
    -r | --run      )  START=$2; ENDAT=$2; shift 2 ;;
    -b | --bleed    )  ISBLEED=true; shift ;;
    -f | --forcecfg )  setforce; shift ;;
    -n | --newfile  )  MAKENEW=true; shift ;;
    --newfiles      )  MAKENEW=true; shift ;;
    -a | --anpow    )  changeconfig "CFGAPOW" $2; shift 2 ;;
    -q | --qped     )  changeconfig "CFGQPED" $2; shift 2 ;;
    -p | --targpol  )  changeconfig "CFGPTAR" $2; shift 2 ;;
    -c | --comment  )  changeconfig "comment" $2; shift 2 ;;
    --checkconfig   )  checkconfig; shift ;;
    --createconfig  )  createconfig; shift ;;
    --batchstart    )  BATCH=true; START=$2; shift 2 ;;
    --batchend      )  BATCH=true; ENDAT=$2; shift 2 ;;
    --forceanpow    )  setforceap; shift ;;
    --forceqped     )  setforceqp; shift ;;
    --forcetargpol  )  setforcetp; shift ;;
    --ledmode       )  LEDMODE=true; shift ;;
    --help          )  printhelp; shift;;
    --              )  shift; break ;;
    *               )
                    if [[ -z "${1}" ]]; then
                        echo "";
                    else
                        echo "$1 is not an option. You need --help";
                    fi
                    break;; 
  esac
done


#MAKE SURE THAT BATCH VALUES ARE ACCEPTABLE
if [[ "${BATCH}" == "true" ]]; then
  validatebatch;
fi

#MAKE SURE THESE DIRECTORIES EXIST
[ -d "${RSLTDIR}" ]       && echo "run_molana_analysis() ==> Specified analysis repository exists." || mkdir "${RSLTDIR}"
[ -d "${RSLTDIR}/files" ] && echo "run_molana_analysis() ==> Specified analysis files directory exists." || mkdir "${RSLTDIR}/files"
[ -d "${MROOTDR}/prompt_stats" ] && echo "run_molana_analysis() ==> Specified directory for Prompt Results exists." || mkdir "${MROOTDR}/prompt_stats"

#REMOVE ANY OUTPUT FILES WHICH MAY BE LINGERING
rm -f *.txt
rm -f *.png
rm -f *.pdf

echo "run_molana_analysis() ==> Starting analysis for ${START} to ${ENDAT}"

for (( ANALRUN=${START}; ANALRUN<=${ENDAT}; ANALRUN++ )); do

    #################################################################
    #################################################################
    ##NO LONGER REANALYZE PREX-II RUNS
    #if [ "$ANALRUN" -lt 18814 ]
    #then
    #  echo "This is a PREX-II Run... No run analysis will be completed. Continuing on...";
    #  continue;  
    #fi
    #################################################################
    #################################################################

    
    FORCENEW=false;

    #TODO: WE NEED TO MODIFY BELOW FOR LED RUNS, THE LS WITH WILDCARD HAS ISSUES. 

    ##WHERE ARE THE FILES THAT WE NEED LOCATED?
    SETFILE="${MROOTDR}/mollerrun_${ANALRUN}.set"
    DATFILE="${MROOTDR}/moller_data_${ANALRUN}.root"
    if [[ "${LEDMODE}" == true ]]; then
      DATFILE="${MROOTDR}/moller_data_led_${ANALRUN}.root"
    fi;
    if [[ "${PULMODE}" == true ]]; then
      DATFILE="${MROOTDR}/moller_data_puls_${ANALRUN}.root"
    fi;
    #MATCH FOR DATA FILE WILL BE UNIQUE 
    #DATFILE=$( ls ${MROOTDR}/moller*${ANALRUN}.root )
    echo "Found data file for ${ANALRUN}: ${DATFILE}"
    INCFILE="${MROOTDR}/molana_increments_${ANALRUN}.root"

    ##LET'S GET A NAME FOR THE RAW DATA FILE TO PASS TO DON'S DECODER
    RAWDATA=$(ls ${RWFLDIR}/moller_data*${ANALRUN}.dat | xargs -n 1 basename);
    echo "run_molana_analysis() ==> Found raw data file: ${RAWDATA}";

    ##HAVE WE ALREADY COPIED THE SETTINGS FILE?
    if [[ -f "${SETFILE}" ]]; then
        echo "run_molana_analysis() ==> Settings file already copied to MOLANA ROOT repository. :)"
    else
        echo "run_molana_analysis() ==> Copying moller settings file...";
        ./run_copy_moller_settings.sh ${ANALRUN} ${ANALRUN}
        echo "run_molana_analysis() ==> Populating moller settings into hamolpoldb...";
        ./populate_settings_in_molpol_db.sh ${ANALRUN}
    fi

    ##HAVE WE ALREADY CONVERTED THE RAW DATA TO THE MOLANA DATA ROOT FILE?
    if [[ -f "${DATFILE}" && "${MAKENEW}" == false ]]; then
        echo "run_molana_analysis() ==> Needed MOLANA data file exists..."
    else
        echo "run_molana_analysis() ==> Re-Populating moller settings into hamolpoldb..."
        ./populate_settings_in_molpol_db.sh ${ANALRUN}
        echo "run_molana_analysis() ==> Making MOLANA data file..."
        #${ANALDIR}/molana ${ANALRUN}
        ${ANALDIR}/molana ${RAWDATA}
    fi

    ##TODO: Fetch this from the settings database. Replaced seds with wildcarded literals
    ##IF WE HAVE THE SETTINGS AND DATA FILE LET'S START
    if [[ -f $SETFILE && -f $DATFILE ]];then
        ##WHAT IS THE PATTERN
        PATTERN=$(sed -n -e "s#\(.*HELPATTERNd.* : \)##p" $SETFILE)
        if [ $PATTERN == "Octet" ]; then
          PATTERN=8;
        fi
        if [ $PATTERN == "Quartet" ]; then
          PATTERN=4;
        fi
        ##WHAT IS THE FREQUENCY? DELAY?  DATE?
        FREQNCY=$(sed -n -e "s#\(.*HELFREQ.* : \)##p" $SETFILE)
        HELDLAY=$(sed -n -e "s#\(.*HELDELAYd.* : \)##p" $SETFILE)
        FREQNCY=${FREQNCY//[!0-9.]/}
        HELDLAY=${HELDLAY//[!0-9]/}
        RUNDATE=$(sed -n -e "s#\(Date       : \)##p" $SETFILE)
        read dayname month datnum clock zone year <<< ${RUNDATE}
        RUNDATE=$(date --date="$(printf "${RUNDATE}")" +%Y-%m-%d)
        RUNTIME=$(date --date="$(printf "${RUNDATE}")" +%H-%M-%S)


        ##HAVE WE ALREADY CREATED THE MOLANA INCREMEMENTS FILE? OR DO WE WANT TO DO IT FRESH?
        if [[ -f ${INCFILE} && "${MAKENEW}" == false ]]; then
            echo "run_molana_analysis() ==> MOLANA Increments ROOT file already exists! :)"
        else
            echo "run_molana_analysis() ==> Making MOLANA increments ROOT file..."
            root -b -l -q "molana_increments.C+(\""${DATFILE}"\","${HELDLAY}")"
        fi

        ##IF THIS IS AN LED OR PULS RUN CAN WE JUST STOP HERE FOR NOW?
        if [[ "${LEDMODE}" == true || "${PULMODE}" == true ]]; then
            exit 1;
        fi

        ##IS THE RUN NEW TO THE DATABASE? IN WHICH CASE WE MUST FORCE THE CONFIGURATION FILE
        ISOLDRUN=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT id_run FROM moller_run WHERE id_run = ${ANALRUN};")
        if [[ -z "$ISOLDRUN" ]]; then FORCENEW=true; fi

        ##IF NOT FORCING VALUES GET THEM FROM DB
        if [[ -z "${FORCE}" || "${FORCE}"="false" ]]; then
            ANPOWER=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_anpow FROM moller_run WHERE id_run=${ANALRUN};")
            echo "run_molana_analysis() ==> Returned ANPOWER from hamolpol moller_run table is: ${ANPOWER}";
            if [[ -z "$ANPOWER" || "$ANPOWER" == "NULL" ]]; then
               ANPOWER=${ANALPOW} #OLD RUN RETURNS NO ANALYSING POWER ASSIGNED... USE DEFAULT TO FIND EASILY IN DATABASE AND CORRECT
            fi
            CHRGPED=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_qpedused FROM moller_run WHERE id_run = ${ANALRUN};")
            echo "run_molana_analysis() ==> Returned CHRGPED from hamolpol moller_run table is: ${CHRGPED}"
            if [[ -z "$CHRGPED" || "$CHRGPED" == "NULL" ]]; then
               CHRGPED=0
            fi
            TARGPOL=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT run_ptarg FROM moller_run WHERE id_run = ${ANALRUN};")
            echo "run_molana_analysis() ==> Returned TARGPOL from hamolpol moller_run table is: ${TARGPOL}"
            if [[ -z "$TARGPOL" || "$TARGPOL" == "NULL" ]]; then
               TARGPOL=${TARGDEF}
            fi
        fi

        . ${CFGFILE};

        #############################################################################################################
        #############################################################################################################
        #############################################################################################################
        #############################################################################################################
        ANPOWER=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT rundet_anpow FROM moller_run_details WHERE id_rundet=${ANALRUN};")
        echo "run_molana_analysis() ==> Fetched AZZ of ${ANPOWER} from moller_run_details table."
        if [[ -z "$ANPOWER" || "$ANPOWER" == "NULL" ]]; then ANPOWER=${ANALPOW}; fi
        CHRGPED=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT rundet_qpedset FROM moller_run_details WHERE id_rundet=${ANALRUN};")
        echo "run_molana_analysis() ==> Fetched QPED of ${CHRGPED} from moller_run_details table."
        if [[ -z "$CHRGPED" || "$CHRGPED" == "NULL" ]]; then CHRGPED=0; fi
        #############################################################################################################
        #############################################################################################################
        #############################################################################################################
        #############################################################################################################



        ##IF FORCE FORCEANPOW FORCEQPED OR FORCEPTARG
	if [[ "${FORCEAP}" == true || "${FORCE}" == true ]] || [ "${FORCENEW}" == true ]; then ANPOWER=${CFGAPOW}; echo "run_molana_analysis() ==> Forced ANPOWER is: ${ANPOWER}"; fi
	if [[ "${FORCEQP}" == true || "${FORCE}" == true ]] || [ "${FORCENEW}" == true ]; then CHRGPED=${CFGQPED}; echo "run_molana_analysis() ==> Forced CHRGPED is: ${CHRGPED}"; fi
	if [[ "${FORCETP}" == true || "${FORCE}" == true ]] || [ "${FORCENEW}" == true ]; then TARGPOL=${CFGPTAR}; echo "run_molana_analysis() ==> Forced TARGPOL is: ${TARGPOL}"; fi

        ##ECHO THE VALUES OBTAINED
        echo "run_molana_analysis() ==> **** Ready to analyze $ANALRUN! :) ****"
        echo "run_molana_analysis() ==> Data file: ${DATFILE}"
        echo "run_molana_analysis() ==> H.Pattern: ${PATTERN}"
        echo "run_molana_analysis() ==> Frequency: ${FREQNCY}"
        echo "run_molana_analysis() ==> Delay Num: ${HELDLAY}"
        echo "run_molana_analysis() ==> Date/Time: ${RUNDATE}"
        echo "run_molana_analysis() ==> AnalPower: ${ANPOWER}"
        echo "run_molana_analysis() ==> ChargePed: ${CHRGPED}"
        echo "run_molana_analysis() ==> TargetPol: ${TARGPOL}"


        ##TODO: FIXME: SOMETHING WRONG HERE
        ##IS TYPE OF RUN IN MOLLER_RUN_DETAILS? IF NOT LABEL IT "PENDING". TODO: WAS BLEEDTHROUGH FLAG (--bleed) PASSED?
	RUNTYPE=$(mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "SELECT rundet_type FROM moller_run_details WHERE id_rundet=${ANALRUN};")
        echo "Run type received: ${RUNTYPE}";
        ##if [[ -z "$RUNTYPE" || "$RUNTYPE" == "NULL" ]]; then


        if [[ "$RUNTYPE" == "beam_pol" ]]; then
            ##IF IT WASN'T FORCED AS A BLEED_THROUGH LABEL IT PENDING
            if [[ "${ISBLEED}" == true ]]; then 
                RUNTYPE="bleed_through"; 
            else
                RUNTYPE="pending"
            fi
            #PUSH THE RUN TYPE TO THE RUN_DETAILS TABLE
            mysql -h ${MDBHOST} --user="${MDBUSER}" --password="${MDBPASS}" --database="${MDBNAME}" --skip-column-names -e "INSERT IGNORE INTO moller_run_details (id_rundet,rundet_day,rundet_type) VALUES (${ANALRUN},'${RUNDATE}','${RUNTYPE}');"
        fi

        echo "run_molana_analysis() ==> Runtype is ${RUNTYPE}"

        ##RUN ANALYSIS
        if [[ "$RUNTYPE" == "bleed_through" || "${ISBLEED}" == true ]]; then
          echo "run_molana_analysis() ==> Running molana_bleedthrough..."
          root -b -l -q "molana_bleedthrough.C+(\""${INCFILE}"\",${FREQNCY},0)"
        else
          echo "run_molana_analysis() ==> Running molana analysis and bleedthrough..."
          root -b -l -q "molana_prompt_analysis.C+(\""${INCFILE}"\","${PATTERN}","${FREQNCY}","${ANPOWER}","${CHRGPED}","${DEADTAU}")"
          root -b -l -q "molana_bleedthrough.C+(\""${INCFILE}"\",${FREQNCY},1)"
        fi

        #TODO: BURST CRASHING -- FIND OUT WHY
        ## Copy magnet set points to the table
        #./run_copy_moller_magnets.sh   ${ANALRUN}
        ## Run the burst_analysis -- fills multiple asymmetries at burst level (prompt only handles moller asym)
        #./run_molana_burst_analysis.sh ${ANALRUN}
     
        ########################## REMOVE THIS IF CONDITION.   THE REST STAYS
        #if [[ "$RUNTYPE" == "beam_pol" ]]; then
        ##DOES THE DIRECTORY FOR THE RUN EXIST FOR THE OUTPUT IMAGES?
        if [ ! -d "${RSLTDIR}/files/run_${ANALRUN}" ]; then mkdir ${RSLTDIR}/files/run_${ANALRUN}; fi
        rm -f ${RSLTDIR}/files/run_${ANALRUN}/*.png
        rm -f ${RSLTDIR}/files/run_${ANALRUN}/*.pdf
        mv -f  errors_${ANALRUN}.txt       ${RSLTDIR}/files/run_${ANALRUN}/
        mv  *.png                          ${RSLTDIR}/files/run_${ANALRUN}/
        mv  molana_*_stats_${ANALRUN}      ${MROOTDR}/prompt_stats/

        ##DO WE WANT TO LEAVE A FILE RECORD OF THE MOLLER CONFIGURATIONS. SIZE IS SMALL. COULD BE USED IN CASE OF DB FAILURE... IMPLEMENT LATER

       #fi
     

    else
        if [[ ! -f $DATFILE ]];then
            echo "(ERROR) run_molana_analysis() ==> Data file  ${DATFILE}  does not exist!"
        fi
        if [[ ! -f $SETFILE ]];then
            echo "(ERROR) run_molana_analysis() ==> Settings file  ${SETFILE}  does not exist!"
        fi
    fi

done

./run_print_prompt_stats.sh




############################
############################
#
#   (1) SPIT OUT THE DISTINCT GROUPS OF BEAM_POL FALSE_ASYM AND SPIN_DANCE TYPES INTO FILE
#   (2) READ GROUPS FROM FILE AND QUERY DATABASE FOR LIST OF RUNS (EVENTUALLY RUNS MARKED AS GOOD) IN EACH GROUP
#   (3) RUN MOLANA GROUPS AND DEPOSIT OUTPUT INTO GROUPS FOLDER
#   (4) UPDATE WEBSITE TO PULL THESE IMAGES   
#   (5) MUST PRINT IMAGES TO PNG IN GROUP ANALYSIS
#
#   mysql -h $MOLANA_DB_HOST --user="$MOLANA_DB_USER" --password="$MOLANA_DB_PASS" --database="$MOLANA_DB_NAME" --skip-column-names -e "select id_rundet from moller_run_details where rundet_pcrex_group = 1097;" | paste -sd ,
#
#   select distinct FLOOR(rundet_pcrex_group) from moller_run_details where rundet_type = "beam_pol" or rundet_type = "false_asym" or rundet_type = "spin_dance";
#
############################
############################

