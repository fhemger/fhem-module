##########################################
#
# Copyright 2019 by fhemger
# 
# beta version
#
#
# uses SubProcess.pm
#
# LaCrosse before 21.09.2019:
#   Damit 36_LaCrosse.pm die 4-stelligen IDs der 30.3180.IT Sensoren akzeptiert, ist darin folgende Änderung erforderlich (Zeile 47).
#
#   Line 47: $a[2] =~ m/^([\da-f]{2,4})$/i;
# 
#
# udev rule Zugriff des fhem Benutzers auf den USB Stick
# replace xxxx, yyyy by your rtl-sdr usb stick VID and PID
# /etc/udev/rules.d/rtl-sdr.rules
# SUBSYSTEMS=="usb", ATTRS{idVendor}=="xxxx", ATTRS{idProduct}=="yyyy", MODE:="0666"
##service udev restart
#
# Erweitert LaCrosse AutoCreate GPLOT und ATTR
#
#
# Change Log
#
# 24.09.2019 Inital release
#
#
# TODO
#	- "disable:1,0 disabledForIntervals "
#	- cleanup, optimize, simplify
#

package main;
use strict;
use warnings;
use SubProcess;
use Data::Dumper;

sub tfrec_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}			= 'tfrec_Define';
    $hash->{UndefFn}		= 'tfrec_Undef';
	$hash->{ReadFn}			= 'tfrec_Read';
    $hash->{SetFn}			= 'tfrec_Set';
    $hash->{AttrFn}			= 'tfrec_Attr';
	$hash->{FingerprintFn}	= 'tfrec_Fingerprint';
	$hash->{NotifyFn}		= 'tfrec_Notify';

    $hash->{AttrList} = "LaCrossePair:0,1,2 "
					."disable:1,0 disabledForIntervals "
					."tfrec_cmd tfrec_args tfrec_interval tfrec_timeout tfrec_debug:off,on tfrec_debug_log "
					.$readingFnAttributes;
					
	#$hash->{AutoCreate} = { "wolf_ism8.*" => {} };
}

sub tfrec_Define($$) {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    
    if(int(@param) < 2) {
        return "too few parameters: define <name> 36_tfrec";
    }
    	
	my $name = $param[0];
    $hash->{NAME}  = $name;
	
	#$hash->{NOTIFYDEV} = "global,.*\.cmdtfrec";
	
	# see 36_JeeLink.pm
	$hash->{Clients} = "LaCrosse";
	$hash->{MatchList} = { "1:LaCrosse" => "^(\\S+\\s+9 |OK\\sWS\\s)" };

	# need for LaCrosse autocreate
	$hash->{LaCrossePair} = 2;
	
	# defaults
	$attr{$name}{tfrec_cmd} = "/usr/bin/tfrec";
	$attr{$name}{tfrec_args} = "-T 1 -q";
	$attr{$name}{tfrec_debug} = "off";
	$attr{$name}{tfrec_interval} = 60;
	$attr{$name}{tfrec_timeout} = 15;
	
	# add GPLOT and ATTR to LaCrosse AutoCreate
	if(LoadModule("LaCrosse")) {
		if(!defined($modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{GPLOT}) || $modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{GPLOT} !~ /temp4hum4:Temp\/Hum,/) {
			$modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{GPLOT} .= "temp4hum4:Temp/Hum,";
		}
		
		if(!defined($modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{ATTR}) || $modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{ATTR} !~ /event-on-change-reading:/) {
			$modules{LaCrosse}->{AutoCreate}->{"LaCrosse.*"}->{ATTR} .= "event-on-change-reading:.* ";
		}
	}
	
	tfrec_SubProcessCmd($hash, "create");
	
	if($init_done) {
		tfrec_SubProcessInterval($hash);
	} #else see Notify for subprocess start
		
	return; # undef on success
} #Define

sub tfrec_SubProcessInterval {
	my $hash = $_[0];
	my $name = $hash->{NAME};

	return if(IsDisabled($name));
	
	RemoveInternalTimer($hash, "tfrec_SubProcessInterval");
	if(defined($hash->{subprocess})) {
		if(defined($hash->{subprocess}->{pid})) {
			if(!tfrec_CheckPid($hash, $hash->{subprocess}->{pid})) { #$hash->{subprocess}->running()
				
				tfrec_SubProcessCmd($hash, "run");
			} else {
				Log3 $name, 4, "$name Subprocess ".$hash->{subprocess}->{NAME}." already running, setting new timer";
			}
		} else {
			# first run
			tfrec_SubProcessCmd($hash, "run");
		}
		
		# set timer
		if( AttrVal($name, "tfrec_interval", 0) > 0) {
			my $next = gettimeofday() + AttrVal($name, "tfrec_interval", 60);
			InternalTimer($next , "tfrec_SubProcessInterval", $hash);
			readingsSingleUpdate($hash, "tfrec_next", localtime($next), 0);
		} else {
			readingsSingleUpdate($hash, "tfrec_next", "-disabled-", 0);
		}
	} else {
		tfrec_SubProcessCmd($hash, "terminate");
		readingsSingleUpdate($hash, "tfrec_next", "-error-", 0);
	}
} #SubProcessInterval

sub tfrec_SubProcessCmd($$) {
	my $hash = $_[0];
	my $cmd = $_[1];
	
	my $name = $hash->{NAME};
	return if(IsDisabled($name));
	
	Log3 $name, 5, "$name SubProcess cmd \"$cmd\"";
	
	if($cmd eq "create") {
		return if(defined($hash->{subprocess}));
		
		my $subprocess = SubProcess->new( { onRun => \&tfrec_OnRun }); #, onExit => \&tfrec_OnExit });
		#$subprocess->{timeout} = AttrVal($name, "tfrec_timeout", 70) + 10;
		$subprocess->{PARENTNAME} = $name;
		$subprocess->{verbose} = AttrVal( $name, 'verbose', 0 );
		$subprocess->{NAME} = "$name.cmdtfrec";
		$subprocess->{errorcount} = 0;
	
		$hash->{FH} = $subprocess->{child};
		$hash->{FD} = fileno($subprocess->{child});
		
		$hash->{subprocess} = $subprocess;
		
		return;
	}
	
	return if(!defined($hash->{subprocess}));
	
	my $subprocess = $hash->{subprocess};
	
	if($cmd eq "run") {
		# if running
		return if(defined($subprocess->{pid}) && tfrec_CheckPid($subprocess, $subprocess->{pid})); # $subprocess->running());
		$hash->{subprocess}->{errorcount} = 0;
		$hash->{PID} = $subprocess->run();
		$selectlist{$subprocess->{NAME}} = $hash;
	} elsif($cmd eq "terminate") {
		$subprocess->terminate();
		Log3 $name, 5, "$name Subprocess terminate";
	} elsif($cmd eq "wait") {
		$subprocess->wait();
	} elsif($cmd eq "kill") {
		RemoveInternalTimer($hash, "tfrec_SubProcessInterval");
		if(tfrec_KillPid($hash->{subprocess}, $hash->{subprocess}->{tfrec_pid})) {
			readingsSingleUpdate($hash, "tfrec_pid", "killed", 0);
			$subprocess->kill();
			InternalTimer(gettimeofday() + 2, "tfrec_killcheck", $hash);
		} else {
			Log3 $name, 1, "$name ".$subprocess->{NAME}." SubProcess Cmd Kill failed!";
		}
	} elsif($cmd eq "Intervaldisable") {
		RemoveInternalTimer($hash, "tfrec_SubProcessInterval");
		readingsSingleUpdate($hash, "tfrec_next", "-disabled-", 0);
	} elsif($cmd eq "check") {
		if(tfrec_CheckPid($subprocess, $subprocess->{pid})) { #$subprocess->running()) {
			if(tfrec_CheckPid($subprocess, $subprocess->{tfrec_pid})) {
				readingsSingleUpdate($hash, "state", "running", 0)
			} else {
				readingsSingleUpdate($hash, "state", "tfrec not running", 0)
			}
		} else {
			readingsSingleUpdate($hash, "state", "SubProcess failed", 0)
		}
	} elsif ($cmd eq "cleanup") {
		undef($selectlist{$subprocess->{NAME}});
		undef($hash->{PID});
	}
} #SubProcessCmd

sub tfrec_killcheck {
	my $hash = $_[0];
	my $subprocess = $hash->{subprocess};
	
	if(!tfrec_CheckPid($subprocess, $subprocess->{pid})) { #$subprocess->running()) {
		tfrec_SubProcessCmd($hash, "cleanup");
		readingsSingleUpdate($hash, "state", "not running (killed)", 0)
	}
	
	RemoveInternalTimer($hash, "tfrec_killcheck");
} #killcheck

# Read from subprocess
sub tfrec_Read {
	my $hash = $_[0];
	my $name = $hash->{NAME};
	
	my $data = $hash->{subprocess}->readFromChild();
	
	chomp($data);
	
	#type:msg
	my ($type, $msg) = split(/:/, $data, 2);
	
	Log3 $name, 5, "$name Recieved from Subprocess \"$data\"";
	
	if($type eq "OUTPUT") {
		# on debug ?
		readingsSingleUpdate($hash, "tfrec_last", $msg, 0) if(AttrVal($name, "tfrec_debug", "off") eq "on");
		
		if($msg =~ /^TFA/) {
			#TFA1 ID 0140 +28.4 48% seq 1 lowbat 0 RSSI 73
			my ($type, $id, $temp, $hum, $seqnum, $lowbat, $rssi) = $msg =~ /(TFA\d+)\s+ID\s+(\S+)\s+(\S+)\s+(\S+)%\s+seq\s+(\S+)\s+lowbat\s+(\S+)\s+RSSI\s+(\S+)/;
			
			if($id eq "BAD") {
				Log3 $name, 5, "$name BAD: $msg";
				return;
			}
			
			my $parsestr = "$id $temp $hum $seqnum $lowbat $rssi 0 ".time();
		
			tfrec_Parse($hash, $parsestr);
			# TODO Update reading tcfrec output & STATE
			return;
		} elsif ($msg =~ /RET OPEN (\S+), retry/) {
			my $text = $1;
			$hash->{subprocess}->{errorcount}++;
			if($1 == -1) { $text = "No Device found"; }
			elsif ($1 == -3) { $text = "Check device permissions"; }
			# tfrec error
			Log3 $name, 1, "$name RET OPEN $1, retry ($text)";
			#$hash->{subprocess}->writeToChild("Sleep");
			# Stop tfrec
			# TODO Update reading tcfrec output & STATE
			
			readingsSingleUpdate($hash, "tfrec_error", $msg, 0);
			readingsSingleUpdate($hash, "state", $msg, 0);
			
			if($hash->{subprocess}->{errorcount} > 5) {
				Log3 $name, 1, "$name Terminating tfrec, too many errors";
				$hash->{subprocess}->terminate(); # keep timer active
				#tfrec_SubProcessCmd($hash, "cleanup");
			}
			
			return;
		} elsif ($msg =~ /^Found (.*)/) {
			$hash->{subprocess}->{errorcount} = 0;
			Log3 $name, 4, "$name Device found: $1";
			readingsSingleUpdate($hash, "tfrec_device", $1, 0);
			readingsSingleUpdate($hash, "tfrec_error", '', 0);
			return;	
		} elsif ($msg =~ /^Detach|Registering|Dumpmode|AUTO|Samplerate|START/) {
			$hash->{subprocess}->{errorcount} = 0;
			Log3 $name, 5, "$name Init: $msg";
			return;
		} elsif ($msg =~ /^#/) {
			Log3 $name, 5, "$name Invalid: $msg";
			return;
		}
		
		Log3 $name, 5, "$name Unknown tfrec output";
		
	} elsif($type eq "FHEM") {
		my ($cmd, $name, $value) = split(/ /, $msg, 3);
		if ($cmd eq "reading") {
			Log3 $name, 5, "$name FHEM Set Reading: $name Value: $value";
			readingsSingleUpdate($hash, $name, $value, 0);
			
			$hash->{subprocess}->{$name} = $value if($name eq "tfrec_pid");
			return;
		} elsif ($cmd eq "subprocess") {
			Log3 $name, 5, "$name FHEM SubProcess terminated, cleanup";
			tfrec_SubProcessCmd($hash, "terminate");
			tfrec_SubProcessCmd($hash, "cleanup");
			return;
		}
		
		Log3 $name, 3, "$name Unknown FHEM Cmd \"$cmd\"";
		
	} else {
		Log3 $name, 3, "$name Unknown Subprocess type \"$type\"";
	}
	
} #ReadSub


sub tfrec_OnRun($) {
	my $subprocess = shift;
	
	my $parentname = $subprocess->{PARENTNAME};
	my $subname = $subprocess->{NAME};
	
	my $parenthash = $defs{$parentname};
		
	#my $command = $subprocess->readFromParent();
	#Log3 $parentname, 1, "$parentname $subname Command $command" if($command);
	
	my $tfrec_debug = AttrVal($parentname, "tfrec_debug", "");
	my $tfrec_cmd = AttrVal($parentname, "tfrec_cmd", "");
	my $tfrec_args = AttrVal($parentname, "tfrec_args", "");
	my $tfrec_interval = AttrVal($parentname, "tfrec_interval", 0);
	my $tfrec_timeout = AttrVal($parentname, "tfrec_timeout", 0);
	
	if (!($tfrec_cmd && $tfrec_args)) {
		Log3 $parentname, 1, "$parentname $subname unable to start tfrec missing value";
		return "Failed";
	}

	my $timeout = "";
	if($tfrec_interval) {
		if($tfrec_interval && $tfrec_timeout && $tfrec_interval > $tfrec_timeout) {
			Log3 $parentname, 5, "$parentname $subname adding timeout to args";
			$timeout = "-w $tfrec_timeout";
		} else {
			Log3 $parentname, 3, "$parentname $subname timeout > interval interval disabled";
		}
	}
	
	Log3 $parentname, 4, "$parentname $subname Start Interval: $tfrec_interval Timeout: $tfrec_timeout";
	
	# tfrec start
	my $debug = "";
	if($tfrec_debug eq "on") {
		$debug = "-D";
		#"-DDD"
	}
	
	my $cmd = "$tfrec_cmd $tfrec_args $timeout $debug 2>&1";

	$subprocess->writeToParent("FHEM:reading tfrec_cmd $cmd");
	
	Log3 $parentname, 5, "$parentname $subname Cmd: \"$cmd\"";
	
	my $statemsg = "stopped";
	
	my $starttime = time();
	my $tfrec_pid = open(my $tfrec, "-|", $cmd ); #'/usr/bin/tfrec -T 1 -w 15 2>&1');
	
	# signals
	# ->terminate()
	$SIG{HUP} = sub { Log3 $parentname,5,"$parentname $subname HUP Caught a sigterm $!"; tfrec_KillPid($subprocess, $tfrec_pid); $statemsg ="terminated"; };
	# ->kill()
	$SIG{KILL} = sub { Log3 $parentname,4,"$parentname $subname KILL Caught a sigterm $!"; tfrec_KillPid($subprocess, $tfrec_pid); $statemsg ="killed"; exit 1;};
		
	if(!$tfrec_pid) {
			Log3 $parentname, 1, "$parentname $subname Error starting tfrec";
			$subprocess->writeToParent("FHEM:reading state tfrec ERROR");
			$subprocess->writeToParent("FHEM:reading tfrec_pid Error");
			return;
	}
	
	$subprocess->writeToParent("FHEM:reading state tfrec started");
	$subprocess->writeToParent("FHEM:reading tfrec_pid $tfrec_pid");
	#TODO set state
	
	Log3 $parentname, 4, "$parentname $subname tfrec PID $tfrec_pid";
	
	
	while(my $line = <$tfrec>) {
		# TODO timeout -> SIGNAL?
		Log3 $parentname, 5, "$parentname $subname Readline \"$line\"";
		
		$subprocess->writeToParent("OUTPUT:$line"); # triggers ReadFn via selectlist
		
		#$command = $subprocess->readFromParent(); # ??
		#if(!defined($command)) {
		#	if($subprocess->{lasterror} !~ /no data/) {
		#		Log3 $parentname, 1, "$parentname $subname Read error: ".$subprocess->{lasterror};
		#		#Dotrigger ?
		#	}
		#}
		
		# check timeout
		my $runtime = time() - $starttime;
		Log3 $parentname, 5, "$parentname $subname Runtime: $runtime";
		
		if($tfrec_interval && $runtime > $tfrec_timeout + 2) { # + 5
			Log3 $parentname, 4, "$parentname $subname Timeout $runtime";
			$statemsg = "timeout";
			last;
		}
	}
	
	close($tfrec);
	undef($tfrec);
	
	#give trfrec time to terminate
	sleep(1);
	
	if(tfrec_CheckPid($subprocess, $tfrec_pid)) {
		$statemsg .= " kill";
		tfrec_KillPid($subprocess, $tfrec_pid);
		Log3 $parentname, 1, "$parentname $subname tfrec pid $tfrec_pid killed";
	}
	
	$subprocess->writeToParent("FHEM:reading state tfrec not running ($statemsg)");
	$subprocess->writeToParent("FHEM:reading tfrec_pid -");
	
	$subprocess->writeToParent("FHEM:subprocess terminate");
	Log3 $parentname, 5, "$parentname $subname SubProcess finished";
} #OnRun

#sub tfrec_OnExit {
#	my $subprocess = shift;
#	$subprocess->writeToParent("FHEM:Subprocess OnExit");
#	Debug("--OnExit ------");
#} #OnExit

sub tfrec_KillPid($$) {
	my $hash = shift;
	my $pid = shift;
	
	my $name = $hash->{NAME};
	my $timeout = 5;
	
	return if(!$pid);
	
	Log3 $name, 5, "$name Stopping tfrec process $pid";
	my $ret = kill('TERM', $pid);
	while( kill(0, $pid) && $timeout > 0) {
		Log3 $name, 5, "$name Wait for PID ~0.25 s";
		select(undef, undef, undef, 0.25);
		$timeout -= 0.25;
	}
	
	Log3 $name, 5, "$name Timeout waiting for PID $pid" if($timeout <= 0);
	
	Log3 $name, 5, "$name No process with PID $pid" if(!$ret);
	
	return $ret;
} # StopPid

sub tfrec_CheckPid {
	my $hash = shift;
	my $pid = shift;
	
	my $name = $hash->{NAME};
	
	if(!$pid) {
		Log3 $name, 1, "$name PID undef";
		return undef;
	}
	
	my $ret = kill(0, $pid);
	
	if($ret) {
		Log3 $name, 5, "$name PID $pid is alive";
	} else {
		Log3 $name, 5, "$name PID $pid not found";
	}
	
	return $ret;
} # CheckPid

#tfrec_Ready {
#	my ($hash) = @_;
#	Debug("------tfrec_Ready----");
#}

sub tfrec_Notify($$)
{
	my ($hash, $dev_hash) = @_;
	my $name = $hash->{NAME}; # own name / hash
 
	return "" if(IsDisabled($name)); # Return without any further action if the module is disabled
 
	my $devname = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	
	return if( !$events );

	#Log3 $name, 5, "$name Event from $devname ".join(' ', @{$events}).Dumper($events);

	if($devname eq "global")
	{
		foreach my $event (@{$events}) {
			$event = "" if(!defined($event));
			Log3 $name, 5, "$name Notify $devname $event";
			
			if(grep(m/^INITIALIZED|REREADCFG$/, $event))
			{	
				tfrec_SubProcessInterval($hash);
			}
    	}
	}
} # Notify

sub tfrec_Undef($$) {
    my ($hash, $arg) = @_;
	
	my $name = $hash->{NAME};

	if(defined($hash->{SubProcess})) {
		tfrec_SubProcessCmd($hash, "terminate");
		tfrec_SubProcessCmd($hash, "wait");
	}

	tfrec_SubProcessCmd($hash, "cleanup");

	my $msg = "";
	if(defined($hash->{Sensors}{$name})) {
		# Remove from own list see tfrec_parse
		delete($hash->{Sensors}{$name});
		$msg .= "Notify remove $name from sensorlist"
	}
				
	my $addr = $hash->{addr};
	if(defined($addr)) {
		delete($hash->{defptr}{$addr});
		$msg .= ", $addr from defptr"
	}
	
	Log3 $name, 4, "$name $msg" if($msg);
	
} # Undef
	
sub tfrec_Parse($$) {
	my ($hash, $msg) = @_;
	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};

	$sname = $name if(!defined($sname));
	
	Log3 $sname, 5, "$name Message Length: ".length($msg)." parsing \"$msg\"";
	
	if(length($msg) < 27) {
		Log3 $sname, 3, "$name Message too short, ignoring";
		return;
	}
	
	my @fields = split(/\s+/, $msg);
	
	my $numfields = scalar(@fields);
	Log3 $sname, 5, "$name Number Fields: $numfields";
	
# tfrec -e "echo"
# id temp hum seq batfail rssi flags timestamp
# 01a3 +27.3 0 13 0 68 0 1567861455
# 02a4 +25.1 46 3 0 81 0 1567861820

	if($numfields < 8) {
		Log3 $sname, 3, "$name Not enough fields";
		return;
	}
	
	my ($sensorID, $temp, $hum, $seqnum, $batfail, $rssi, $flags, $timestamp) = @fields;
	
	Log3 $sname, 5, "$name Fields: $sensorID $temp $hum $seqnum $batfail $rssi $flags $timestamp (".localtime($timestamp).")";
	
	my $tempLSB = ($temp * 10 + 1000) & 0xff;
	my $tempMSB = (($temp * 10 + 1000) >> 8) & 0xff;
	my $humWBF = $hum | ($batfail << 7);
	
	my $dmsg = "OK 9 ".hex($sensorID)." 1 $tempMSB $tempLSB $humWBF";
	
# LaCrosse
# Temperature sensor - Format:
#      0   1   2   3   4
# -------------------------
# OK 9 56  1   4   156 37     ID = 56  T: 18.0  H: 37  no NewBatt
# OK 9 49  1   4   182 54     ID = 49  T: 20.6  H: 54  no NewBatt
# OK 9 55  129 4   192 56     ID = 55  T: 21.6  H: 56  WITH NewBatt

# OK 9 2   1   4 212 106       ID = 2   T: 23.6  H: -- Channel: 1
# OK 9 2   130 4 225 125       ID = 2   T: 24.9  H: -- Channel: 2

# OK 9 ID XXX XXX XXX XXX
# |  | |  |   |   |   |
# |  | |  |   |   |   --- Humidity incl. WeakBatteryFlag
# |  | |  |   |   |------ Temp * 10 + 1000 LSB
# |  | |  |   |---------- Temp * 10 + 1000 MSB
# |  | |  |-------------- Sensor type (1 or 2) +128 if NewBatteryFlag
# |  | |----------------- Sensor ID
# |  |------------------- fix "9"
# |---------------------- fix "OK"

	my %addvals= (  RSSI 				=> $rssi,
					RAWMSG				=> $msg,
					SeqNum				=> $seqnum, #0 - 15
					Flags				=> $flags,
					MSGTimeStamp		=> "".localtime($timestamp),
					);

	Log3 $sname, 5, "$name Dispatch Message: \"$dmsg\"";
	
	# Dispatch
	my @found = Dispatch($defs{$sname}, $dmsg, \%addvals);
	
	my $fdev = $found[0][0];
	if(!defined($fdev)) {
		Log3 $sname, 5, "$sname Dispatch returns undef";
		$defs{$sname}->{defptr}{hex($sensorID)}++;
		readingsSingleUpdate($defs{$sname}, "DispatchedError", "$dmsg", 0) if($defs{$sname}->{defptr}{hex($sensorID)} > 2); # autocreate threshold
		return;
	}

	undef($defs{$sname}->{defptr}{hex($sensorID)});
	
	readingsSingleUpdate($defs{$sname}, "Dispatched", "$dmsg", 0);
	
	# Bulk update
	readingsBeginUpdate($defs{$fdev});
	my $rv = readingsBulkUpdateIfChanged($defs{$fdev}, "RSSI", $rssi, 1);
	Log3 $sname, 5, "$name Update Reading $fdev: \"$rv\"" if($rv);
	
	$rv = readingsBulkUpdateIfChanged($defs{$fdev}, "SeqNum", $seqnum, 1);
	Log3 $sname, 5, "$name Update Reading $fdev: \"$rv\"" if($rv);
	readingsEndUpdate($defs{$fdev}, 1);
	
	if(!defined($defs{$sname}->{Sensors}{$fdev})) {
		$defs{$sname}->{Sensors}{$fdev} = 1;
		
		my $rval = ReadingsVal($fdev, ".associatedWith", '');
		if( $rval !~ /$sname/ ) {
			chomp(my $nval = "$rval $sname");
			$rv = readingsSingleUpdate($defs{$fdev}, ".associatedWith", "$nval", 0);
			Log3 $sname, 4, "$name Update Reading $fdev: \"$rv\"";
		}
	
		$rval = ReadingsVal($sname, ".associatedWith", '');
		if( $rval !~ /$fdev/ ) {
			chomp(my $nval = "$rval $fdev");
			$rv = readingsSingleUpdate($defs{$sname}, ".associatedWith", "$nval", 0);
			Log3 $sname, 4, "$name Update Reading $sname: \"$rv\"";
		}
	}
	
} # Parse

sub tfrec_Fingerprint($$) {
	my ($ioname, $msg) = @_;
	
	return ("", undef);
} # Fingerprint

sub tfrec_Set($@) {
	my ( $hash, $name, $cmd, @args ) = @_;
	
	if($cmd eq "tfrec_Intervalstart") {
		tfrec_SubProcessInterval($hash);
	} elsif($cmd eq "tfrec_Intervaldisable") {
		tfrec_SubProcessCmd($hash, "Intervaldisable");
	} elsif($cmd eq "tfrec_terminate") {
		tfrec_SubProcessCmd($hash, "terminate");
		tfrec_SubProcessCmd($hash, "cleanup");
	} elsif($cmd eq "tfrec_restart") {
		tfrec_SubProcessCmd($hash, "terminate");
		tfrec_SubProcessCmd($hash, "wait");
		tfrec_SubProcessCmd($hash, "cleanup");
		tfrec_SubProcessInterval($hash);
	} elsif($cmd eq "tfrec_check") {
		tfrec_SubProcessCmd($hash, "check");
	} elsif($cmd eq "tfrec_runonce") {
		tfrec_SubProcessCmd($hash, "run");
	} elsif($cmd eq "tfrec_kill") {
		tfrec_SubProcessCmd($hash, "kill");
	} elsif($cmd eq "tfrec_parse") {
		tfrec_Parse($hash, join(' ', @args));
	} elsif($cmd eq "tfrec_clearerrors") {
		readingsSingleUpdate($hash, "tfrec_error", "-", 0);
	} elsif($cmd eq "LaCrossePair") {
		$hash->{LaCrossePair} = $args[0];
	} else {
		return "Unknown argument $cmd, choose one of tfrec_check tfrec_Intervalstart tfrec_Intervaldisable tfrec_terminate tfrec_restart tfrec_runonce tfrec_kill tfrec_parse tfrec_clearerrors LaCrossePair";
	}
	
	Log3 $name, 5, "$name set $cmd";
	return;
}

sub tfrec_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	
	if($cmd eq "set") {
		return undef;
	}
	return undef;
}

1;

=pod
=begin html

<a name="tfrec"></a>
<h3>tfrec</h3>
<ul>
    <i>tfrec</i> uses
	<a href="https://github.com/baycom/tfrec">tfrec - A SDR tool for receiving wireless sensor data</a> to
	monitor KlimaLogg Pro Sensors.
	<br><br>
	This module dispatches recieved data to the defined modules, which then take care of the devices.
	<br><br>
	Make sure your fhem has access rights to the usb device:
	<br><br>
	e.g:<br>
	replace xxxx, yyyy by your rtl-sdr usb stick VID and PID<br>
	/etc/udev/rules.d/rtl-sdr.rules:<br>
	<code>SUBSYSTEMS=="usb", ATTRS{idVendor}=="xxxx", ATTRS{idProduct}=="yyyy", MODE:="0666"</code>
	<br><br>
	#service udev restart
	<br><br>
	Currently supported modules:
	<br><br>
	<ul>
		<li><i>LaCrosse</i><br>
			<b>Caution:</b> For this to work LaCrosse needs to be changes to accept KlimaLogg Sensors 4 digit IDs.<br>
			e.g.: Sensor 30.3180.IT
			<br><br>
			Change Line 47 in 36_LaCrosse.pm from:<br>
				<code>$a[2] =~ m/^([\da-f]{2})$/i;</code><br>
			to<br>
				<code>$a[2] =~ m/^([\da-f]{2,4})$/i;</code>
			<br><br>
			<b>Caution:</b> Will be overwritten on fhem update!!
			<br><br>
			Adds GPLOT (temp4hum4:Temp/Hum) and ATTR (event-on-change-reading:.* ) to LaCrosse for autocreate.
		</li>
	</ul>
	
    <br><br>
    <a name="tfrecdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; tfrec</code>
        <br><br>
        Example: <code>define tfrec tfrec</code>
        <br><br>
    </ul>
    <br>
    
    <a name="tfrecset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
		The following set command exist:
        <br><br>
        Options:
        <ul>
			  <li><i>tfrec_check</i><br>
                  Checks if tfrec porcess still running.
				  <br><br>
				  </li>
  			  <li><i>tfrec_restart</i><br>
                  Stop/Start tfrec process.
				  <br><br>
				  </li>
			  <li><i>trec_terminate</i><br>
                  Stops tfrec process.
				  <br><br>
				  </li>
			  <li><i>trec_kill</i><br>
                  Stops tfrec process.
				  <br><br>
				  </li>
			  <li><i>trec_startonce</i><br>
                  Starts tfrec process without interval timer.
				  <br><br>
				  </li>
			<li><i>trec_Intervalstart</i><br>
                  Starts tfrec process and interval timer.
				  <br><br>
				  </li>
			<li><i>trec_Intervaldisable</i><br>
                  Disable tfrec interval timer.
				  <br><br>
				  </li>
			<li><i>trec_clearerrors</i><br>
                  Clear error readings.
				  <br><br>
				  </li>
            <li><i>tfrec_parse</i><br>
                Parse tfrec output 
				<br><br>
				Format:<br>
				<code>id temp hum seq batfail rssi flags timestamp</code>
				<br><br>
				Example:<br>
				<code>01a3 +27.3 0 13 0 68 0 1567861455</code>
				<br><br>
				</li>
			<li><i>LaCrossePair</i> 0-2<br>
				Default: 2<br>
                Needed for LaCrosse autocreate.<br>
				If not equal 2 autocreate is disabled.
				<br><br>
				</li>
        </ul>
    </ul>
    <br>

    <a name="tfrecattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        Attributes:
        <ul>
            <li><i>verbose</i> 1-5<br>
				Default: not defined<br>
                Set verbositiy level
				<br><br>
            </li>
            <li><i>tfrec_cmd</i><br>
                Default: /usr/bin/tfrec
				<br><br>
				tfrec binary
				<br><br>
				<i>Needs a tfrec_restart.</i>
				<br><br>
            </li>
            <li><i>tfrec_args</i><br>
                Default: -T 1
				<br><br>
				tfrec arguments<br>
				-w see tfrec_interval and tfrec_timeout attributes.
				<br><br>
				<i>Needs a tfrec_restart.</i>
				<br><br>
            </li>
			<li><i>tfrec_interval</i><br>
                Default: 60<br>
				0 to disable interval.
				<br><br>
				Run tfrec every interval seconds for timeout seconds.<br>
				see tfrec_timeout attribute
				<br><br>
				<i>Needs a tfrec_restart.</i>
				<br><br>
            </li>
			<li><i>tfrec_timeout</i><br>
                Default: 15
				<br><br>
				Run tfrec every interval seconds for timeout seconds.<br>
				see tfrec_interval attribute
				<br><br>
				<i>Needs a tfrec_restart.</i>
				<br><br>
            </li>
            <li><i>tfrec_debug</i> on|off<br>
                Default: off
				<br><br>
				If "on" set tfrec debug output, create tfrec_last reading.
				<br><br>
				<i>Needs a tfrec_restart.</i>
				<br><br>
            </li>
            <li><i>disable</i> 0|1<br>
                Default: 0
				<br><br>
				Disable device.
				<br><br>
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
