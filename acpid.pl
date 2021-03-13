#!/usr/bin/perl
#
# Hibernates system if battery charge drops under $MIN_CHARGE and battery discharging

use strict;
use warnings;

sub logger; # logs messages if $debug != 0

$0 = 'acpid.pl';
my $debug = 0;
my $MIN_CHARGE = 10;

my $base = '/sys/class/power_supply/BAT0';

unless (-f "$base/present") {
	logger "Battery info at /sys/class/BAT0/present not found, quitting.";
	exit 0;
}

my $battery_present = 2;
my $battery_check = 2;
my $charging = 2;

while (sleep 180) {
	open (my $batteryFH, '<', "$base/present") or next;
	my $buf;

	if (read ($batteryFH, $buf, 1)) {
		if ($battery_check == 0) {
			logger "Ability to read from $base/present restored";
			$battery_check = 1;
		}

		if ($buf == '0') {
			if ($battery_present) {
				logger "We have no battery, skipping charge level polling until it appears";
				$battery_present = 0;
			}

			close $batteryFH;
			next;
		}
	} else {
		if ($battery_check) {
			logger "Unable to read from /sys/class/BAT0/present";
			$battery_check = 0;
		}

		close $batteryFH;
		next;
	}

	close $batteryFH;
	$battery_present = 1;

# check status, we have no need to poll battery if it charging/charged
	unless (-f "$base/status") {
		logger "Something broken in /sys, unable to find $base/status, quitting";
		exit 1;
	}

# TODO: file access save state and print on change
	open (my $statusFH, '<', "$base/status") or do {
		logger "Unable to open $base/status";
		next;
	};

	$buf = <$statusFH>;
	close $statusFH;
	chomp $buf;

	if ($buf ne 'Discharging') {
		if ($charging != 1) {
			logger "Battery charging.";
			$charging = 1;
		}
	} else {
		if ($charging) {
			logger "Battery discharging.";
			$charging = 0;
		}
	}

# read charge state
	unless (-f "$base/capacity") {
		logger "Something broken in /sys, unable to find $base/capacity, quitting";
		exit 1;
	}

# TODO: file access save state and print on change
	open (my $chargeFH, '<', "$base/capacity") or do {
		logger("Unable to open $base/capacity\n");
		next;
	};

	read ($chargeFH, $buf, 3) or do {
		logger "Unable to read $base/capacity, but file is in place";
		next;
	};

	close $chargeFH;
	chomp $buf; # just in case

	if ($buf < $MIN_CHARGE) {
		if ($charging != 0) { # discharging
			logger "Battery charge is less than 10%, hibernating";
			`dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Hibernate`;
		}
	} else {
		if ($buf < ($MIN_CHARGE + 5)) {
			`notify-send --urgency=critical --expire-time=10000 --icon=battery-caution "Low battery charge: $buf%"`;
		}

		if ( ($charging == 1) and ( $buf > 100) ) {
			`notify-send --urgency=normal --expire-time=3000 "Battery overcharging"`;
		}

		logger "Charge is $buf%";
	}
}


sub logger {
	if ($debug) {
		my $msg = shift;
		$msg = sprintf '%s %s\n', localtime (), $msg;
		syswrite STDOUT, $msg;
	}
}
