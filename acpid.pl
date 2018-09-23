#!/usr/bin/perl
#
# Hibernates system if battery charge drops under $MIN_CHARGE and battery discharging


use strict;
use warnings "all";
use Fcntl;

sub logger($); # logs messages if $debug != 0
# maybe one time i'll use it
sub i3wmstate; # returns 1 if i3wm running, else - 0


$0 = 'acpid.pl';
my $debug = 0;
my $MIN_CHARGE = 10;

my $base = '/sys/class/power_supply/BAT0';

unless(-f "$base/present") {
	logger("Battery info at /sys/class/BAT0/present not found, quitting.\n");
	exit 0;
}

my $battery_present = 2;
my $battery_check = 2;
my $charging = 2;

while ( sleep(180) ) {
# check that battery is in place
	open(ACPI, "$base/present") or next;
	my $buf = '';

	if (read(ACPI, $buf, 1)) {
		if ($battery_check == 0) {
			logger("Ability to read from /sys/class/BAT0/present restored\n");
			$battery_check = 1;
		}

		if ($buf == '0') {
			if ($battery_present != 0) {
				logger("We have no battery, skipping charge level polling until it appears\n");
				$battery_present = 0;
			}

			close ACPI;
			next;
		}
	} else {
		if ($battery_check != 0) {
			logger("Unable to read from /sys/class/BAT0/present\n");
			$battery_check = 0;
		}

		close ACPI;
		next;
	}

	close ACPI;
	$battery_present = 1;

# check status, we have no need to poll battery if it charging/charged
	unless (-f "$base/status") {
		logger("Something broken in /sys, unable to find $base/status, quitting\n");
		exit 1;
	}

# TODO: file access save state and print on change
	open(STATUS, "$base/status") or do {
		logger("Unable to open $base/status\n");
		next;
	};

	$buf = <STATUS>;
	close STATUS;

	chomp($buf);

	if ($buf ne 'Discharging') {
		if ($charging != 1) {
			logger("Battery charging.\n");
			$charging = 1;
		}
	} else {
		if ($charging != 0) {
			logger("Battery discharging.\n");
			$charging = 0;
		}
	}

# read charge state
	unless (-f "$base/capacity") {
		logger("Something broken in /sys, unable to find $base/capacity, quitting\n");
		exit 1;
	}

# TODO: file access save state and print on change
	open(CHARGE, "$base/capacity") or do {
		logger("Unable to open $base/capacity\n");
		next;
	};

	read(CHARGE, $buf, 3) or do {
		logger("Unable to read $base/capacity, but file is in place\n");
		next;
	};

	chomp($buf); # just in case

	if ($buf < $MIN_CHARGE) {
		logger("Battery charge is less than 10%, hibernating\n");
		`dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Hibernate`;
	} else {
		if ($buf < ($MIN_CHARGE + 5)) {
			`notify-send --urgency=critical --expire-time=10000 --icon=battery-caution "Low battery charge: $buf%"`;
		}

		if ( ($charging == 1) and ( $buf > 100) ) {
			`notify-send --urgency=normal --expire-time=3000 "Battery overcharging"`;
		}

		logger("Charge is $buf%\n");
	}
}


sub logger ($) {
	if ($debug != 0) {
		my $msg = shift;
		$msg = localtime() . ' ' . $msg;
		syswrite STDOUT, $msg;
	}
}

sub i3wmstate {
	my $flag = 0;
	opendir(P, '/proc') || die 'no /proc found!';

	while (readdir(P)) {
		my $pid = $_;
		next unless(defined($pid));
		next if ($pid eq '');

		if (-d "/proc/$pid") {
			# dir UID == APCID.pl process user owner
			if ((stat("/proc/$pid"))[4] == int(getpwnam($ENV{'LOGNAME'}))) {
				next unless(-r "/proc/$pid/cmdline");
				open(CMDLINE, "/proc/$pid/cmdline") || die "unable to open /proc/$pid/cmdline";
				my $cl = <CMDLINE>;
				close(CMDLINE);

				if(defined($cl)) {
					if ((substr($cl, 0, 2) eq 'i3') and (length($cl) <= 4)) {
						$flag = 1;
						undef $cl;
						undef $pid;
						last;
					}
				}

				undef $cl;
			}
		}

		undef $pid;
	}

	return $flag;
}
