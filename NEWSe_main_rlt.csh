#!/bin/csh
########################################################################
#PBS -N NEWSe_main
#PBS -o /glade/work/jmccurry/WOF/scripts/error_output/NEWSe_main_hythomp.log
#PBS -e /glade/work/jmccurry/WOF/scripts/error_output/NEWSe_main_hythomp.err
#PBS -l select=1:ncpus=1
#PBS -l walltime=12:00:00
#PBS -q premium 
#PBS -A UMCP0011
#PBS -k oed
########################################################################
#set TEMPDIR to prevent exceeding on node temp file storage limit
setenv TMPDIR /glade/scratch/$USER/temp  
mkdir -p $TMPDIR
set echo
########################################################################
#
#NEWSe_main.csh - script that is the driver for the
#                 NEWSe run on the Deepthought2 HPC 
#remember to set starting analysis date in realtime.cfg
########################################################################


#############################
#experiment run controls
#always set start_date and stop_date according to your cycle run 
#always change input_nml_file according to the filter you are using
#typically leave spin_up_mins = 0, unless starting a new run and not using restart files

set exp = 64_mem_3km_pf_hybrid_15MIN_CSEC_THOMPSON #experiment run folder suffix
set WRFOUT = WRFOUT #folder name for storing forecast output files in experiment run folder
set OBSTYPE = OBS_SEQ_CONV #obs subdirectory where observations are stored under the main obs folder ie; /glade/scratch/jmccurry/WOF/realtime/OBSGEN/ 


set start_date = 201907031000
#set start_date = 201907170700 
#set start_date = 201905281200
#set start_date = 202008121000


set stop_date = 201907031945
#set stop_date = 201907180115
#set stop_date = 201905290315
#set stop_date = 202008130215

set length_of_expname = `echo $exp | awk -f "_" '{print NF}'` 
set serial = `echo $exp | cut -d '_' -f 4-${length_of_expname}` #serial number for conducting concurrent runs 
set test_mode = 0 #special test mode switch, currently unimplemented
set spin_up_mins = 0 #set to sixty when starting runs from perturbed initial conditions
set input_nml_file = input.nml.pfhybrid_thompson#input.nml file used for run 
set fast_LBC_update = .false. #set to True for 15 minute LBC updates or False for 60 min updates
set restart_main = .true.  #set to True to use restart files instead of history files
set run_rigging = .true. #keep set to true

#########
#automated set up steps -- can ignore
set event_year = `echo ${start_date} | cut -b 1-4`
set event_moday = `echo ${start_date} | cut -b 5-8`
set sourcefile = WOFenv_rlt_${event_year}_${event_moday}_${serial} #source main runtime param file
cp /glade/work/$USER/WOF/scripts/WOFenv_rlt_${event_year}_${event_moday} /glade/work/$USER/WOF/scripts/${sourcefile}
source /glade/work/$USER/WOF/scripts/WOFenv_rlt_${event_year}_${event_moday}
source ${TOP_DIR}/realtime.cfg.${event}.${exp}
echo "set exp = ${exp}" >> ${sourcefile}
echo "set restart_main = ${restart_main}" >> ${sourcefile} 
touch RMSD_checks/RMSD_check.${event}.${exp}.out
echo  "LOG: EXP RESTART" >> RMSD_checks/RMSD_check.${event}.${exp}.out
#########

# Copy in correct DART input.nml to rundir

yes | cp -f ${TOP_DIR}/${input_nml_file}_${ENS_SIZE}mem ${RUNDIR}/input.nml

# Copy in latest version of filter to rundir
yes | cp -f ${TOP_DIR}/filter_archive/filter ${RUNDIR}/WRF_RUN/filter

#clean up and logmaking steps
rm -rf ${RUNDIR}/filter_done
rm -rf ${RUNDIR}/experiment_log.txt
touch ${RUNDIR}/experiment_log.txt
touch ${RUNDIR}/pertlog_main.txt
mkdir ${RUNDIR}/logs

#automated steps for spinup period
set end_spinup_date = 203501261200
if ( ${spin_up_mins} != 0 ) then 
    touch ${SEMA4}/spinup
    cd $RUNDIR
    set end_spinup_date = `echo ${nextCcycle} ${spin_up_mins}m -f ccyymmddhhnn | ${RUNDIR}/advance_time`
    cd $SCRIPTDIR
endif 

#start main loop

while ( 1 == 1 )
 
    #source required variables and set date for filter
    #start date can be set from realtime.cfg file in realtime folder

    source ${TOP_DIR}/realtime.cfg.${event}.${exp}
    set save_start = 'yes'
    set datea = ${nextCcycle}
    set datef = ${nextCcycle}
    cd $RUNDIR
    ./clean_advance_temp.sh #removes old files from advance_temp folders

    #automated spin up steps

    if ( -e ${SEMA4}/spinup ) then
       touch ${SEMA4}/skip_filter
    endif

    if ( -e ${SEMA4}/spinup && ${datea} == ${end_spinup_date} ) then
       rm -rf ${SEMA4}/spinup
       rm -rf ${SEMA4}/skip_filter
    endif
    


    #remove old flags from flag directory in experiment run folder

    rm -rf ${SEMA4}/wrf_done*

    rm -rf ${SEMA4}/mem*_blown
 
    # Compute necessary times to facilitate NEWSe execution 
    set datep  =  `echo  $datea -${assim_per_conv}m | ${RUNDIR}/advance_time` 
    echo $datep
    set daten  =  `echo  $datea ${assim_per_conv}m | ${RUNDIR}/advance_time`
    echo $daten
    set gdate  = `echo $datea 0 -g | ${RUNDIR}/advance_time`
    echo $gdate
    set gdatef = `echo  $datea ${assim_per_conv}m -g | ${RUNDIR}/advance_time`
    echo $gdatef
    set wdate  =  `echo  $datea 0 -w | ${RUNDIR}/advance_time`
    echo $wdate
#####################
#filter code start
#####################

####
    set iteration = 0 #keep set to 0

    foreach obs_file ( ${OBSDIR}/${OBSTYPE}/obs_seq.combined_full_cropped.${datea} ) #if you ever change the naming conventions for obs sequence files, change the entry here
 
    if ( -e ${obs_file} && ! -e ${RUNDIR}/flags/skip_filter ) then  
    @ iteration = $iteration + 1 
####


####
    #code for assimilating more than one obs seq file, can ignore
    if ( ${iteration} > 1 ) then 
       yes | cp ${RUNDIR}/input.nml.conv3 ${RUNDIR}/input.nml
    endif
####

####
#!!! link obs sequence file specified by for loop
    ${LINK} ${obs_file} obs_seq.out
####

     # Link in prior inflation mean and sd files for filter -ignore if not using anderson multiplicative inflation
     #if ( ${datea} != ${runDay}${cycle}00 ) then

     #   ${LINK} ${RUNDIR}/${datep}/output_priorinf_mean.nc.${datep} ./input_priorinf_mean.nc
     #   ${LINK} ${RUNDIR}/${datep}/output_priorinf_sd.nc.${datep} ./input_priorinf_sd.nc
      
     #endif

     #${LINK} ${ENSEMBLE_INIT}/rundir_3km/advance_temp1/wrfinput_d01 wrfinput_d01

     ${REMOVE} Main.sed
     
     echo "2i\"                                                                               >! Main.sed
     echo '#PBS' "-N wof_filter\"                                                             >> Main.sed
     echo '#PBS' "-q premium\"                                                             >> Main.sed

     echo '#PBS' "-o ${RUNDIR}/wof_filter.log\"                                                         >> Main.sed
     echo '#PBS' "-e ${RUNDIR}/wof_filter.err\"                                                         >> Main.sed
     echo '#PBS' "-l select=${FILTER_NODES}:ncpus=${FILTER_CORES}:mpiprocs=${FILTER_CORES}:mem=109GB\"  >> Main.sed
     echo '#PBS' "-l walltime=04:00:00\"                                                      >> Main.sed
     echo '#PBS' "-A UMCP0011\"                                                               >> Main.sed
     echo '#PBS' "-k oed\"                                                                    >> Main.sed

     echo "#=================================================================="   >> Main.sed 
     sed -i "/mpiexec_mpt/c\mpiexec_mpt dplace -s 1 ${RUNDIR}/WRF_RUN/filter" ${SCRIPTDIR}/filter_rlt.job
     sed -f Main.sed ${SCRIPTDIR}/filter_rlt.job >! wof_filter.job
     chmod +x wof_filter.job
     sleep 1
       
     ##########
     #duplicate and rename necessary wrf fields for running filter
     ##########
     if ( ${restart_main} == .true. ) then
     rm -rf ${RUNDIR}/rig.log
     touch ${RUNDIR}/rig.log
     qsubcasper ${RUNDIR}/rig_restarts_for_dart_prefilt.sh 
     set wait = 1 
     while ( ${wait} == 1 )
  
         if ( `grep -c "SUCCESS" ${RUNDIR}/rig.log` == 8 ) then 
              set wait = 0 
         endif 
     end
     endif
     rm -rf ${RUNDIR}/rig.log
     touch ${RUNDIR}/rig.log
     echo ${datea} ${obs_file} >> ${RUNDIR}/experiment_log.txt 
 
     ########
     #submit filter job and record submit time for log purposes
     qsub wof_filter.job 
     echo $filter_time
     set filter_thresh = `echo $filter_time | cut -b3-4`
     echo $filter_thresh
     @ filter_thresh = `expr $filter_thresh \+ 0` * 60 + `echo $filter_time | cut -b1-1` * 3600
     set submit_time = `date +%s`
     sleep 10


     #wait on filter to finish
     while ( ! -e filter_done )
  
	sleep 10
	echo "waiting on filter ..." 
     end
     echo "EXIT FILTER"
     ########
     #second round of modifying restart files
     #currently done in advance_model_rlt and advance_model_rlt_updatebc
     ########
     #if ( ${restart_main} == .true. ) then
     #rm -rf ${RUNDIR}/rig.log
     #touch ${RUNDIR}/rig.log
     #qsubcasper ${RUNDIR}/rig_restarts_for_dart_postfilt.sh 
     #set wait = 1
     #while ( ${wait} == 1 )

     #    if ( `grep -c "SUCCESS" ${RUNDIR}/rig.log` == 64 ) then
     #         set wait = 0
     #    endif
     #end
     #endif
     #rm -rf ${RUNDIR}/rig.log
     #touch ${RUNDIR}/rig.log

     ${REMOVE} filter_done  
    #  Move DART output files to storage directories in the experiment run folder
     foreach FILE ( preassim output )
        if ( -e ${FILE}_mean.nc && -e ${FILE}_sd.nc ) then
           #${MOVE} ${FILE}_mean.nc ${RUNDIR}/${datea}/${FILE}_mean.nc.${datea}.`basename ${obs_file}`
           ${MOVE} ${FILE}_mean.nc ${RUNDIR}/${datea}/${FILE}_mean.nc.${datea}

           #${MOVE} ${FILE}_sd.nc ${RUNDIR}/${datea}/${FILE}_sd.nc.${datea}.`basename ${obs_file}`
           ${MOVE} ${FILE}_sd.nc ${RUNDIR}/${datea}/${FILE}_sd.nc.${datea}

           ${MOVE} ${FILE}_priorinf_mean.nc ${RUNDIR}/${datea}/${FILE}_priorinf_mean.nc.${datea}
           ${MOVE} ${FILE}_priorinf_sd.nc ${RUNDIR}/${datea}/${FILE}_priorinf_sd.nc.${datea}
           if ( ! $status == 0 ) then
              echo "failed moving ${RUNDIR}/${FILE}"
              touch BOMBED
           endif
        endif
     end

     #  A fatal error occurred.  Shut down the system --currently turned off
     if ( -e BOMBED ) then
        echo "missing inflation or other DART input files ... attempting to ignore" 
        #echo "FATAL SYSTEM ERROR"
        #touch ABORT_STEP
        ${REMOVE} BOMBED
        #exit

     endif
     #move obs_seq.final to correct folder and remove inflation files for enkf 
     #run checks on RMSD after fiter completion 
     ${MOVE} obs_seq.final ${RUNDIR}/${datea}/obs_seq.final.${datea}.`basename ${obs_file}`
     ${REMOVE} input_priorinf*
     cd ${SCRIPTDIR}
     ./run_check.sh ${datea} ${event}.${exp}  
     cd ${RUNDIR}

    endif 
    end
####
#remove flags and old log files
     rm -rf ${SEMA4}/skip_filter
     rm -rf ${RUNDIR}/rig_restarts.log
     if ( ${test_mode} == 1 ) then
         exit (0)
     endif 
############################
#end filter loop
############################
     source ${TOP_DIR}/realtime.cfg.${event}.${exp}
     ######
     #if using restart files then set restart flag to true in namelist
     ######
     if ( ${datea} == ${start_date} ) then
     echo "setenv restart .false." >> ${TOP_DIR}/realtime.cfg.${event}.${exp}
     else if ( ${datea} != ${start_date} && ${restart_main} == .true. ) then
     echo "setenv restart .true." >> ${TOP_DIR}/realtime.cfg.${event}.${exp}
     endif 
     rm -rf ${RUNDIR}/rig.log
     set n = 1
     while ( $n <= $ENS_SIZE )
     #  Integrate ensemble members to next analysis time
     echo "#\!/bin/csh"                                                            >! ${RUNDIR}/wof_adv_mem.csh
     echo "#=================================================================="    >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-N wof_adv_mem_${n}"                                                  >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-q economy"                                                  >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-o ${RUNDIR}/wof_adv_mem_${n}.log"                                              >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-e ${RUNDIR}/wof_adv_mem_${n}.err"                                              >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-l select=${WRF_NODES}:ncpus=${WRF_CORES}:mpiprocs=${WRF_CORES}" >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-l walltime=01:00:00"                                            >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-A UMCP0011"                                                     >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-k oed"                                                          >> ${RUNDIR}/wof_adv_mem.csh
     echo "#=================================================================="    >> ${RUNDIR}/wof_adv_mem.csh   

     cat >> ${RUNDIR}/wof_adv_mem.csh << EOF

     source /glade/work/$USER/WOF/scripts/WOFenv_rlt_${event_year}_${event_moday}
     source ${TOP_DIR}/realtime.cfg.${event}.${exp}

     set echo

     set start_time = \`date +%s\`
     echo "host is " \`hostname\`
     cd ${RUNDIR}

     #  copy files to appropriate location
     echo \$start_time >& start_member_${n}
     # here we are recycling the wrfout files so it should already exist
     if ( -d ${RUNDIR}/advance_temp${n} ) then
        cd ${RUNDIR}/advance_temp${n}
     else
        rm -rf ${RUNDIR}/advance_temp${n}  >& /dev/null
        mkdir -p ${RUNDIR}/advance_temp${n}
        cd ${RUNDIR}/advance_temp${n}
     endif


     #integrate the model forward in time
     cd ${RUNDIR}

     ######
     #if intermediate cycle run advance_model_rlt.csh (no update to BC's)
     #if hourly cycle run advance_model_rlt_updatebcs.csh to update lateral boundary conditions
     ######
     if ( `echo ${datea} | cut -c 11-12` == 00 ) then
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! logs/advance_temp.${n}.out
     else if ( `echo ${datea} | cut -c 11-12` == 15 && ${fast_LBC_update} == .true. ) then 
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! logs/advance_temp.${n}.out
     else if ( `echo ${datea} | cut -c 11-12` == 30 && ${fast_LBC_update} == .true. ) then 
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! logs/advance_temp.${n}.out
     else if ( `echo ${datea} | cut -c 11-12` == 45 && ${fast_LBC_update} == .true. ) then 
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! logs/advance_temp.${n}.out
     else
     ${SCRIPTDIR}/advance_model_rlt_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 0 >&! logs/advance_temp.${n}.out
     endif 
     set end_time = \`date  +%s\`
     @ length_time = \$end_time - \$start_time
     echo "duration = \$length_time"
EOF

     qsub wof_adv_mem.csh
     @ n++ 
     end 

     cd ${RUNDIR}

     #  check to see if all of the ensemble members have advanced
     set advance_start_thresh = `echo $advance_start | cut -b3-4`
     @ advance_start_thresh = `expr $advance_start_thresh \+ 0` * 60 + `echo $advance_start | cut -b1-1` * 3600 
     @ advance_start_thresh = `expr $advance_start_thresh \+ 0` * 60 + `echo $advance_start | cut -b1-1` * 3600 

     set advance_thresh = `echo $advance_time | cut -b3-4`
     @ advance_thresh = `expr $advance_thresh \+ 0` * 60 + `echo $advance_time | cut -b1-1` * 3600 

     set n = 1
     while ( $n <= $ENS_SIZE )

	set keep_trying = true

	while ( $keep_trying == 'true' )

           set submit_time = `date +%s`

           @ count = 0 
           #  Wait for the output file
           while ( 1 == 1 && -e start_member_${n} )
              @ count += 1 
              set start_time = `head -1 start_member_${n}`
              set current_time = `date  -u +%s`
              @ length_time = $current_time - $start_time

              if ( -e ${SEMA4}/wrf_done${n} ) then

        	 #  If the output file already exists, move on
        	 set keep_trying = false
        	 break

              else if ( -e ${SEMA4}/mem${n}_blown ) then
                   sed -i "s/temp${ENS_SIZE}/temp${n}/" wof_adv_mem.csh
                   sed -i "s/member_${ENS_SIZE}/member_${n}/" wof_adv_mem.csh
                   sed -i "s/csh ${ENS_SIZE} 1/csh ${n} 1/" wof_adv_mem.csh
                 
                   qsub wof_adv_mem.csh
                   rm ${SEMA4}/mem${n}_blown    
              else if ( ${count}>120 ) then 
                  # sed -i "s/temp${ENS_SIZE}/temp${n}/" wof_adv_mem.csh
                  # sed -i "s/member_${ENS_SIZE}/member_${n}/" wof_adv_mem.csh
                  # sed -i "s/csh ${ENS_SIZE} 1/csh ${n} 1/" wof_adv_mem.csh
                  # qsub wof_adv_mem.csh
                   @ count = 0 
                  
              endif 
              sleep 5

           end

	end
	
    ${REMOVE} start_member_${n} wof_adv_mem${n}.log wof_adv_mem${n}.err 

	@ n++

     end

     ${MOVE} obs_seq.final.${datea}.nc ${RUNDIR}/${datea}

     ${MOVE} wof_filter.log wof_filter.log.${datea} 

     grep cfl advance_temp*/rsl* > cfl_log.${datea}

     ${REMOVE} wof_filter.err obs_seq.out

     ${REMOVE} wof_adv_mem.csh


     # Advance to the next time if this is not the final time
     echo "Starting next time"
     set nextCcycle = `echo $datea ${assim_per_conv}m | ${RUNDIR}/advance_time`

     if ( ${nextCcycle} == ${stop_date} ) then
         exit (0)
     endif
     #change to sed command 
     echo "setenv nextCcycle ${nextCcycle}" >> ${TOP_DIR}/realtime.cfg.${event}.${exp}
  end


exit (0)
