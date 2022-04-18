MOLANA Run Details
==================

This folder contains the CSV files containing basic Moller polarimetry run information which is pertinent to data management.

## General Information

1. Run details are read into the MySql table by the BASH script *populate_moller_details.sh*; the script takes a single argument which is the directory to look in for the csv files to be read.  
2. Run details are maintained line-by-line in CSV format with 8 fields shown in the table below.

| Field | Description |
|-------|-------------|
| Date (YYYY-MM-DD) | Date of the Moller Polarimetry measurements; this can be different than the actual date (if say we measured between Swing and Owl shifts). |
| Run Start | Starting Run |
| Run End | Ending Run |
| Analyzing Power | Analzying power for the optics of this run (or run set) |
| Group Type | What type of group is this "beam_pol", "beam_pol_sys" , etc. |
| Group Number | Assigned group number for these particular Moller polarimetry measurements |
| Note | Any particular information about these runs (e.g. 0.5uA;10um foil) keep it short **and without commas**. |
| Experiment | Code for the experiment; this is a field that can be used to sort the webpage or used to quickly pick runs from the database. |

3. The Bash script reads the files in natural order. As such the naming convention is important. Plese stick to the convention of naming files YYYY-MM-DD_Something.csv in order to allow for proper read in order.

## Group Numbers

The numbering convention for PREX and CREX Group IDs was 

    <1000 : Spring 2019 Commisioning period prior to PREX-II
     1000+: PREX-II 
     3000+: CREX
     
The presumption at the time being that we should have more than 100 groups of measurements per experiment. This ideally leaves the first digit as the experiment identifier which is followed by sequential group numberings.

## Good Practices :)

* It's good practice to secure every file as 'read only' after it is finished. This can be achieved by
    chmod 400 filename.csv
* Correctons to the CSV list can be made in a corrections CSV file under a later date. This is likely good practice.
* Move all previously read CSV files which are recorded into the database into the ARCHIVE folder. In the case that the database, for some reason, becomes corrupted then it can be re-populated/updated with a simple *populate_moller_details.sh ARCHIVE/*

## Examples

The below example covers a sequence of runs from 19468 through 19476 which were taken on 9/16/2020 and part of a saturation scan series. The note indicates the helmholtz holding field was set to 3.2T (59.7 Amps), the group of runs was designated the Group ID 3055 and this was done during the CREX experiment. 

    2020-09-16,19468,19476,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX

This series of runs could have also been recorded as: 

    2020-09-16,19468,19468,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19469,19469,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19470,19470,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19471,19471,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19472,19472,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19473,19473,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19474,19474,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19475,19475,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19476,19476,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX 

Suppose run #19471 was a junk run where we lost beam for immediately after beginning taking data

    2020-09-16,19468,19470,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX
    2020-09-16,19471,19471,0.754210,junk,,junk,
    2020-09-16,19472,19476,0.754210,beam_pol_sys,3055.,saturation;3.2T=59.700A,CREX

## Things that might be good to do

It might be good to write a tidbit of bash code that ignores any line that starts with say a "#" so we can add comments to files. I was trying to use the LOG file but this was just another file to fill. This would also be good for recording reasons for corrections files. 
