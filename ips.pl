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
    open(PATCH, $ARGV[$i]) or die "open() failed opening $ARGV[$i] for reading.\n";

    read(PATCH, my $header, 5);
    $patch = splice(@ARGV, $i, 1) if $header eq 'PATCH';

    last DETECT_PATCH if $patch;

    close(PATCH);
}
die("Failed to detect an IPS patch.\n") unless $patch;

my $rom = $ARGV[0];
open(ROM, "+<$rom") or die "open() failed opening $rom\n";

PATCH_LOOP: for (;;) {
    my $rom_offset;
	read(PATCH, $rom_offset, 3) or die("read() failed to read $rom_offset.\n");

	last PATCH_LOOP if $rom_offset eq 'EOF';

	# No 24-bit number template in pack.  This works okay for now.
	$rom_offset = hex( unpack("H*", $rom_offset) );

	print "At offset $rom_offset, " if $verbose;
	seek(ROM, $rom_offset, SEEK_SET) or die("seek() failed to seek to $rom_offset.\n");

	read(PATCH, my $data_size, 2) or die("read() failed reading data size.\n");
	my $length = hex( unpack("H*", $data_size) );

	if ($length) {
		print "writing $length bytes of data.\n" if $verbose;
		read(PATCH, my $data, $length) == $length
            or die("read() failed with $length bytes read.\n");
		print ROM $data;
	}
	else { # RLE mode
		read(PATCH, my $rle_size, 2) or die("read() failed reading RLE size.\n");
		$length = hex( unpack("H*", $rle_size) );

		print "writing $length bytes of RLE data.\n" if $verbose;
		read(PATCH, my $byte, 1) == 1 or die "read() failed RLE data.\n";
		print ROM "$byte" x $length;
	}
}

print "Patched $rom with IPS file $patch.\n";

close(PATCH);
close(ROM);

exit;