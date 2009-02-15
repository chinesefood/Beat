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

open(PAT, "$ARGV[1]") or die "Can't open $ARGV[1]";
open(DAT, "+<$ARGV[0]") or die "Can't open $ARGV[0]";

read(PAT, my $header, 5);
die "Bad magic bytes in $ARGV[1]" if $header ne "PATCH";

while(1) {
	read(PAT, my $rom_offset, 3) or die "Read error";

	if ($rom_offset eq "EOF") {
		print STDERR "Done!\n";
		exit;
	}

	# This is ugly, but unpack doesn't have anything that's
	# very helpful for THREE-byte numbers.
	$rom_offset = ord(substr($rom_offset,0,1))*256*256 +
	ord(substr($rom_offset,1,1))*256 +
	ord(substr($rom_offset,2,1));

	print STDERR "At address $rom_offset, ";
	seek(DAT, $rom_offset, "SEEK_SET") or die "Failed seek";

	read(PAT, my $data_size, 2) or die "Read error";
	my $length = ord(substr($data_size,0,1))*256 + ord(substr($data_size,1,1));

	if ($length) {
		print STDERR "Writing $length bytes, ";
		read(PAT, my $data, $length) == $length or die "Read error";
		print DAT $data;
	}
	else { # RLE mode
		read(PAT, my $rle_size, 2) or die "Read error";
		$length = ord(substr($rle_size,0,1))*256 + ord(substr($rle_size,1,1));

		print STDERR "Writing $length bytes of RLE, ";
		read(PAT, my $byte, 1) or die "Read error";
		print DAT ($byte)x$length;
	}

	print STDERR "done\n";
}
