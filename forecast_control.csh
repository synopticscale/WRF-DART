#!/bin/csh
#sequentially run a set of forecasts in specified run directory 
#By JMC October 15th 2020
##########################
set echo

######
#future updates: delegate each experiment to a new rundirectory 
#this will lower wait times 
######
#uncomment for serial run 
#set exp = 64_mem_3km
#source /glade/work/jmccurry/WOF/scripts/WOFenv_rlt_2018
#source ${TOP_DIR}/realtime.cfg.${event}.${exp}
#cd ${RUNDIR}
#####


#####
#set starting and ending dates of forecast initiations here
#format is YYYYmmddhr for both start and end dates
foreach day_master ( 20190703201907031919 )
#####
#run options
@ ENS_SIZE_FCST = 20 #controls number of forecast ensemble members
set exp = 64_mem_3km_enkf_15MIN_CSEC_THOMPSON #cycle run directory suffix
set gcidir = enkf #caser forecast archive storage directory -- normally set this to match filter config
set gcisubdir = 25dbz_64_mem_restarts_15MIN_THOMPSON #casper forecast archive storage subdirectory -- set to experiment name
set forecast_eval_interval = 15 #how long to advance forecasts between DART evaluation
set history_interval = 60  #seconds between wrf output -- normally set above eval interval*60 to avoid extra files 
set restart_interval = 900 #seconds between restart output -- always set to eval interval*60
set from_campaign = .false. #set to .true. if you want to use cycle output stored on casper 


#####
set filter_string = `echo ${day_master} | cut -c 5-8`
set filter = `echo ${exp} | cut -d '_' -f4`${filter_string}
set event = `echo ${day_master} | cut -c 1-8`
source /glade/work/jmccurry/WOF/scripts/WOFenv_rlt_forecast
source ${TOP_DIR}/realtime.cfg.${event}.${exp}
mkdir ${TOP_DIR}/${event}.${exp}
#####

#####
#NOTES
#currently only works for forecasts initiated at 00 mins
#need to improve time cycling
#####

#####
#record runs here
#20190528 18-23 enkf pf_hyb
#20190703 16-23 enkf pf_hyb
#20200812 16-23 enkf pf_hyb
#20190717 13-23 enkf pf_hyb
#20190528 00-03 pf_hyb enkf
#20190703 00-01 pf_hyb
#20200812 00-01 pf_hyb
#20190717 00-01 pf_hyb
#
#####

set obs = obs_seq.combined_full_cropped
set start_hr = `echo ${day_master} | cut -c 17-18`
set end_hr = `echo ${day_master} | cut -c 19-20`
@ ENS_SIZE_FCST = 20 
set day = `echo ${day_master} | cut -c 9-16`
echo ${day}
foreach hr (`seq -f "%02g" ${start_hr} ${end_hr}`)
foreach min ( 30 )
#check for output in campaign dir
gci ls univ/umcp0011/WOF_FORECAST_ARCHIVE/${gcidir}/${gcisubdir} >! campaigncheck.txt
set missing = `grep -c "WRFOUTS_FCST${day}${hr}${min}" campaigncheck.txt`
if ( ${missing} == 1 ) then
   continue 
endif
set fcst_exp = ${exp}_fcst${hr}${min} 


cd ${SCRIPTDIR}


${SCRIPTDIR}/Setup_NEWSe_forecasts.csh ${exp} ${fcst_exp} ${event} ${ENS_SIZE_FCST}
source ${TOP_DIR}/realtime.cfg.${event}.${fcst_exp}



echo "running forecast for ${day} ${hr}${min}z"
sed -i "/nextCcycle/c\setenv nextCcycle ${day}${hr}${min}" ${TOP_DIR}/realtime.cfg.${event}.${fcst_exp}
sed -i "/setenv assim_per_conv/c\setenv assim_per_conv ${forecast_eval_interval}" ${TOP_DIR}/realtime.cfg.${event}.${fcst_exp}

cd ${RUNDIR}/flags
rm -rf start_forecast *done *blown  
cd ${RUNDIR}
rm -rf filter_done
mkdir ${TOP_DIR}/${event}.${exp}/WRFOUTS_FCST${day}${hr}${min}
mkdir ${TOP_DIR}/${event}.${exp}/WRFOUTS_FCST${day}${hr}${min}/${day}${hr}${min}
if ( ${from_campaign} == .true. ) then
    ${SCRIPTDIR}/transfer_saved_mems_campaign.csh ${exp} ${fcst_exp} ${day} ${hr} ${min} ${ENS_SIZE_FCST} ${event} ${TOP_DIR} ${restart_interval} ${history_interval} 
else
    ${SCRIPTDIR}/transfer_saved_mems_scratch.csh ${exp} ${fcst_exp} ${day} ${hr} ${min} ${ENS_SIZE_FCST} ${event} ${TOP_DIR} ${restart_interval} ${history_interval} 

endif
#need to add ability to modify stop date to avoid needing to set it to run end 
#setting to run end could seriously waste resources in event of screw up 
sed -i "/NEWSe_main.err/c\\#PBS -e \/glade\/work\/jmccurry\/WOF\/scripts\/error_output\/NEWSe_main.err_${fcst_exp}" ${SCRIPTDIR}/NEWSe_main_forecast.csh

sed -i "/set exp/c\set exp = ${fcst_exp}" ${SCRIPTDIR}/NEWSe_main_forecast.csh
sed -i "/set FORECAST_ENS/c\set FORECAST_ENS = ${ENS_SIZE_FCST}" ${SCRIPTDIR}/NEWSe_main_forecast.csh

sed -i "/set WRFOUT/c\set WRFOUT  = ${TOP_DIR}/${event}.${exp}/WRFOUTS_FCST${day}${hr}${min}" ${SCRIPTDIR}/NEWSe_main_forecast.csh

sed -i "/set GCIOUT/c\set GCIOUT = /glade/campaign/univ/umcp0011/WOF_FORECAST_ARCHIVE/WRFOUTS_FCST${day}${hr}${min}" ${SCRIPTDIR}/NEWSe_main_forecast.csh
sed -i "/set GCISUBDIR/c\set GCISUBDIR = ${gcisubdir}" ${SCRIPTDIR}/NEWSe_main_forecast.csh
sed -i "/set GCIDIR/c\set GCIDIR  = ${gcidir}" ${SCRIPTDIR}/NEWSe_main_forecast.csh

sed -i "/set sourcefile/c\set sourcefile = forecastcpanel/WOFenv_rlt_${fcst_exp}_${filter}_init${hr}${min}" ${SCRIPTDIR}/NEWSe_main_forecast.csh
sed -i "/set event/c\set event = ${event}" ${SCRIPTDIR}/NEWSe_main_forecast.csh


cd ${SCRIPTDIR}
cp ${SCRIPTDIR}/NEWSe_main_forecast.csh ${SCRIPTDIR}/NEWSe_main_forecast_${hr}${min}.csh
qsub ${SCRIPTDIR}/NEWSe_main_forecast.csh


########
#uncomment for serial run 
#while ( ! -e ${SEMA4}/forecast_done ) 
#  sleep 10 
#  echo "waiting for forecast completion"
#end 
#rm -rf ${SEMA4}/forecast_done
########


end 
end 
end
