#!/usr/bin/perl

# ips.pl
# version 0.01cn
#
# This is a quick hack to apply IPS patches. It is distributed under
# the terms of the GNU General Public License.

if (@ARGV != 2) {
	print STDERR <<EOF;
Usage:

$0 datafile ipsfile

There are no options. Your original datafile is modified.
EOF

	exit;
}

use strict;

open(PATCH, "$ARGV[1]") or die "Can't open $ARGV[1]";
open(ROM, "+<$ARGV[0]") or die "Can't open $ARGV[0]";

read(PATCH, my $header, 5);
die "Bad magic bytes in $ARGV[1]" if $header ne "PATCH";

while(1) {
	read(PATCH, my $rom_offset, 3) or die "Read error";

	if ($rom_offset eq "EOF") {
        close(PATCH);
        close(ROM);

		print STDERR "Done!\n";
		exit;
	}

	# No 24-bit number template in pack.  This works okay for now.
	$rom_offset = hex( unpack("H*", $rom_offset) );

	print STDERR "At address $rom_offset, ";
	seek(ROM, $rom_offset, "SEEK_SET") or die "Failed seek";

	read(PATCH, my $data_size, 2) or die "Read error";
	my $length = hex( unpack("H*", $data_size) );

	if ($length) {
		print STDERR "Writing $length bytes, ";
		read(PATCH, my $data, $length) == $length or die "Read error";
		print ROM $data;
	}
	else { # RLE mode
		read(PATCH, my $rle_size, 2) or die "Read error";
		$length = hex( unpack("H*", $rle_size) );

		print STDERR "Writing $length bytes of RLE, ";
		read(PATCH, my $byte, 1) or die "Read error";
		print ROM ($byte)x$length;
	}

	print STDERR "done\n";
}