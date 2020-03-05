#!/usr/bin/perl
use lib '/usr/share/perl5';
use Date::Calc qw(Add_Delta_DHMS);
use Date::Calc qw(Date_to_Days);
use File::Copy;

###############################################################################
###############################################################################
###############################################################################
# 			Credit for Changes				      #
#		Matthew Sienkiewicz	2013 - 2015    			      #
#		Sara Ganetis		May 2016			      #
#		Ryan Connelly		23 Dec 2017			      #
# 									      #
###############################################################################
###############################################################################
###############################################################################

#Choose run options.
	$GEOGRID        = "1";
        $GETSST         = "1";
	$DOWNLOAD	= "1";
	$UNGRIB		= "1";
	$METGRID        = "1";
	$REAL           = "1";
	$WRF            = "1";
	$PYTHON         = "1";
	$UPP            = "1";
	$RIP            = "1";
	$NCL		= "1";
	$FRONTPAGELOOP	= "1";
	$CLEANUP	= "1";

#Set Paths
	$dirWRFV3	= "/D0/sbuwrf/REALTIME/WRFv3.9.1/WRFV3";
	$dirWPS		= "/D0/sbuwrf/REALTIME/WRFv4.0/WPS";
	$dirRIP4	= "/D0/sbuwrf/REALTIME/WRFv3.7.1/RIP4";
	$curl		= "/usr/bin/curl -L -fs --retry 4 --retry-delay 4 --max-time 150";
	$med		= "/opt/ncl/bin/med";
	$xwdtopnm	= "/usr/bin/xwdtopnm";		# DOES NOT EXIST!
	$ppmtogif	= "/usr/bin/ppmtogif";		# DOES NOT EXIST!
	$ctrans		= "/opt/ncl/bin/ctrans -d xwd -resolution 1350x1200";
	$infiles	= "/D0/sbuwrf/REALTIME/infiles"; #where the RIP infiles are located

#Set Run Options
	$ENV{RUNLENGTH}	= 84;	#Forecast hours
	$ENV{INTERVAL}	= 3;	#Hours between bdy condition calls
	$int 		= $ENV{INTERVAL};
	$init		= "00";	#Model init time, i.e. "00", "06", "12", "18"
	$ENV{MAX_DOM}	= 3;	#Maximum number of domains for run
	$ENV{INTERVAL_SECONDS}	= $int * 60 * 60;	#Don't change this.
	$vtable		= "Vtable.GFS";
	$mname		= "GFS";
	$ENV{NODE}	= "1";	#Number of nodes to use
	$ENV{NPROC}	= 64;
	$max_dom	= $ENV{MAX_DOM};
	$runlength	= $ENV{RUNLENGTH};
	$int 		= $ENV{INTERVAL};

#Set rip inputs
@ripins = (#	"winds_sfc",	"winds_925",	"winds_850",	"winds_700",	"winds_500",	"winds_300",
#		"temps_sfc",	"temps_925",	"temps_850",	"temps_700",	"temps_500",
#		"500_avo",	"700_dBZfronto",	"700_RHomg",	"850_dBZfronto",	"capeshear",
#		"700_RHomg",
#		"pblht",	"pcp1",		"pcp24",	"pcp3",	"pw",	"refl_10cm",
		"pblht",	#"pw",
#		"slp_thickness",	"wetbulb_slp",
		"sound_ABE",	"sound_ACK",	"sound_ACY",	"sound_ALB",	"sound_BDL",	"sound_BDR",	"sound_BOS",	"sound_CHH",
		"sound_DOV",	"sound_EWR",	"sound_GON",	"sound_HPN",	"sound_HYA",	"sound_ILG",	"sound_ISP",	"sound_JFK",
		"sound_MTP",	"sound_NYC",	"sound_OKX",	"sound_ORH",	"sound_PHL",	"sound_POU",	"sound_PSF",	"sound_PVD",	"sound_SBU",
		"sound_SWF",	"sound_TEB",	"sound_TTN",	"sound_WRI",    "sound_P01",    "sound_P02",    "sound_P03",
		"xsect_dBZfronto_A",		"xsect_dBZfronto_B",	"xsect_dBZfronto_C",		"xsect_dBZfronto_D",
		"xsect_dBZtheta_A",		"xsect_dBZtheta_B",	"xsect_dBZtheta_C",		"xsect_dBZtheta_D",
		"xsect_mpvthes_A",		"xsect_mpvthes_B",	"xsect_mpvthes_C",		"xsect_mpvthes_D",
		"xsect_RHtheta_A",		"xsect_RHtheta_B",	"xsect_RHtheta_C",		"xsect_RHtheta_D",
                "xsect_tmpcq_A",		"xsect_tmpcq_B",	"xsect_tmpcq_C",		"xsect_tmpcq_D", "temps_ground");
###############################################################################
###############################################################################
###############################################################################
#Find run date and time in UTC
$init	= $ARGV[0];

if (length("$init") == 2) {
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime(time);
    $year += 1900;
    $mon += 1;
    if ($mon<10) {$mon="0$mon";}
    if ($mday<10) {$mday="0$mday";}
    $day = "$year"."$mon"."$mday"."$init";

}
elsif (length("$init") == 10) {
    $day = "$init";
}
	$gfsday = substr($day,0,8);
	$YYYY = substr($day,0,4);
	$MM = substr($day,4,2);
	$DD = substr($day,6,2);
	$HH = substr($day,8,2);
	$initHH = substr($day,8,2);
        $sTime_unformatted = "$YYYY$MM$DD$HH";  #Start time unformatted, for UPP script
	$sTime = "$YYYY-$MM-$DD"."_$HH:00:00";	#Start Time
	my $time = localtime;
	print "\n$time\tRun BEG: $sTime\n";

	#Get End Time
	($eYYYY,$eMM,$eDD,$eHH,$eMN,$eSS) = Add_Delta_DHMS($YYYY,$MM,$DD,
						$HH,"00","00","00",$runlength,"00","00");
	if (length("$eHH") != 2) { $eHH="0$eHH"; }
	if (length("$eDD") != 2) { $eDD="0$eDD"; }
	if (length("$eMM") != 2) { $eMM="0$eMM"; }
	$eTime = "$eYYYY-$eMM-$eDD"."_$eHH:00:00";	#End Time
	my $time = localtime;
	print "$time\tRun END: $eTime\n\n";

	#Set directory where everything will be done.
	$ENV{OUTDIR}		= "/D0/sbuwrf/REALTIME/GFS/$day";
	$outdir			= $ENV{OUTDIR};
 	unless ( -d $outdir ) { mkdir $outdir; }
###############################################################################
###############################################################################
###############################################################################
if ($GEOGRID) {
	my $time = localtime;
	print "\n$time\tStarting GEOGRID \n";

	my $interval_seconds = $ENV{INTERVAL_SECONDS};
	#Create namelist.wps
	&namelistWPS($sTime,$eTime,$max_dom,$interval_seconds,$outdir);

	#Set up directory for geogrid
	symlink "$dirWPS/geogrid/src/geogrid.exe","$outdir/geogrid.exe";
	symlink "$dirWPS/geogrid/GEOGRID.TBL","$outdir/GEOGRID.TBL";

	#Create PBS script to run geogrid.exe
        print $time = localtime;
	my $pbs_func = "geogrid";
	my $type_q = "shortq";
	&make_pbs_script($pbs_func,$type_q);

	system ("cd ${outdir}; GEOGRID_ID=`qsub run_${pbs_func}.pbs`");

	#Check to see if geogrid completed. If not, exit.
	my $max_dom = $ENV{MAX_DOM};
	my $num_geo_files = $max_dom - 1;
	my $count_geo = 0;
	while(1) {
		my @geofiles = <${outdir}/geo_em*.nc>;
		#print "$geofiles\t$#geofiles\n";
		if ($#geofiles == $num_geo_files) {
			my $time = localtime;
			print "\n$time\tCompleted GEOGRID!\n\n";
			sleep (4);  #To give the file time to finish in the background
			last;
		} else {
			sleep(2);
		}
		if ($count_geo == 600) {
			my $time = localtime;
			print "\n$time\tERROR: GEOGRID Failed.\n\n";
			system ("qdel $GEOGRID_ID");
			exit;
		} else {
			$count_geo = $count_geo + 1;
		}
	}

	#Hide the evidence.
	unlink "$outdir/geogrid.exe";
	unlink "$outdir/GEOGRID.TBL";
	system ("cd $outdir; rm $outdir/geogrid.log.*");
	#unlink "$outdir/namelist.wps";
}
###############################################################################
###############################################################################
###############################################################################
if ($GETSST) {
    my $time = localtime;
    print "\n$time\tStarting SST\n";

    unlink "$outdir/$YYYY$MM$DD$HH"."_SST.grb2";
    $ENV{SST} = "$outdir/SST:$YYYY-$MM-$DD"."_$HH";

    #Set up directory for ungrib
    symlink "$dirWPS/ungrib/src/ungrib.exe","$outdir/ungrib.exe";
    symlink "$dirWPS/ungrib/Variable_Tables/Vtable.SST","$outdir/Vtable";
    symlink "$dirWPS/link_grib.csh","$outdir/link_grib.csh";

    #URL for directory where sst grids will be found
    $url = "http://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod";

    #SST grid file names (on server and renamed for our use).
    $file1 = "sst.$YYYY$MM$DD/rtgssthr_grb_0.083.grib2";
    $file2 = "$YYYY$MM$DD$HH"."_SST.grb2";

    system("$curl -f -s $url/$file1 -o $outdir/$file2");

    #Check to see if GRIB2 downloaded.
    if ( -e "$outdir/$file2" ) {
        my $time = localtime;
        print "$time\t\tDOWNLOADED!\n";
        #Create namelist.wps
	$sstTime = "$YYYY-$MM-$DD"."_00:00:00";
        &namelistSST($sstTime,$sstTime);

        #Run link_grib.csh
        system ("cd $outdir; $outdir/link_grib.csh $file2");

        #Run ungrib.exe
        system ("cd $outdir; $outdir/ungrib.exe >/dev/null 2>&1");

        #Check to see if ungrib was successful. If not, exit script.
        if ( -e "$outdir/SST:$YYYY-$MM-$DD"."_00" ) {
            my $time = localtime;
            print "$time\t\tUNGRIBBED!\n";
            rename "$outdir/SST:$YYYY-$MM-$DD"."_00","$outdir/SST:$YYYY-$MM-$DD"."_$HH";
        }
        else {
            my $time = localtime;
            print "$time\t\tERROR: UNGRIB Failed.\n";
            exit;
        }
    }
    else {
        my $time = localtime;
        print "$time\t\tERROR: DOWNLOAD Failed. Trying previous day...\n";
	#Find date and time of model file
	($ryyyy,$rmm,$rdd,$rHH,$rMN,$rSS) = Add_Delta_DHMS($YYYY,$MM,$DD,
							$HH,"00","00","-1","00","00","00");
	if (length("$rdd") != 2) { $rdd="0$rdd"; }
	if (length("$rmm") != 2) { $rmm="0$rmm"; }
        #SST grid file names (on server and renamed for our use).
        $file1 = "sst.$ryyyy$rmm$rdd/rtgssthr_grb_0.083.grib2";
        $file2 = "$YYYY$MM$DD$HH"."_SST.grb2";
        system("$curl $url/$file1 -o $outdir/$file2");
        if ( -e "$outdir/$file2" ) {
            my $time = localtime;
            print "$time\t\tDOWNLOADED!\n";
	    $sstTime = "$ryyyy-$rmm-$rdd"."_00:00:00";
            &namelistSST($sstTime,$sstTime);

            #Run link_grib.csh
            system ("cd $outdir; $outdir/link_grib.csh $file2");

            #Run ungrib.exe
            system ("cd $outdir; $outdir/ungrib.exe >/dev/null 2>&1");

            #Check to see if ungrib was successful. If not, exit script.
            if ( -e "$outdir/SST:$ryyyy-$rmm-$rdd"."_00" ) {
                my $time = localtime;
                print "$time\t\tUNGRIBBED!\n";
                rename "$outdir/SST:$ryyyy-$rmm-$rdd"."_00","$outdir/SST:$YYYY-$MM-$DD"."_$HH";
            }
            else {
                my $time = localtime;
                print "$time\t\tERROR: UNGRIB Failed.\n";
                exit;
            }
        }
        else {
            my $time = localtime;
            print "$time\t\tERROR: DOWNLOAD Failed. Skipping SST...\n";
        }
    }

    #Clean up directory.
#    unlink "$outdir/ungrib.exe";
    unlink "$outdir/Vtable";
    unlink "$outdir/ungrib.log";
    unlink "$outdir/namelist.wps";
    unlink "$outdir/link_grib.csh";
    unlink "$outdir/GRIBFILE.AAA";
    unlink "$outdir/$YYYY$MM$DD$HH"."_SST.grb2";

    my $time = localtime;
    print "$time\tCompleted SST!\n\n";

}
###############################################################################
###############################################################################
###############################################################################
#Loop through each model grid file
#for ($FHR = 0; $FHR <= $runlength; $FHR+=$int) {

  #Download loop
  for ($FHR = 0; $FHR <= $runlength; $FHR+=$int) {
	if (length("$FHR") != 2) { $FHR="0$FHR"; }

	#Find date and time of model file
	($tyyyy,$tmm,$tdd,$tHH,$tMN,$tSS) = Add_Delta_DHMS($YYYY,$MM,$DD,
							$HH,"00","00","00",$FHR,"00","00");
	if (length("$tHH") != 2) { $tHH="0$tHH"; }
	if (length("$tdd") != 2) { $tdd="0$tdd"; }
	if (length("$tmm") != 2) { $tmm="0$tmm"; }

	#Model file date/time string
	$mTime = "$tyyyy-$tmm-$tdd"."_$tHH:00:00";

	my $time = localtime;
	print "$time\t$mTime\n";

	#Download File
	if ($DOWNLOAD) {
		#URL for directory where model grids will be found
		$url = "http://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.$gfsday"."/$initHH";

		#Model grid file names (on server and renamed for our use).
		$file1 = "gfs.t$HH"."z.pgrb2.0p50.f0$FHR";
		$file2 = "$YYYY$MM$DD$HH"."_0$FHR"."_gfs.grb2";

		$check = 1;
		while ( $check == 1 ) {
			#Try to download index file.
			system("$curl $url/$file1.idx -o $outdir/$file1.idx");

			#If successful, download GRIB2 file.
			if ( -e "$outdir/$file1.idx" ) {
				sleep (2);
				unlink "$outdir/$file1.idx";
				my $returnCode = system("cd $outdir; $curl $url/$file1 -o $outdir/$file2");
				if ( $returnCode != 0 )	{
					my $time = localtime;
					print "$time\t\tFailed Download!\n"
				}
				else {
					my $time = localtime;
					print "$time\t\tDOWNLOADED!\n";
					$check = 0;
				}
			}
			#If data is not yet available, wait one minute and check again.
			else {
				my $time = localtime;
				print "$time\t\tWaiting...\n";
				sleep(60);
			}
		}
	}
   }


	#Ungrib File
	if ($UNGRIB) {
		my $interval_seconds = $ENV{INTERVAL_SECONDS};
		#Create namelist.wps
		&namelistWPS($sTime,$eTime,$max_dom,$interval_seconds,$outdir);

		#Set up directory for ungrib
#		symlink "$dirWPS/ungrib/src/ungrib.exe","$outdir/ungrib.exe";
		symlink "$dirWPS/ungrib/Variable_Tables/$vtable","$outdir/Vtable";
		symlink "$dirWPS/link_grib.csh","$outdir/link_grib.csh";

		my $yyyy	= substr($sTime,0,4);
		my $mm		= substr($sTime,5,2);
		my $dd		= substr($sTime,8,2);
		my $HH		= substr($sTime,11,2);
		my $starttime 	= $yyyy.$mm.$dd.$HH;
		$runlength	= $ENV{RUNLENGTH};
		$interval	= $ENV{INTERVAL};

		$gribfiles = "";
		for ($FHR = 0; $FHR <= $runlength; $FHR+=$interval) {
			if (length("$FHR") != 2) { $FHR="0$FHR"; }
			$gribfile = $outdir.'/'.$starttime.'_0'.$FHR.'_gfs.grb2';
			print "$gribfile\n";
			$gribfiles = $gribfiles.' '.$gribfile;

		}

		#Run link_grib.csh
		system ("cd $outdir; $outdir/link_grib.csh $gribfiles");

		#Run ungrib.exe
		system ("cd $outdir; $outdir/ungrib.exe >/dev/null 2>&1");#

		for ($FHR = 0; $FHR <= $runlength; $FHR+=$interval) {
			#Find date and time of model file
			($sTime,$mTime) = getTimeStrings($starttime,$FHR);
			$mTime = substr($mTime,0,13);
			if ( -e "$outdir/FILE:$mTime" ) {
				my $time = localtime;
				print "$time\t\tFILE:$mTime\n";
			}
			else {
				my $time = localtime;
				print "$time\t\tFailed: FILE:$mTime\n";
				exit;
			}
		}

		#Clean up directory.
#		unlink "$outdir/ungrib.exe";
#		unlink "$outdir/Vtable";
#		unlink "$outdir/ungrib.log";
#		unlink "$outdir/namelist.wps";
		unlink "$outdir/link_grib.csh";
		unlink "$outdir/GRIBFILE.*";
	}

	#METGRID
	if ($METGRID) {

		my $interval_seconds = $ENV{INTERVAL_SECONDS};
		#Create namelist.wps
		&namelistWPS($sTime,$eTime,$max_dom,$interval_seconds,$outdir);

		#Set up directory for metgrid
		symlink "$dirWPS/metgrid/src/metgrid.exe","$outdir/metgrid.exe";
		symlink "$dirWPS/metgrid/METGRID.TBL","$outdir/METGRID.TBL";

		#Create PBS script and run metgrid
		my $pbs_func = "metgrid";
		my $type_q = "shortq";
		&make_pbs_script($pbs_func,$type_q);

		system ("cd ${outdir}; METGRID_ID=`qsub run_${pbs_func}.pbs`");
		$METGRID_ID = $ENV{METGRID_ID};

		#Check to see if metgrid completed. If not, exit.
		my $maxdom 	= $ENV{MAX_DOM};
		my $runlength	= $ENV{RUNLENGTH};
		my $int 	= $ENV{INTERVAL};
		my $num_met_files = (((${runlength}/${int})*(${maxdom}))+${maxdom})-1;
		print "$num_met_files\n";
		my $count_met = 0;
		while(1) {
			my @metfiles = <${outdir}/met_em.d0*.nc>;
			print "$#metfiles\n";
			if ($#metfiles == $num_met_files) {
				my $time = localtime;
				print "$time\tCompleted METGRID\n\n";
				sleep (4);  #To give the last file time to finish in the background
				last;
			} else {
				sleep(2);
			}
			if ($count_met == 900) {
				my $time = localtime;
				print "$time\tERROR: METGRID Failed.\n\n";
				system ("qdel ${METGRID_ID}");
				exit;
			} else {
				$count_met = $count_met + 1;
			}
		}

		#Clean up directory.
		unlink "$outdir/metgrid.exe";
		#system ("cd $outdir; rm $outdir/metgrid.log.*");
#		unlink "$outdir/namelist.wps";
#		unlink "$outdir/METGRID.TBL";
	}

#}
print "\n";
###############################################################################
###############################################################################
###############################################################################
#REAL.EXE
if ($REAL) {
	my $time = localtime;
	print "$time\tStarting REAL\n";

	#Set namelist.input
	&namelistWRF($YYYY,$MM,$DD,$HH,$eYYYY,$eMM,$eDD,$eHH);

	#Set up directory for real
	symlink "$dirWRFV3/main/real.exe","$outdir/real.exe";
	symlink "$dirWRFV3/run/CAM_ABS_DATA","$outdir/CAM_ABS_DATA";
	symlink "$dirWRFV3/run/CAM_AEROPT_DATA","$outdir/CAM_AEROPT_DATA";
	symlink "$dirWRFV3/run/ETAMPNEW_DATA","$outdir/ETAMPNEW_DATA";
	symlink "$dirWRFV3/run/GENPARM.TBL","$outdir/GENPARM.TBL";
	symlink "$dirWRFV3/run/LANDUSE.TBL","$outdir/LANDUSE.TBL";
	symlink "$dirWRFV3/run/ozone.formatted","$outdir/ozone.formatted";
	symlink "$dirWRFV3/run/ozone_lat.formatted","$outdir/ozone_lat.formatted";
	symlink "$dirWRFV3/run/ozone_plev.formatted","$outdir/ozone_plev.formatted";
	symlink "$dirWRFV3/run/RRTM_DATA","$outdir/RRTM_DATA";
	symlink "$dirWRFV3/run/RRTMG_LW_DATA","$outdir/RRTMG_LW_DATA";
	symlink "$dirWRFV3/run/RRTMG_SW_DATA","$outdir/RRTMG_SW_DATA";
	symlink "$dirWRFV3/run/SOILPARM.TBL","$outdir/SOILPARM.TBL";
	symlink "$dirWRFV3/run/URBPARM.TBL","$outdir/URBPARM.TBL";
	symlink "$dirWRFV3/run/VEGPARM.TBL","$outdir/VEGPARM.TBL";

	#Create PBS script and run real
	my $pbs_func = "real";
	my $type_q = "shortq";
	&make_pbs_script($pbs_func,$type_q);

	system ("cd ${outdir}; REAL_ID=`qsub run_${pbs_func}.pbs`");
	$REAL_ID = $ENV{REAL_ID};

	#Check to see if real completed. If not, exit.
	my $max_dom = $ENV{MAX_DOM};
	my $count_real = 0;
	while(1) {
		if ( -e "$outdir/wrfinput_d0${max_dom}" ) {
			my $time = localtime;
			sleep(4); # Give it time to complete file
			print "$time\tCompleted REAL\n\n";
			last;
		} else {
			sleep 2;
		}
		if ($count_real == 600) {
			my $time = localtime;
			print "$time\tERROR: REAL Failed.\n\n";
#			system ("qdel ${REAL_ID}");
			exit;
		} else {
			$count_real = $count_real + 1;
			#print "$count_real\n";
		}
	}

	#Clean up directory after real
#	unlink "$outdir/real.exe";
	system ("cd $outdir; rm rsl.out.*");
	system ("cd $outdir; rm rsl.error.*");
#	unlink "$outdir/namelist.input";
	unlink "$outdir/CAM_ABS_DATA";
	unlink "$outdir/CAM_AEROPT_DATA";
	unlink "$outdir/ETAMPNEW_DATA";
	unlink "$outdir/GENPARM.TBL";
	unlink "$outdir/LANDUSE.TBL";
	unlink "$outdir/ozone.formatted";
	unlink "$outdir/ozone_lat.formatted";
	unlink "$outdir/ozone_plev.formatted";
	unlink "$outdir/URBPARM.TBL";
	unlink "$outdir/VEGPARM.TBL";
}
###############################################################################
###############################################################################
###############################################################################
if ($WRF) {
	my $time = localtime;
	print "$time\tStarting WRF in background...\n\n";

	#Set namelist.input
	&namelistWRF($YYYY,$MM,$DD,$HH,$eYYYY,$eMM,$eDD,$eHH);

	#Set up directory for wrf.exe
	symlink "$dirWRFV3/main/wrf.exe","$outdir/wrf.exe";
	symlink "$dirWRFV3/run/CAM_ABS_DATA","$outdir/CAM_ABS_DATA";
	symlink "$dirWRFV3/run/CAM_AEROPT_DATA","$outdir/CAM_AEROPT_DATA";
	symlink "$dirWRFV3/run/ETAMPNEW_DATA","$outdir/ETAMPNEW_DATA";
	symlink "$dirWRFV3/run/GENPARM.TBL","$outdir/GENPARM.TBL";
	symlink "$dirWRFV3/run/LANDUSE.TBL","$outdir/LANDUSE.TBL";
	symlink "$dirWRFV3/run/ozone.formatted","$outdir/ozone.formatted";
	symlink "$dirWRFV3/run/ozone_lat.formatted","$outdir/ozone_lat.formatted";
	symlink "$dirWRFV3/run/ozone_plev.formatted","$outdir/ozone_plev.formatted";
	symlink "$dirWRFV3/run/RRTM_DATA","$outdir/RRTM_DATA";
	symlink "$dirWRFV3/run/RRTMG_LW_DATA","$outdir/RRTMG_LW_DATA";
	symlink "$dirWRFV3/run/RRTMG_SW_DATA","$outdir/RRTMG_SW_DATA";
	symlink "$dirWRFV3/run/SOILPARM.TBL","$outdir/SOILPARM.TBL";
	symlink "$dirWRFV3/run/URBPARM.TBL","$outdir/URBPARM.TBL";
	symlink "$dirWRFV3/run/VEGPARM.TBL","$outdir/VEGPARM.TBL";

	#Run WRF in the background
	#Create PBS script and run wrf
	my $pbs_func = "wrf";
	my $type_q = "longq";
	&make_pbs_script($pbs_func,$type_q);

	system ("cd ${outdir}; WRF_ID=`qsub run_${pbs_func}.pbs`");

}
###############################################################################
################################################################################
################################################################################
if ($PYTHON) {

        sleep (10);
        my $time = localtime;
        print "$time\tStart Python\n";

        my $max_dom = 3; #$ENV{MAX_DOM};

	#Make directory for output images
	unless ( -d "$outdir/images" ) { mkdir "$outdir/images"; }

        #Also make directory on itpa
        system('ssh sbuwrf@itpa.somas.stonybrook.edu mkdir /data/web/sbuwrf/'."$day >/dev/null 2>&1");

        #Run perl script that runs Python
        system ("cd /D0/sbuwrf/REALTIME; ./run_python.pl $day $mname");

				# Run python job submission script
				# system ("cd /D0/sbuwrf/pythonscripts/RunNetcdfPythonPlottingJobs.py $day");

        #Start each python script. Each one contains a FHR loop that waits until file is finished
        #Doing it this way allows python to draw the map and colorbar axes once instead of each FHR
        #which saves a significant amount of time.
        #
        #The $dom arg is theoretically redundant, but I've kept it for now anyway.
#	for ($dom = 1; $dom <= $max_dom; $dom++) {
#                system ("python3.5 /D0/sbuwrf/pythonscripts/plot_wrf_grb_refl_10cm.py $outdir $dom $day >& /dev/null &");
#                system ("python3.5 /D0/sbuwrf/pythonscripts/plot_wrf_grb_temps_sfc.py $outdir $dom $day >& /dev/null &");
#                system ("python3.5 /D0/sbuwrf/pythonscripts/plot_wrf_grb_pcp.py $outdir $dom $day >& /dev/null &");
#	}
}
###############################################################################
###############################################################################
###############################################################################
if ($UPP) {
	sleep (10);
	my $time = localtime;
	print "$time\tStart UPP\n";

	my $max_dom = $ENV{MAX_DOM};
        my $UPP_script_dir = "/D0/sbuwrf/REALTIME/WRFv3.7.1/WRFV3/UPPV3.1/scripts";

        #Set up parm, wrfprd, and postprd directories as needed for UPP.
        system ("cd $outdir; mkdir $outdir/parm");
        system ("cp /D0/sbuwrf/REALTIME/WRFv3.7.1/WRFV3/UPPV3.1/parm/wrf_cntrl.parm $outdir/parm/.");
        system ("cd $outdir; mkdir $outdir/wrfprd");
        system ("cd $outdir; mkdir $outdir/postprd");

	#For each output hour...
	for ($FHR = 0; $FHR <= $runlength; $FHR+=1) {
		$hour = $FHR;
		if ($FHR <= 9) { $FHR="0$FHR"; }

		#Find date and time of forecast hour
		($tyyyy,$tmm,$tdd,$tHH,$tMN,$tSS) = Add_Delta_DHMS($YYYY,$MM,$DD,$HH,"00","00","00",$FHR,"00","00");
		if (length("$tHH") != 2) { $tHH="0$tHH"; }
		if (length("$tdd") != 2) { $tdd="0$tdd"; }
		if (length("$tmm") != 2) { $tmm="0$tmm"; }

		#For each model domain...
		my $crash = 0;	#If wrf crashes...
		for ($dom = 1; $dom <= $max_dom; $dom++) {
			$domain = $dom;
			if ($domain <= 9) { $domain="0$domain"; }

			#Name of wrfout file.
			$wrfout = "wrfout_d$domain"."_$tyyyy-$tmm-$tdd"."_$tHH:00:00";
                        $UPP_out = "$outdir/postprd/WRFPRS_d$domain.$FHR";

			my $time = localtime;
			print "$time\t\t$wrfout...\n";

			#Check to see if wrfout file is available. If so, ripdp and rip. If not, wait and check again.
			$check = 0;
			while ($check == 0) {

				#If wrfout file is available...
				if ( -e "$outdir/$wrfout" ) {
					my $time = localtime;
					print "$time\t\t\t...FOUND!\n";

					#Wait for wrf.exe to finish writing wrfout file.
					$check2 = 0;
					while ($check2 == 0) {
						$filesize1 = -s "$outdir/$wrfout";
						sleep (2);
						$filesize2 = -s "$outdir/$wrfout";
						if ($filesize1 == $filesize2) { $check2 = 1; }
					}

                                        #Move completed wrfout to wrfprd directory.
                                        system ("cd $outdir; cp $wrfout $outdir/wrfprd/.");

					#Execute UPP.
					system ("cd $UPP_script_dir; $UPP_script_dir/run_unipost_ryan $outdir $sTime_unformatted $FHR d$domain");

					#Check to see if UPP ran succesfully.
					if ( -s "$UPP_out" ) {
						my $time = localtime;
						print "$time\t\t\t$UPP_out\n";
					}
					else {
						my $time = localtime;
						print "$time\t\t\tFAILED: $UPP_out\n";
					}
					$check = 1;
				}
				#If wrfout file is not available, wait and check again.
				else {
					if ($crash >= 300) {
						my $time = localtime;
						print "$time\t\tWRF CRASHED! EXITING.\n";
						exit; }
					$crash = $crash + 1;
					sleep (3);
				}
			}
			#Temporarily put this here til all RIP imgs are replaced with Python
			#Have to do this because Python can't output as .gif but website php code requires .gifs
			#and I don't know how to make the webssite php have a mix of both

# Currently being done in Python script!

#        		system ("mv $outdir/images/NAM.refl_10cm.d$domain.$FHR.png $outdir/images/NAM.refl_10cm.d$domain.$FHR.gif");
#        		system ("mv $outdir/images/NAM.temps_sfc.d$domain.$FHR.png $outdir/images/NAM.temps_sfc.d$domain.$FHR.gif");
		}
	}
	#Copy these new Python images for that model hour to dendrite

# Currently being done in Python script!

#	system("scp $outdir/images/*refl_10cm* sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");
#	system("scp $outdir/images/*temps_sfc* sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");
#	if ($hour < 10) {
#		system("scp $outdir/images/*refl_10cm*.$hour.gif sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");
#	}
}
###############################################################################
###############################################################################
###############################################################################
if ($RIP) {
	sleep (10);
	my $time = localtime;
	print "$time\tStart RIP\n";

	my $max_dom = $ENV{MAX_DOM};

	#Make directories for ripdp files and output images
	unless ( -d "$outdir/ripdp" ) { mkdir "$outdir/ripdp"; }
	unless ( -d "$outdir/images" ) { mkdir "$outdir/images"; }

	#Make output directory on dendrite
	#system('ssh sbuwrf@dendrite.somas.stonybrook.edu mkdir /home/sbuwrf/LI_WRF/'."$day");
	system('ssh sbuwrf@itpa.somas.stonybrook.edu mkdir /data/web/sbuwrf/'."$day >/dev/null 2>&1");

	#Set up directory for ripdp and rip
	symlink "$dirRIP4/eta_micro_lookup.dat","$outdir/eta_micro_lookup.dat";
	symlink "$dirRIP4/psadilookup.dat","$outdir/psadilookup.dat";
	symlink "$dirRIP4/stationlist","$outdir/stationlist";
	symlink "$dirRIP4/ripdp_wrfarw","$outdir/ripdp_wrfarw";
	symlink "$dirRIP4/rip","$outdir/rip";

	#For each output hour...
	for ($FHR = 0; $FHR <= $runlength; $FHR+=1) {
		$hour = $FHR;
		if ($FHR <= 9) { $FHR="0$FHR"; }

		#Find date and time of forecast hour
		($tyyyy,$tmm,$tdd,$tHH,$tMN,$tSS) = Add_Delta_DHMS($YYYY,$MM,$DD,$HH,"00","00","00",$FHR,"00","00");
		if (length("$tHH") != 2) { $tHH="0$tHH"; }
		if (length("$tdd") != 2) { $tdd="0$tdd"; }
		if (length("$tmm") != 2) { $tmm="0$tmm"; }

		#For each model domain...
		my $crash = 0;	#If wrf crashes...
		for ($dom = 1; $dom <= $max_dom; $dom++) {
			$domain = $dom;
			if ($domain <= 9) { $domain="0$domain"; }

			#Name of wrfout file.
			$wrfout = "wrfout_d$domain"."_$tyyyy-$tmm-$tdd"."_$tHH:00:00";

			my $time = localtime;
			print "$time\t\t$wrfout...\n";

			#Check to see if wrfout file is available. If so, ripdp and rip. If not, wait and check again.
			$check = 0;
			while ($check == 0) {

				#If wrfout file is available...
				if ( -e "$outdir/$wrfout" ) {
					my $time = localtime;
					print "$time\t\t\t...FOUND!\n";

					#Wait for wrf.exe to finish writing wrfout file.
					$check2 = 0;
					while ($check2 == 0) {
						$filesize1 = -s "$outdir/$wrfout";
						sleep (2);
						$filesize2 = -s "$outdir/$wrfout";
						if ($filesize1 == $filesize2) { $check2 = 1; }
					}

					#Execute ripdp
					@riphours = (0,1,3,24);
					for ($b=0;$b<=3;$b++) {
						$riphour = $hour - $riphours[$b];
						if (length($riphour) < 2) { $riphour="0$riphour"; }
						($ryyyy,$rmm,$rdd,$rHH,$rMN,$rSS) = Add_Delta_DHMS($YYYY,$MM,$DD,$HH,"00","00","00",$riphour,"00","00");
						if (length("$rHH") != 2) { $rHH="0$rHH"; }
						if (length("$rdd") != 2) { $rdd="0$rdd"; }
						if (length("$rmm") != 2) { $rmm="0$rmm"; }
						if ($riphour >= 0) {
							$ripdp[$b] = "wrfout_d$domain"."_$ryyyy-$rmm-$rdd"."_$rHH:00:00";
							$ripdp_func[$b] = $outdir."/".$ripdp[$b];
						} else {
							$ripdp[$b] = "wrfout_d$domain"."_$ryyyy-$rmm-$rdd"."_$rHH:00:00";
							$ripdp_func[$b] = "";
						}
						print "$riphour\t$ripdp[$b]\n";
					}

					#Execute ripdp on wrfout file.
					#system ("cd $outdir; $outdir/ripdp_wrfarw $outdir/ripdp/wrfout_d$domain"."_$FHR all $outdir/${ripdp[0]} $outdir/${ripdp[1]} $outdir/${ripdp[2]} $outdir/${ripdp[3]}"); #  >/dev/null 2>&1
					system ("cd $outdir; $outdir/ripdp_wrfarw $outdir/ripdp/wrfout_d$domain"."_$FHR all ${ripdp_func[0]} ${ripdp_func[1]} ${ripdp_func[2]} ${ripdp_func[3]} >/dev/null 2>&1"); #

					#Create RIP infile for model time.
					open (IN,"<$infiles/NEWoperational_d$domain".".in");
					my(@indata) = ();
					chomp(@indata=<IN>);
					close IN;
					open (OUT,">$outdir/images/operational_d$domain"."_$FHR.in");
					for ($i=0;$i<=$#indata;$i++) {
						$indata[$i] =~ s/#mname#/$mname/g;
						$indata[$i] =~ s/#domain#/$domain/g;
						$indata[$i] =~ s/#hour#/$hour/g;
						print OUT ("$indata[$i]\n");
					}
					close OUT;

					#Run RIP on wrfout file using current infile
					system ("cd $outdir; $outdir/rip $outdir/ripdp/wrfout_d$domain"."_$FHR $outdir/images/operational_d$domain"."_$FHR.in >/dev/null 2>&1");
					system ("cd $outdir/images; med -e ".'\'1,$ split $ operational_d'."$domain"."_f$FHR".'\''." $outdir/images/operational_d$domain"."_$FHR.cgm");
					unlink "$outdir/images/operational_d$domain"."_$FHR.in";
					unlink "$outdir/images/operational_d$domain"."_$FHR.cgm";
					system ("rm $outdir/ripdp/wrfout_d$domain"."_$FHR*");

					#For each RIP infile...
					for ($v=0;$v<=$#ripins;$v++) {

						#Format image number
						$img = $v + 1;
						if (length("$img") == 1) { $img="00$img"; }
						if (length("$img") == 2) { $img="0$img"; }
						if (length("$img") == 3) { $img="$img"; }

						#Name of image...
						my $rip_file = "$mname.${ripins[$v]}".".d$domain".".$FHR".".gif";

						#Convert NCGM to GIF
						#system ("cd $outdir/images; bpsh $node $ctrans $outdir/images/operational_d$domain"."_f$FHR"."$img.ncgm | $xwdtopnm 2>/dev/null | $ppmtogif > $outdir/images/$rip_file 2>/dev/null");
						system ("cd $outdir/images; $ctrans $outdir/images/operational_d$domain"."_f$FHR"."$img.ncgm | $xwdtopnm 2>/dev/null | $ppmtogif > $outdir/images/$rip_file 2>/dev/null");

						#Hide the evidence
						unlink "$outdir/images/operational_d$domain"."_f$FHR"."$img.ncgm";

						#Check to see if GIF was created
						if ( -s "$outdir/images/$rip_file" ) {
							my $time	= localtime;
							print "$time\t\t\t$rip_file\n";
							if ($hour < 10) {
								copy "$outdir/images/$rip_file", "$outdir/images/$mname.${ripins[$v]}".".d$domain".".$hour.gif";
							}
						}
						else {
							my $time = localtime;
							print "$time\t\t\tFAILED: $rip_file\n";
						}
					}
					$check = 1;
				}
				#If wrfout file is not available, wait and check again.
				else {
					if ($crash >= 300) {
						my $time = localtime;
						print "$time\t\tWRF CRASHED! EXITING.\n";
						exit; }
					$crash = $crash + 1;
					sleep (3);
				}
			}
		}

	#Copy RIP images for that model hour to dendrite
	#system("scp $outdir/images/*.$FHR.gif sbuwrf".'@dendrite.somas.stonybrook.edu:/home/sbuwrf/LI_WRF/'."$day/ >/dev/null 2>&1");
	system("scp $outdir/images/*.$FHR.gif sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");
	if ($hour < 10) {
		#system("scp $outdir/images/*.$hour.gif sbuwrf".'@dendrite.somas.stonybrook.edu:/home/sbuwrf/LI_WRF/'."$day/ >/dev/null 2>&1");
		system("scp $outdir/images/*.$hour.gif sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");
	}


	}

	my $time = localtime;
	print "$time\tCompleted RIP\n\n";

	#Hide the evidence
	unlink "$outdir/eta_micro_lookup.dat";
	unlink "$outdir/psadilookup.dat";
	unlink "$outdir/stationlist";
	unlink "$outdir/ripdp_wrfarw";
	unlink "$outdir/rip";

#Copy all RIP images over, for good measure
#system("scp $outdir/images/*.gif sbuwrf".'@dendrite.somas.stonybrook.edu:/home/sbuwrf/LI_WRF/'."$day/ >/dev/null 2>&1");
system("scp $outdir/images/*.gif sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");

}
###############################################################################
###############################################################################
###############################################################################
#Use NCL to plot Time Series
if ($NCL) {

	@nclstns =	("ALB",	"BDL",	"BDR",	"BOS",	"CHH",	"EWR",	"ISP",	"JFK",	"MTP",	"NYC",	"OKX",	"PVD",	"SBU");

	for ($dom = 1; $dom <= $max_dom; $dom++) {
		$domain = $dom;
		if ($domain <= 9) { $domain="0$domain"; }

		#Combine all files into one netCDF file.
		#system("cd $outdir; ncrcat -h $outdir/wrfout_d$domain* $outdir/wrfout_d$domain.nc");

		#Link NCL script.
		symlink "$infiles/ncl_timeseries_gfs.ncl","$outdir/ncl_timeseries_gfs.ncl";

		#Set environmental variable and run NCL script.
		system("cd $outdir; export wrf_dir=$outdir >/dev/null 2>&1; export wrf_dom=$domain >/dev/null 2>&1; ncl ncl_timeseries_gfs.ncl >/dev/null 2>&1");

		#Hide the evidence.
		#unlink "$outdir/wrfout_d$domain.nc";
		unlink "$outdir/ncl_timeseries_gfs.ncl";
		system("cd $outdir; mv *.png $outdir/images/ >/dev/null 2>&1");

		for ($s=0;$s<=$#nclstns;$s++) {
			system("cd $outdir; convert -trim $outdir/images/GFS_${nclstns[$s]}.000001.png $outdir/images/GFS_${nclstns[$s]}.000001.png");
			system("cd $outdir; convert -trim $outdir/images/GFS_${nclstns[$s]}.000002.png $outdir/images/GFS_${nclstns[$s]}.000002.png");
			system("cd $outdir; convert -trim $outdir/images/GFS_${nclstns[$s]}.000003.png $outdir/images/GFS_${nclstns[$s]}.000003.png");
			system("cd $outdir; convert -trim $outdir/images/GFS_${nclstns[$s]}.000004.png $outdir/images/GFS_${nclstns[$s]}.000004.png");
			rename "$outdir/images/GFS_${nclstns[$s]}.000001.png","$outdir/images/GFS_${nclstns[$s]}_tmp_d$domain.png";
			rename "$outdir/images/GFS_${nclstns[$s]}.000002.png","$outdir/images/GFS_${nclstns[$s]}_prs_d$domain.png";
			rename "$outdir/images/GFS_${nclstns[$s]}.000003.png","$outdir/images/GFS_${nclstns[$s]}_pcp_d$domain.png";
			rename "$outdir/images/GFS_${nclstns[$s]}.000004.png","$outdir/images/GFS_${nclstns[$s]}_wsp_d$domain.png";
		}

		#Copy all PNG images over
		system("scp $outdir/images/*.png sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'."$day/ >/dev/null 2>&1");

	}

}
###############################################################################
###############################################################################
###############################################################################
#Create Front-page Loop
if ($FRONTPAGELOOP) {
        my $filelist = "GFS.refl_10cm.d02.00.gif";
        foreach my $i (0..84) {
            $filelist = $filelist ." GFS.refl_10cm.d02." . (sprintf "%02d", $i) . ".gif";
        }
        #print $filelist;
	system ("cd $outdir/images/; convert -delay 16.8 -loop 0 " .$filelist. " front_page_loop.gif");
	#system("scp $outdir/images/front_page_loop.gif sbuwrf".'@dendrite.somas.stonybrook.edu:/home/sbuwrf/LI_WRF/'." >/dev/null 2>&1");
	system("scp $outdir/images/front_page_loop.gif sbuwrf".'@itpa.somas.stonybrook.edu:/data/web/sbuwrf/'." >/dev/null 2>&1");
}
###############################################################################
###############################################################################
###############################################################################
#Clean up after wrf.exe
if ($CLEANUP) {
#	unlink "$outdir/wrf.exe";
	unlink "$outdir/CAM_ABS_DATA";
	unlink "$outdir/CAM_AEROPT_DATA";
	unlink "$outdir/ETAMPNEW_DATA";
	unlink "$outdir/GENPARM.TBL";
	unlink "$outdir/LANDUSE.TBL";
	unlink "$outdir/ozone.formatted";
	unlink "$outdir/ozone_lat.formatted";
	unlink "$outdir/ozone_plev.formatted";
	unlink "$outdir/URBPARM.TBL";
	unlink "$outdir/VEGPARM.TBL";
	#system ("cd $outdir; rm rsl.out.*");
	#system ("cd $outdir; rm rsl.error.*");
#	unlink "$outdir/namelist.input";
}
###############################################################################
###############################################################################
###############################################################################
sub namelistSST {

	my $max_dom		= $ENV{MAX_DOM};
	my $interval_seconds	= $ENV{INTERVAL_SECONDS};
	my $outdir			= $ENV{OUTDIR};
	my $sTime			= @_[0];
	my $eTime			= @_[1];


	#Create start_date and end_date strings that reflect
	#the number of domains
	if ($max_dom > 1) {
		$new_sTime = $sTime;
		$new_eTime = $eTime;
		for ($k=2;$k<=$max_dom;$k++) {
			$new_sTime = join("','",$new_sTime,$sTime);
			$new_eTime = join("','",$new_eTime,$eTime);
		}
		$sTime = $new_sTime;
		$eTime = $new_eTime;
	}

	#Set namelist.wps
	open (OUT,">$outdir/namelist.wps");
	print OUT <<"END";
	&share
	 wrf_core		= 'ARW',
	 max_dom		= $max_dom,
	 start_date		= '$sTime',
	 end_date		= '$eTime',
	 interval_seconds	= $interval_seconds,
	 io_form_geogrid	= 2,
	 debug_level		= 300
	/

	&ungrib
	 out_format		= 'WPS',
	 prefix			= 'SST',
	/

END
	close OUT;
}
###############################################################################
###############################################################################
###############################################################################
###############################################################################
sub namelistWPS {

	my $sTime		= @_[0];
	my $eTime		= @_[1];
	my $max_dom		= @_[2];
	my $interval_secs	= @_[3];
	my $outdir		= @_[4];

	#Create start_date and end_date strings that reflect
	#the number of domains
	if ($max_dom > 1) {
		$new_sTime = $sTime;
		$new_eTime = $eTime;
		for ($k=2;$k<=$max_dom;$k++) {
			$new_sTime = join("','",$new_sTime,$sTime);
			$new_eTime = join("','",$new_eTime,$eTime);
		}
		$sTime = $new_sTime;
		$eTime = $new_eTime;
	}

	#Set namelist.wps
	open (OUT,">$outdir/namelist.wps");
	print OUT <<"END";
	&share
	 wrf_core		= 'ARW',
	 max_dom		= $max_dom,
	 start_date		= '$sTime',
	 end_date		= '$eTime',
	 interval_seconds	= $interval_secs,
	 io_form_geogrid	= 2,
	 debug_level		= 1000
	/

	&geogrid
         parent_id		=   1, 1, 2,
         parent_grid_ratio	=   1, 3, 3,
         i_parent_start		=   1,  53,  77,
         j_parent_start		=   1,  29,  53,
         e_we			= 121, 160, 157,
         e_sn			=  91, 121, 118,
         geog_data_res		= 'default','default','default',
         dx			= 36000,
         dy			= 36000,
         map_proj		= 'lambert',
         ref_lat		=  39.338,
         ref_lon		= -84.000,
         truelat1		=  39.338,
         truelat2 		=  39.338,
         stand_lon		= -84.000,
	 geog_data_path		= '/D0/sbuwrf/REALTIME/WRFv3.9.1/WPS/geogrid/geog'
	 opt_geogrid_tbl_path	= '$outdir/'
	/

	&ungrib
	 out_format		= 'WPS',
	 prefix			= 'FILE',
	/

	&metgrid
	 fg_name		= 'FILE',
         constants_name         = '$sst',
	 io_form_metgrid	= 2,
	 opt_metgrid_tbl_path	= '$outdir/',
	/

END
	close OUT;
}
###############################################################################
###############################################################################
sub namelistWRF {

	my $max_dom		= $ENV{MAX_DOM};
	my $interval_seconds	= $ENV{INTERVAL_SECONDS};
	my $outdir		= $ENV{OUTDIR};
	my $runlength		= $ENV{RUNLENGTH};
	my $sYYYY		= @_[0];
	my $sMM			= @_[1];
	my $sDD			= @_[2];
	my $sHH			= @_[3];
	my $eYYYY		= @_[4];
	my $eMM			= @_[5];
	my $eDD			= @_[6];
	my $eHH			= @_[7];

	my $start_year = $sYYYY;
	my $start_month = $sMM;
	my $start_day = $sDD;
	my $start_hour = $sHH;
	my $end_year = $eYYYY;
	my $end_month = $eMM;
	my $end_day = $eDD;
	my $end_hour = $eHH;
	#Create start_year, end_year, etc. strings that reflect
	#the number of domains
	if ($max_dom > 1) {
		for ($k=2;$k<=$max_dom;$k++) {
			$start_year	= join(", ",$start_year,$sYYYY);
			$start_month	= join(", ",$start_month,$sMM);
			$start_day	= join(", ",$start_day,$sDD);
			$start_hour	= join(", ",$start_hour,$sHH);
			$end_year	= join(", ",$end_year,$eYYYY);
			$end_month	= join(", ",$end_month,$eMM);
			$end_day	= join(", ",$end_day,$eDD);
			$end_hour	= join(", ",$end_hour,$eHH);
		}
	}

	#Set namelist.input
	open (OUT,">$outdir/namelist.input");
	print OUT <<"END";
	&time_control
	 run_days				= 0,
	 run_hours				= $runlength,
	 run_minutes				= 0,
	 run_seconds				= 0,
	 start_year				= $start_year,
	 start_month				= $start_month,
	 start_day				= $start_day,
	 start_hour				= $start_hour,
	 start_minute				= 00,   00,   00,
	 start_second				= 00,   00,   00,
	 end_year				= $end_year,
	 end_month				= $end_month,
	 end_day				= $end_day,
	 end_hour				= $end_hour,
	 end_minute				= 00,   00,   00,
	 end_second				= 00,   00,   00,
	 interval_seconds			= $interval_seconds,
	 input_from_file			= .true.,.true.,.true.,
	 history_interval			= 60,  60,  60,
	 frames_per_outfile			= 1, 1, 1,
	 restart				= .false.,
	 restart_interval			= 5000,
	 io_form_history			= 2
	 io_form_restart			= 2
	 io_form_input				= 2
	 io_form_boundary			= 2
	 debug_level				= 100
	 adjust_output_times			= .true.,
	/
	&domains
	 time_step 				= 180,
	 time_step_fract_num			= 0,
	 time_step_fract_den			= 1,
	 max_dom				= $max_dom,
         e_we			                = 121, 160, 157,
         e_sn			                =  91, 121, 118,
	 e_vert					= 40,     40,     40,
	 p_top_requested			= 10000,
	 num_metgrid_levels			= 34,
	 num_metgrid_soil_levels		= 4,
	 dx					= 36000, 12000,  4000,
	 dy					= 36000, 12000,  4000,
	 grid_id				=   1,   2,   3,
	 parent_id				=   1,   1,   2,
         i_parent_start		                =   1,  53,  77,
         j_parent_start		                =   1,  29,  53,
	 parent_grid_ratio			=   1,   3,   3,
	 parent_time_step_ratio			= 1,     3,     3,
	 feedback				= 0,
	 smooth_option				= 0,
         use_adaptive_time_step			= .true.,
         step_to_output_time			= .true.,
         target_cfl				= 1.2, 1.2, 1.2,
         target_hcfl				= 0.84, 0.84, 0.84,
         max_step_increase_pct			= 5, 51, 51,
         starting_time_step			= -1, -1, -1,
         max_time_step				= -1, -1, -1,
         min_time_step				= -1, -1, -1,
         adaptation_domain			= 1,
	/
	&physics
	 mp_physics				= 8,     8,     8,
	 ra_lw_physics				= 1,     1,     1,
	 ra_sw_physics				= 4,     4,     4,
	 radt					= 30,   15,     5,
	 sf_sfclay_physics			= 5,     5,     5,
	 sf_surface_physics			= 2,     2,     2,
	 bl_pbl_physics				= 5,     5,     5,
	 bldt					= 0,     0,     0,
	 cu_physics				= 5,     5,     0,
	 cudt					= 0,     0,     0,
         ishallow				= 1,
         isfflx                                 = 1,
         ifsnow                                 = 1,
         icloud                                 = 1,
	 surface_input_source			= 1,
	 num_soil_layers			= 4,
         num_land_cat                           = 21,
	 sf_urban_physics			= 0,     0,     0,
	 maxiens				= 1,
	 maxens					= 3,
	 maxens2				= 3,
	 maxens3				= 16,
	 ensdim					= 144,
	 fractional_seaice			= 0,
	 seaice_threshold			= 100.,
	 do_radar_ref				= 1,
	/
	&fdda
	/
	&dynamics
         rk_ord					= 3,
         diff_6th_opt				= 2,
	 diff_6th_factor			= 0.12,
	 w_damping				= 1,
	 diff_opt				= 1, 1, 1,
	 km_opt					= 4, 4, 4,
         damp_opt				= 3,
	 base_temp				= 290.,
         iso_temp				= 210.,
	 zdamp					= 5000.,  5000.,  5000.,
	 dampcoef				= 0.,    0.,    0.,
	 khdif					= 0,  0,  0,
	 kvdif					= 0,  0,  0,
         smdiv					= 0.1, 0.1, 0.1,
         emdiv					= 0.01, 0.01, 0.01,
         epssm					= 0.1, 0.1, 0.1,
	 non_hydrostatic			= .true., .true., .true.,
         time_step_sound			= 0, 0, 0,
         h_mom_adv_order			= 5, 5, 5,
         v_mom_adv_order			= 3, 3, 3,
         h_sca_adv_order			= 5, 5, 5,
         v_sca_adv_order			= 3, 3, 3,
	 moist_adv_opt				= 1, 1, 1,
	 scalar_adv_opt				= 1, 1, 1,
	/

	&bdy_control
	 spec_bdy_width				= 5,
	 spec_zone				= 1,
	 relax_zone				= 4,
	 specified				= .true., .false., .false.,
	 nested					= .false., .true., .true.,
	/
	&grib2
	/
	&namelist_quilt
	 nio_tasks_per_group			= 0,
	 nio_groups				= 1,
	/
END
	close OUT;
}
###############################################################################
# Gets end times of WRF run

sub getTimeStrings {
	my $starttime	= @_[0];
	my $fhr		= @_[1];
	my $yyyy	= substr($starttime,0,4);
	my $mm		= substr($starttime,4,2);
	my $dd		= substr($starttime,6,2);
	my $HH		= substr($starttime,8,2);
	$sTime		= "$yyyy-$mm-$dd"."_$HH:00:00";
	print "$starttime\t$sTime\n";
	($tyyyy,$tmm,$tdd,$tHH,$tMN,$tSS) = Add_Delta_DHMS($yyyy,$mm,$dd,$HH,"00","00","00",$fhr,"00","00");
	if (length("$tmm") != 2) { $tmm="0$tmm"; }
	if (length("$tHH") != 2) { $tHH="0$tHH"; }
	if (length("$tdd") != 2) { $tdd="0$tdd"; }
	$eTime		= "$tyyyy-$tmm-$tdd"."_$tHH:00:00";
	return ($sTime,$eTime);
}

###############################################################################
sub make_pbs_script {

	my $pbs_func		= @_[0];
	my $type_q		= @_[1];
	my $outdir		= $ENV{OUTDIR};
	my $node 		= $ENV{NODE};	#Number of nodes to use
	my $nproc		= $ENV{NPROC};	#Number of processors


	#Write job submission script for process
	open (OUT,">$outdir/run_${pbs_func}.pbs");
	print OUT <<"END";
#!/bin/bash
#PBS -l nodes=${node}:ppn=${nproc}
#PBS -N run_${pbs_func}
#PBS -q ${type_q}

cd ${outdir}

/cm/shared/apps/intel/compilers_and_libraries/2016.4.258/mpi/intel64/bin/mpirun ${outdir}/${pbs_func}.exe

END
	close OUT;
}
###############################################################################
