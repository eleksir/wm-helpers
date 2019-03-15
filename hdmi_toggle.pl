#!/usr/bin/perl
# hotplug script that toggles laptop' secondary display to be right of embedded one

use strict;
use warnings "all";

use Fcntl;

my $XRANDR = `xrandr`;

if ( $? != 0 ) {
	exit 1;
}

my @connected = grep {/ connected /} split(/\n/, $XRANDR);

if (@connected > 2) {
	print "Assume that we have no more than 2 displays: one in lid and one external";
	exit 1;
}

my @disconnected = grep {/ disconnected \d/} split(/\n/, $XRANDR);
my $config = (split(/\n/, $XRANDR, 2))[0];
my $vscreenWidth = (split(/\s/, $config))[7];
my $sumOfDisplaysWidth = 0;

my $restart = 0;

# this loop required to disable disconnected but not disabled display
do {
	# if we detect disconnected display that is not not yet disabled, we disable it and
	# on one more iteration we need to update displays list
	if ($restart == 1) {
		$XRANDR = `xrandr`;
		@connected = -1;
		@connected = grep {/ connected /} split(/\n/, $XRANDR);
		@disconnected = grep {/ disconnected \d/} split(/\n/, $XRANDR);
	}

	$restart = 0;

	foreach my $d (@connected) {
		my $param = (split(/ /, $d))[2];

		# display disconnected but not disabled
		if ((split(/x/, $param, 2))[0] eq '(normal') {
			my $display = (split(/ /, $d, 2))[0];
			`xrandr --output $display --auto`;
			sleep 2;
			$sumOfDisplaysWidth = 0;
			$restart = 1;
			last;
		}

		$sumOfDisplaysWidth += (split(/x/, $param, 2))[0];
	}
} while ($restart == 1);

# no changes, just quit
if ($vscreenWidth == $sumOfDisplaysWidth) {
	exit 0;
}

my $embeddedDisplay = '';
my $externalDisplay = '';

foreach my $d (@connected) {
	my $display = (split(/ /, $d, 2))[0];

	if ($display =~ /^e/) {
		$embeddedDisplay = $display;
	} else {
		$externalDisplay = $display;
	}
}

if ($externalDisplay eq '') {
	$externalDisplay = (split(/ /, $disconnected[0], 2))[0];
}

if ($vscreenWidth > $sumOfDisplaysWidth) {
	`xrandr --output $externalDisplay --off`;
} elsif ($vscreenWidth < $sumOfDisplaysWidth) {
	`xrandr --output $externalDisplay --auto --right-of $embeddedDisplay`;
}

exit 0;

