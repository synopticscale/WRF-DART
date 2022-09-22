#!/bin/csh
########################################################################
#PBS -N NEWSe_main
#PBS -o /glade/work/jmccurry/WOF/scripts/NEWSe_main.log
#PBS -e /glade/work/jmccurry/WOF/scripts/NEWSe_main.err_64_mem_3km_pf_hybrid_15MIN_CSEC_fcst1930
#PBS -l select=1:ncpus=1
#PBS -l walltime=7:00:00
#PBS -q regular 
#PBS -A UMCP0011
########################################################################
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
#########
#manual control settings 
set restart_main = .true.
set run_rigging = .false.
set forecast_mode = OSSE
set phys = NSSL
#########
#automated control settings handled by forecast_control.csh
set exp = 64_mem_3km_pf_hybrid_15MIN_CSEC_fcst1930
set filter = `echo $exp | cut -d '_' -f4`
set init = `echo ${exp} | tail -c 5`
set exp = 64_mem_3km_pf_hybrid_15MIN_CSEC_fcst1930
set event = 20190703
set WRFOUT  = /glade/scratch/jmccurry/WOF/realtime/20190703.64_mem_3km_pf_hybrid_15MIN_CSEC/WRFOUTS_FCST201907031930
set GCIDIR  = hybrid
set GCISUBDIR = 25dbz_64_mem_restarts_15MIN_CSEC
set SCRIPTDIR = /glade/work/jmccurry/WOF/scripts
set OBSTYPE = OBS_SEQ_CONV
set sourcefile = forecastcpanel/WOFenv_rlt_64_mem_3km_pf_hybrid_15MIN_CSEC_fcst1930_pf0703_init1930
set error_log = ${SCRIPTDIR}/${exp}.auxiliary_err
cp ${SCRIPTDIR}/WOFenv_rlt_forecast ${SCRIPTDIR}/${sourcefile}
echo "setenv event ${event}" >> ${SCRIPTDIR}/${sourcefile}
echo "setenv exp ${exp}" >> ${SCRIPTDIR}/${sourcefile}
echo "setenv WRFOUTDIR ${WRFOUT}"  >> ${SCRIPTDIR}/${sourcefile}
echo "set restart_main = ${restart_main}" >> ${sourcefile}

source /glade/work/jmccurry/WOF/scripts/${sourcefile}

source ${TOP_DIR}/realtime.cfg.${event}.${exp}
${REMOVE} ${error_log}
touch ${error_log}

mkdir ${WRFOUT}

#########
#manual controls not handled by forecast_control.csh

set num_cycles = 6 
set test_mode = 0 


#########

#########
#forecast controls 

set forecast_length = 90m 
set FORECAST_ENS = 20
#########
${REMOVE} ${RUNDIR}/flags/wrf_done* ${RUNDIR}/flags/*blown 
${REMOVE} ${RUNDIR}/experiment_log.txt
touch ${RUNDIR}/experiment_log.txt
@ cycle_count = -1 
#set save_start = 'forecast'
set save_start = 'forecast_detailed'

while ( 1 == 1 )
    @ cycle_count++  
    #source required variables and set date for filter
    #start date can be set from realtime.cfg file in realtime folder
    if ( ${run_rigging} == .false. ) then 
       touch ${RUNDIR}/flags/skip_filter 
    source ${TOP_DIR}/realtime.cfg.${event}.${exp}
    set datea = ${nextCcycle}
    set datef = ${nextCcycle}
  
    set wrfmin = `echo ${datea} | cut -c 11-12`
    
    if ( (${cycle_count} == 0) && ( ${wrfmin} != 00 ) ) then
         touch ${SEMA4}/init_offhourly
    else
         ${REMOVE} ${SEMA4}/init_offhourly
    endif



    cd $RUNDIR
    ./clean_advance_temp.sh     

    ${REMOVE} ${RUNDIR}/forecast_log.txt
    touch ${RUNDIR}/forecast_log.txt


    # Copy in correct DART input.nml  
    

    yes | cp -f ${TOP_DIR}/input.nml.forecast ${RUNDIR}/input.nml
    cp ${SCRIPTDIR}/cycle_init_utils/fix_missing_wrfouts.sh ${RUNDIR}/fix_missing_wrfouts.sh


  ${REMOVE} ${SEMA4}/wrf_done*

    ${REMOVE} ${SEMA4}/mem*_blown
 
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
#filter loop start
#####################

####
#!!!insert code for main loop of obs_seq files 
    set iteration = 0
#   foreach obs_file ( ${OBSDIR_full}/obs_seq.combined_noVR.${datea} ${OBSDIR_full}/obs_seq_vr.KDMX.${datea} ${OBSDIR_full}/obs_seq_vr.KOAX.${datea} ${OBSDIR_full}/obs_seq_vr.KDVN.${datea} ${OBSDIR_full}/obs_seq_vr.KUEX.${datea} ${OBSDIR_full}/obs_seq_vr.KTWX.${datea} ${OBSDIR_full}/obs_seq_vr.KEAX.${datea} ${OBSDIR_full}/obs_seq_vr.KLSX.${datea} ${OBSDIR_full}/obs_seq_vr.KICT.${datea} ${OBSDIR_full}/obs_seq_vr.KSGF.${datea} ${OBSDIR_full}/obs_seq_vr.KVNX.${datea} ${OBSDIR_full}/obs_seq_vr.KINX.${datea} )

     foreach obs_file ( ${OBSDIR}/${OBSTYPE}/obs_seq.combined_full_cropped.${datea} )
     #foreach obs_file ( ${OBSDIR}/OBS_SEQ_UNMASKED_VR/obs_seq.vronly_full_cropped.${datea} )

#    foreach counter (`seq 10 10 10000`)
#    set obs_file  = ${OBSDIR_full}/obs_seq_vr.KDMX.interval_${counter}.${datea}
 
    if ( -e ${obs_file} && ! -e ${RUNDIR}/flags/skip_filter ) then  
    @ iteration = $iteration + 1 
####


####
#!!!insert code to change input.nml for filter iteration > 1 (no inflation) 
    if ( ${iteration} > 1 ) then 
       yes | cp ${RUNDIR}/input.nml.conv3 ${RUNDIR}/input.nml
    endif
####

    #set obs_file = ${OBSDIR}/OBS_SEQ_CONV/obs_seq.combined_noKDVN.${datea}
    #set obs_file_backup = ${OBSDIR}/OBS_SEQ_CONV/obs_seq.combined_noKDVN.${datea}
####
#!!! comment out or delete following section
####
     # Use dummy file if obs sequence file is not generated
     #if ( ${datea} != ${runDay}0100 ) then

        #${LINK} ${obs_file} obs_seq.out

     #else
        #${LINK} ${obs_file_backup} obs_seq.out
     #endif
####
#!!! link obs sequence file specified by for loop
    ${LINK} ${obs_file} obs_seq.out
####

     # Link in prior inflation mean and sd files for filter
    # if ( ${datea} != ${runDay}${cycle}00 ) then

    #    ${LINK} ${RUNDIR}/${datep}/output_priorinf_mean.nc.${datep} ./input_priorinf_mean.nc
    #    ${LINK} ${RUNDIR}/${datep}/output_priorinf_sd.nc.${datep} ./input_priorinf_sd.nc
      
    # endif

     ${LINK} ${ENSEMBLE_INIT}/rundir_3km/advance_temp1/wrfinput_d01 wrfinput_d01

     ${REMOVE} Main.sed
     
     echo "2i\"                                                                               >! Main.sed
     echo '#PBS' "-N wof_filter\"                                                             >> Main.sed
     echo '#PBS' "-q premium\"                                                             >> Main.sed

     echo '#PBS' "-o ${RUNDIR}/wof_filter.log\"                                                         >> Main.sed
     echo '#PBS' "-e ${RUNDIR}/wof_filter.err\"                                                         >> Main.sed
     echo '#PBS' "-l select=8:ncpus=${FILTER_CORES}:mpiprocs=${FILTER_CORES}:mem=109GB\"  >> Main.sed
     echo '#PBS' "-l walltime=00:30:00\"                                                      >> Main.sed
     echo '#PBS' "-A UMCP0011\"                                                               >> Main.sed

     echo "#=================================================================="   >> Main.sed 
     sed -i "/mpiexec_mpt/c\mpiexec_mpt dplace -s 1 ${RUNDIR}/WRF_RUN/filter" ${SCRIPTDIR}/filter_rlt.job
     sed -f Main.sed ${SCRIPTDIR}/filter_rlt.job >! wof_filter.job
     chmod +x wof_filter.job
     sleep 1

     ##########
     #duplicate and rename necessary wrf fields for running filter
     ##########
     if ( ${restart_main} == .true. ) then
     ${REMOVE} ${RUNDIR}/rig.log
     touch ${RUNDIR}/rig.log
     qsubcasper ${RUNDIR}/rig_restarts_for_dart_prefilt.sh 
     set wait = 1
     while ( ${wait} == 1 )

         if ( `grep -c "SUCCESS" ${RUNDIR}/rig.log` == 8 ) then
              set wait = 0
         endif
     end
     endif
     ${REMOVE} ${RUNDIR}/rig.log
     touch ${RUNDIR}/rig.log
     echo ${datea} ${obs_file} >> ${RUNDIR}/experiment_log.txt

     ########


     echo ${datea} ${obs_file} >> ${RUNDIR}/experiment_log.txt 
     qsub wof_filter.job 


     echo $filter_time
     set filter_thresh = `echo $filter_time | cut -b3-4`
     echo $filter_thresh
     @ filter_thresh = `expr $filter_thresh \+ 0` * 60 + `echo $filter_time | cut -b1-1` * 3600

     set submit_time = `date +%s`

     sleep 10

     while ( ! -e filter_done )
  
	sleep 10
	echo "waiting on filter ..." 
     end

     echo "EXIT FILTER"
     ${REMOVE} filter_done  
    #  Move inflation files to storage directories
     foreach FILE ( preassim )
        if ( -e ${FILE}_mean.nc && -e ${FILE}_sd.nc ) then
     #      #${MOVE} ${FILE}_mean.nc ${RUNDIR}/${datea}/${FILE}_mean.nc.${datea}.`basename ${obs_file}`
           mkdir ${WRFOUT}/${datea}
           ${MOVE} ${FILE}_mean.nc ${WRFOUT}/${datea}/forecast_mean.nc.${datea}

           #${MOVE} ${FILE}_sd.nc ${RUNDIR}/${datea}/${FILE}_sd.nc.${datea}.`basename ${obs_file}`
           ${MOVE} ${FILE}_sd.nc ${WRFOUT}/${datea}/forecast_sd.nc.${datea}

     #      ${MOVE} ${FILE}_priorinf_mean.nc ${RUNDIR}/${datea}/${FILE}_priorinf_mean.nc.${datea}
     #      ${MOVE} ${FILE}_priorinf_sd.nc ${RUNDIR}/${datea}/${FILE}_priorinf_sd.nc.${datea}
     #      if ( ! $status == 0 ) then
     #         echo "failed moving ${RUNDIR}/${FILE}"
     #         touch BOMBED
     #      endif
        endif
     end

     #  A fatal error occurred.  Shut down the system
     if ( -e BOMBED ) then
        echo "missing inflation or other DART input files ... attempting to ignore" 
        #echo "FATAL SYSTEM ERROR"
        #touch ABORT_STEP
        ${REMOVE} BOMBED
        #exit

     endif
     ${COPY} obs_seq.final ${WRFOUT}/${datea}/obs_seq.verify.${datea}.`basename ${obs_file}`
     
 
     ${REMOVE} input_priorinf*

     #${RUNDIR}/${datea}/test_corrupt.sh REFL_10CM ${RUNDIR}/${datea}/output_mean.nc.${datea}  
####
#!!!replace wrfinput file with wrfinput sourced from first assim
#if ( ${iteration} == 1 ) then
#${RUNDIR}/purge_advance_temp_base.sh
#endif

#if ( ${iteration} > 1 ) then
#${RUNDIR}/purge_advance_temp_multiob.sh
#endif



####
#!!!insert check obs file existence + loop done
    endif 
    end
####


####
#exit if end of forecast period (based on timestamp or num cycles )
#exit if this is a single filter test
####
     ${REMOVE} ${SEMA4}/skip_filter

     endif
     if ( ${cycle_count} == ${num_cycles} ) then 
         echo "STARTING_POSTPROC" >> ${error_log} 
         touch ${SEMA4}/forecast_done
         mkdir ${TOP_DIR}/forecast_archive
         ${MOVE} ${TOP_DIR}/realtime.cfg.${event}.${exp} ${TOP_DIR}/forecast_archive
         #${REMOVE} ${RUNDIR}
         cd ${SCRIPTDIR}
	 set parent = `echo $WRFOUT | sed 's|\(.*\)/.*|\1|' | sed 's|.*/||' | cut -d "." -f2`
	 #set filter = `echo $WRFOUT | sed 's|\(.*\)/.*|\1|' | sed 's|.*/||' | cut -d "." -f2 | cut -d "_" -f4`

         ##########################
         #setup initialize and wait for filter processing
         ##########################
         foreach i (`ls -d ${WRFOUT}/*/ | sed 's/.$//'`)
         cp ${SCRIPTDIR}/cycle_init_utils/filter ${i}
         cp ${SCRIPTDIR}/cycle_init_utils/restarts_in_forecast.txt ${i}/restarts_in_d01.txt
         cp ${SCRIPTDIR}/cycle_init_utils/restarts_out_forecast.txt ${i}/restarts_out_d01.txt
         cp ${SCRIPTDIR}/input_nmls/input.nml.${forecast_mode}.${phys} ${i}/input.nml
         cd ${i}
         set verif_date = `echo $i | tail -c 13`
         sed -i "s/forecast_/forecast_${verif_date}_/" restarts_in_d01.txt
         sed -i "s/forecast_/forecast_${verif_date}_/" restarts_out_d01.txt

         ln -sf ${OBSDIR}/${OBSTYPE}/obs_seq.combined_full_cropped.${verif_date} obs_seq.out
         cp wrfout_d01_forecast_${verif_date}_1 wrfinput_d01
         #need to modify wof_filter.job
         ${REMOVE} ${RUNDIR}/rig.log
         ${SCRIPTDIR}/filter_setup.csh ${FILTER_CORES} ${i} ${RUNDIR}/rig.log 
         qsub wof_filter.job
         cd ${SCRIPTDIR}
         end
                   
         
         foreach i (`ls -d ${WRFOUT}/*/ | sed 's/.$//'`)
         cd $i

         set wait_for_filter = 1
         while ( ${wait_for_filter} == 1 )
             if ( -f filter_done ) then
              set wait_for_filter = 0
             endif
         end
         set verif_date = `echo $i | tail -c 13`

         echo "FINISHED FILTERING ${verif_date}" >> ${error_log}

         ${MOVE} obs_seq.final obs_seq.verify.combined_full_cropped.${verif_date}
         ${REMOVE} wrfinput_d01 *.job *.log *.err *.nc filter *.txt *.log rig* fix.sh input.nml dart_log.nml  Main.sed filter_done *.out
         cd ${SCRIPTDIR}
         end 
         
         ##########################
         #remove filtering accessories
         ##########################

	 ./globus_WRFOUT.csh ${WRFOUT} ${GCIDIR} ${GCISUBDIR}
         echo "FINISHED TRANSFERING" >> ${error_log}
	 rm -rf ${WRFOUT} 
         exit (0) 

     endif 



     if ( ${test_mode} == 1 ) then
         exit (0)
     endif 
############################
#end filter loop
############################
     #check if reached end of forecast period, if so move model back to forecast start
     source ${TOP_DIR}/realtime.cfg.${event}.${exp}

     set n = 1
     while ( $n <= $FORECAST_ENS )
     #  Integrate ensemble members to next analysis time
     echo "#\!/bin/csh"                                                            >! ${RUNDIR}/wof_adv_mem.csh
     echo "#=================================================================="    >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-N wof_adv_mem_${n}"                                                  >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-q regular"                                                  >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-o ${RUNDIR}/wof_adv_mem_${n}.log"                                              >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-e ${RUNDIR}/wof_adv_mem_${n}.err"                                              >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-l select=${WRF_NODES}:ncpus=${WRF_CORES}:mpiprocs=${WRF_CORES}" >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-l walltime=01:00:00"                                            >> ${RUNDIR}/wof_adv_mem.csh
     echo '#PBS' "-A UMCP0011"                                                     >> ${RUNDIR}/wof_adv_mem.csh
     echo "#=================================================================="    >> ${RUNDIR}/wof_adv_mem.csh   

     cat >> ${RUNDIR}/wof_adv_mem.csh << EOF

     source /glade/work/jmccurry/WOF/scripts/${sourcefile}
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
        ${REMOVE} ${RUNDIR}/advance_temp${n}  >& /dev/null
        mkdir -p ${RUNDIR}/advance_temp${n}
        cd ${RUNDIR}/advance_temp${n}
     endif


     #integrate the model forward in time
     cd ${RUNDIR}
     ######
     #if intermediate cycle run advance_model_rlt.csh (no update to BC's)
     #if hourly cycle run advance_model_rlt_updatebcs.csh
     ######
     set wrfmin = `echo ${datea} | cut -c 11-12`
     if ( (${wrfmin} == 00) && (${cycle_count} == 0) ) then
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! advance_temp_${datea}.out 
     else if ( (${wrfmin} == 00) && (${cycle_count} > 0) ) then
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 0 >&! advance_temp_${datea}.out 

     else if ( -e ${SEMA4}/init_offhourly ) then 
     ${SCRIPTDIR}/advance_model_rlt_updatebc_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} 1 >&! advance_temp_${datea}.out
     else 
     ${SCRIPTDIR}/advance_model_rlt_temp.csh ${n} 1 ${datea} ${sourcefile} ${save_start} ${WRFOUT} ${run_rigging} >&! advance_temp_${datea}.out
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
     while ( $n <= $FORECAST_ENS )
        ${REMOVE} ${SEMA4}/mem${n}_resubmit
        ${REMOVE} ${SEMA4}/mem${n}_slow

	set keep_trying = true

	while ( $keep_trying == 'true' )

           set submit_time = `date +%s`


           #  Wait for the output file
           while ( 1 == 1 && -e start_member_${n} )

              set start_time = `head -1 start_member_${n}`
              set current_time = `date  -u +%s`
              @ length_time = $current_time - $start_time
              @ submit_time = $current_time - $submit_time 

              if ( -e ${SEMA4}/wrf_done${n} ) then

        	 #  If the output file already exists, move on
        	 set keep_trying = false
        	 break

              else if ( -e ${SEMA4}/mem${n}_blown && ! -e ${SEMA4}/mem${n}_resubmit ) then
                   ${RUNDIR}/fix_missing_wrfouts.sh ${n} >> fix_wrfouts.log
                   touch ${SEMA4}/mem${n}_resubmit
                   set submit_time = `date +%s`
                   echo "WARNING MEM ${n} BLOWN --RESUBMITTING" >> ${error_log}
              else if ( ${length_time} > 1200 && ! -e ${SEMA4}/mem${n}_resubmit ) then
                   ${RUNDIR}/fix_missing_wrfouts.sh ${n} >> fix_wrfouts.log
                   touch ${SEMA4}/mem${n}_resubmit
                   set submit_time = `date +%s`
                   echo "WARNING SLOW FINISH MEM ${n} --RESUBMITTING" >> ${error_log}
              else if ( ${submit_time} > 2400 && ! -e ${SEMA4}/mem${n}_slow ) then 
                   touch ${SEMA4}/mem${n}_slow
                   echo 'WARNING SLOW SUBMIT' >> ${error_log}
              endif
              sleep 5

           end

	end
	
    ${REMOVE} start_member_${n} wof_adv_mem${n}.log wof_adv_mem${n}.err 

	@ n++

     end

     ${MOVE} obs_seq.final ${RUNDIR}/${datea}

     ${MOVE} wof_filter.log wof_filter.log.${datea} 

     grep cfl advance_temp*/rsl* > cfl_log.${datea}

     ${REMOVE} wof_filter.err obs_seq.out

     ${REMOVE} wof_adv_mem.csh


     # Advance to the next time 
     echo "Starting next time"
     set nextCcycle = `echo $datea ${assim_per_conv}m | ${RUNDIR}/advance_time`

     echo "setenv nextCcycle ${nextCcycle}" >> ${TOP_DIR}/realtime.cfg.${event}.${exp}
  end


exit (0)
