#!/usr/bin/perl
#
# Prints laptop battery status

# Requires perl-net-dbus with perl-xml-twig

use strict;
use warnings "all";

use Net::DBus::Dumper;
use Net::DBus;
use Data::Dumper;

sub to_hours($); # translates seconds to HH:MM format

my $bus = Net::DBus->system;

my $upower = $bus->get_service("org.freedesktop.UPower");

my $properties = $upower->get_object("/org/freedesktop/UPower/devices/battery_BAT0", "org.freedesktop.DBus.Properties");
my $capacity = $properties->Get('org.freedesktop.UPower.Device', 'Percentage');
my $state = $properties->Get('org.freedesktop.UPower.Device', 'State');
my $time = "?";

if ($state == 2) {
# discharging
	$time = $properties->Get('org.freedesktop.UPower.Device', 'TimeToEmpty');
	# time in seconds, let's translate it to hours:minutes
	$state = '▼';
} elsif ($state == 1) {
# charging
	$time = $properties->Get('org.freedesktop.UPower.Device', 'TimeToFull');
	$state = '▲';
} else {
# already charged
	$time = 0;
	$state = '•';
}

$time = to_hours ($time);

printf("[%s%% %s %s]", $capacity, $state, $time);

exit 0;

sub to_hours ($) {
	my $sec = shift;
	my $hrs = $sec / (60 * 60);
	$hrs = 0 if ( $hrs < 1 );
	my $min = ($sec - ($hrs * 60 * 60)) / 60;
	$min = 0 if ( $min < 1 );
	return sprintf("%02d:%02d", $hrs, $min);
}

