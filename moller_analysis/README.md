# __MOLANA Analysis (2020 version)__
Repository for **MOLANA** Analysis code. This code is to be used in conjunction with Don Jones' **MOLANA** [raw data decoder](https://github.com/jonesdc76/moller_analyser). This version of the code is intended to be used with a persistent database that maintains prompt results.

> All of the wrappers for the ROOT/C++ analysis scripts are written in Bash. I believe this is the best route from a readability standpoint; the ROOT/C++ code should be reasonably familiar to anyone using this and the Bash wrapper should be easily readible by anyone familiar with Linux OS's. The other route, perhaps with some benefit as far as constructing a GUI, could be Python. --Eric King

## How to use run\_molana\_analysis.sh
The sript *run_molana_analysis.sh* works out all the required coordination between ROOT macros, bash scripts and MOLANA decoder program.

### Getting Started
Helpful for the usage of *run\_molana\_analysis* can be accessed by running the bash script with the _--help_ option.

There exists a persistent configuration file that currently only contains the following information: 

* Analyzing Power
* Charge Pedestal
* Target Polarization

More may be added at some point.

You can check to see if the configuration file is available by running the script with the _--checkconfig_ option; if nothing prints on the screen you can create a cofiguration file template running the script with the _--createconfig_ option. There will be (or perhaps now are) options to then set these values from the command line with the *run\_molana\_analyis.sh* script. The values this file pulls will be the values used for the last successful prompt data analysis that was sent to the database.

For example: 

 *run\_molana\_analysis.sh* *--anpow 0.75309 --targpol 0.08012 --qped 9*

Will (when done) fix those values in the persistent configuration file.

### Analysis

 *run\_molana\_analysis.sh* *--run 18915*

The above command will analyze run #18915. 
* __IF__ run #18915 is unlisted in the database the script will automatically default to the configuration file values for analysis.
* __IF__ run #18915 is listed in the database the script will simply re-analyze with the old specified values.

*run\_molana\_analysis.sh* *--run 18915 --forcecfg*

The above command will force all of the new configuration settings on the analysis. You can also choose to force only one of the values (*see --help*).

*run\_molana\_analysis.sh* *--batchstart 18915 --batchend 18920*

The above command will analyze all runs in the specified span. Again, if they are new runs they will default to the configuration specified __OR__ if they are old runs they will re-analyze against the previously provided parameter.

*run\_molana\_analysis.sh* *--batchstart 18915 --batchend 18920 --forcecfg*

The above command will force the batch run to use the new specified parameters.

### Bleedthrough Runs

Bleedthough runs require some alterations to normal settings--e.g. the beam off cut should not be made. Bleedthrough runs should be handled as follows:

*run_molana_analysis.sh --run 18915 --bleed*

Bleedthough results will be written to the database of prompt analysis results.

### run_molana_analysis.sh Flag Options List

| Short Flag | Long Flag | Description |
|------------|-----------|-------------|
| -r | --run | Sets start and end values for a single run analysis. |
| -b | --bleed | Explicity forces bleedthrough analysis on runs where beam is assured as off. |
| -f | --forcecfg | Forces analysis to use ALL configuration file values rather than values on database record. This should be used if we want to update analysis with new values. These values WILL REPLACE values used in the database. |
|    | --forceanpow | Forces only the analyzing power specified in the molana configuration file to be used. Other values will be taken from the database history. If the database contains a NULL or empty value the script will default to the configuration file. |
|  | --forceqped     |  Forces only the charge pedestal specified in the molana configuration file to be used. Other values will be taken from the database history. If the database contains a NULL or empty value the script will default to the configuration file. |
|  | --forcetargpol  |  Forces only the target polarization specified in the molana configuration file to be used. Other values will be taken from the database history. If the database contains a NULL or empty value the script will default to the configuration file. |
| -n | --newfile  |  Forces creation of new molana data/increments files. Whould be used if the Molana reader or the molana increments file structure needs to be updated. |
|  | --createconfig  |  Quickly creates a configuration file [molana.cfg] based on the most recent successfully analyzed run if the file does not exist. |
|  | --checkconfig   |  Will print your configuration file on the screen for quick analysis. If this pops up blank then run --createconfig for new config file. |
| -a | --anpow    |  Run as --anpow='0.xxxx' to replace the value after the equals sign in the configuration file. You could also do this by hand via something like nano or gedit if you desired. |
| -q | --qped     |  Run as --qped='0.xxxx' to replace the value after the equals sign in the configuration file. You could also do this by hand via something like nano or gedit if you desired. |
| -p | --targpol  |  Run as --targpol='0.xxxx' to replace the value after the equals sign in the configuration file. You could also do this by hand via something like nano or gedit if you desired. |
| -c | --comment  |  TODO: Will insert small comment into the database for the runs being analyzed. This will most likely be a VARCHAR(48) and part of cfg file. Should be run as --comment='short comment with no commas'. |
|  | --batchstart    |  Sets BATCH=true and assigns a batch start number. Start number must be smaller than end number. Failure to enter both --batchstart and --batchend will result in an exit. |
|  | --batchend      |  Sets BATCH=true and assigns a batch start number. Start number must be smaller than end number. Failure to enter both --batchstart and --batchend will result in an exit. |
| -h | --help     |  Prints the help. |

## Using molana_increments.C()

*void molana_increments(string FILE, const Int_t DELAY)*

Molana increments root macro takes the converted root file of the raw data decoded by Don Jones' MOLANA raw decoder. The macro takes two arguements: Location of the file to be analyzed; and helicity delay. Molana increments calculates up the increments between helicity cycles, removes the helicity delay between the helicity patter and the data and writes a new file called *molana_increments_NNNNN.root* which can then be read by the molana analysis script.

## Using molana_analysis.C()

*molana_analysis(string FILE, Int_t HELN, Double_t FREQ, Double_t ANPOW, Double_t QPED )*

Molana analysis root macro takes 5 arguments: Location of the *molana_increments_NNNNN.root* file to be read; helicity pattern type; helicity frequency; analyzing power; and charge pedestal. This can be run on its own in standard ROOT fashion. When run as standalone the script will produce PNG files and an errors text file in the directory which it resides. The script will push prompt analysis results to the specified database.

## Using molana_bleedthrough.C()

molana_bleedthrough(string FILE, Double_t FREQ, Bool_t BEAM )

Molana bleedthrough root macro takes 3 arguments: File location; helicity frequency; and beam status. It analyzes, on a helicity cycle basis, both charge pedestal and bleedthrough rates. When beam is off [BEAM = 0] the script proceeds guaranteed that the beam was not on and spits out *charge pedestal* **and** *bleedthrough rates*. When beam is on [BEAM = 1] the script looks for times when beam is off on the conditions: *bcm < (bcm_mean - 5 sigma)* **and** *coin < (coin_mean - 3 sigma)*. This has produced reliable results of finding beam trips from which the *charge pedestal* is calculated.

# Important information: 

These scripts require the use of the following environmental variables:

* MOLLER\_ROOTFILE\_DIR   (Also required by the MOLANA raw data decoder)
* MOLLER\_DATA\_DIR       (Also required by the MOLANA raw data decoder)

* MOLANA\_DB\_HOST (Used by *run_molana_analysis.sh*, *molana_analysis.C* and *molana_bleedthrough.C* )
* MOLANA\_DB\_USER (Used by *run_molana_analysis.sh*, *molana_analysis.C* and *molana_bleedthrough.C* )
* MOLANA\_DB\_PASS (Used by *run_molana_analysis.sh*, *molana_analysis.C* and *molana_bleedthrough.C* )
* MOLANA\_DB\_NAME (Used by *run_molana_analysis.sh*, *molana_analysis.C* and *molana_bleedthrough.C* )

* MOLLER\_SETTINGS\_DIR      (Where does the DAQ throw the *mollerrun_NNNNN.set* files?)
* MOLANA\_DATADECODER\_DIR   (Where is Don Jones' MOLANA raw decoder located)
* MOLANA\_ONLINE\_PUSH\_DIR  (Where should *run_molana_analysis.sh* push PNG results to?)
