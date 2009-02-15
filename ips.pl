#!/usr/bin/perl -w

# ips.pl
# version 0.01cn
#
# This is a quick hack to apply IPS patches. It is distributed under
# the terms of the GNU General Public License.

use strict;
use Getopt::Long;
use Fcntl qw/SEEK_SET/;

my $verbose = 0;

GetOptions(
    "verbose"   => \$verbose,
);

unless (@ARGV == 2) {
	print "Usage: ips.pl FILE IPS_PATCH\n";
    print "Patches FILE using an IPS patch.\n";

    print "Changes 2009 chinesefood (eat.more.chinese.food\@gmail.com)\n";
	exit;
}

my $patch;
DETECT_PATCH: for (my $i = 0; $i < @ARGV; $i++) {
    open(PATCH, $ARGV[$i]) or die "Can't open $ARGV[$i] for reading.\n";

    read(PATCH, my $header, 5);
    $patch = splice(@ARGV, $i, 1) if $header eq 'PATCH';
last DETECT_PATCH if $patch;

    close(PATCH);
}
die("No IPS patch provided.\n") unless $patch;

my $rom = $ARGV[0];
open(ROM, "+<$rom") or die "Can't open $rom";

PATCH_LOOP: for (;;) {
	read(PATCH, my $rom_offset, 3) or die "Read error";

	last PATCH_LOOP if $rom_offset eq 'EOF';

	# No 24-bit number template in pack.  This works okay for now.
	$rom_offset = hex( unpack("H*", $rom_offset) );

	print "At address $rom_offset, " if $verbose;
	seek(ROM, $rom_offset, SEEK_SET) or die "Failed seek";

	read(PATCH, my $data_size, 2) or die "Read error";
	my $length = hex( unpack("H*", $data_size) );

	if ($length) {
		print "writing $length bytes of data.\n" if $verbose;
		read(PATCH, my $data, $length) == $length or die "Read error";
		print ROM $data;
	}
	else { # RLE mode
		read(PATCH, my $rle_size, 2) or die "Read error";
		$length = hex( unpack("H*", $rle_size) );

		print "writing $length bytes of RLE data.\n" if $verbose;
		read(PATCH, my $byte, 1) or die "Read error";
		print ROM ($byte)x$length;
	}
}

close(PATCH);
close(ROM);

print "Patched $rom with $patch.\n";
exit;