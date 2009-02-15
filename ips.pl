#!/usr/bin/perl -w

# ips.pl
# version 0.02

# Copyright 2009 chinesefood.

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

    print "Copyright 2003, 2009 chinesefood (eat.more.chinese.food\@gmail.com)\n";
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
		read(PATCH, my $byte, 1) == 1 or die "read() failed reading RLE data.\n";
		print ROM "$byte" x $length;
	}
}

print "Patched $rom with IPS file $patch.\n";

close(PATCH);
close(ROM);

exit;

__END__

=head1 NAME

ips.pl - Patches a file with records provided from an IPS patch.

=head1 SYNOPSIS

    ips.pl myfilepatch.ips my.file

=head1 DESCRIPTION

ips.pl is a revision of a Perl script found in the wild (L<http://www.zophar.net/utilities/patchutil/ips-pl.html>) which will apply patches in the IPS format to the file specified.  The IPS file format can be found at L<http://zerosoft.zophar.net/ips.php>.  It supports RLE (Run Length Encoded) IPS patches as well.

=head1 COPYRIGHT

Copyright 2003, 2009 chinesefood (eat.more.goawayspam.chinese.food@goawayspam.gmail.com)

The original author is unknown at the time of this release.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut