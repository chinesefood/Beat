#!/usr/bin/perl -w

use strict;
use Getopt::Long;

use IPS;

our $VERSION = "0.04";

my $verbose = 0;
GetOptions(
	"verbose"   => \$verbose,
);

my $ips = IPS->new();
my $ips_file = detect_ips_patch() || print_usage_statement();
$ips = IPS->new( 'patch_file' => $ips_file );

foreach my $file (@ARGV) {
	print "Patching $file...\n";

	if ($verbose) {
		unless ( open(FH_ROM, "+<$file") ) {
			die("Could not open $file for reading/writing.\n");
		}

		foreach my $record ( $ips->get_all_records() ) {
			if ( $record->is_rle() ){
				print "Writing ", $record->get_rle_length(), " RLE bytes to offset ", $record->get_rom_offset(), "\n";
			}
			else {
				print "Writing ", $record->get_data_size(), " bytes to offset ", $record->get_rom_offset(), "\n";
			}

			$record->write(*FH_ROM);
		}

		if ( $ips->get_truncation_point() ) {
			print "Truncating file...\n";
			$ips->truncate_file(*FH_ROM);
		}
	}
	else {
		$ips->apply_ips_patch($file);
	}

	close(FH_ROM);
}

exit;




sub detect_ips_patch {
	for (my $i = 0; $i < @ARGV; $i++) {
		my $file = $ARGV[$i];
		unless ( open(FH, $file) ) {
			die("open(): Cannot open $file for reading.\n");
		}

		if ( $ips->check_header(*FH) ) {
			splice(@ARGV, $i, 1);
			close(FH);

			return $file;
		}

		close(FH);
	}

	return;
}

sub print_usage_statement {
	print "ips.pl v$VERSION\n\n";
	print "Usage: ips.pl [--verbose] IPS_PATCH FILE1 FILE2 ...\n";
	print "Patches FILES using an IPS patch.\n\n";

	print "Copyright 2003, 2009 chinesefood (eat.more.chinese.food\@gmail.com)\n";
	print "Homepage:  http://github.com/chinesefood/ips.pl/tree/master\n";
	print "This program is free software; you can redistribute it and/or modify it under\n".
		  "the terms of the GNU General Public License as published by the Free Software\n".
		  "Foundation; either version 2 of the License, or (at your option) any later\n".
		  "version.\n";

	print "This program is distributed in the hope that it will be useful, but WITHOUT\n".
		  "ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS\n".
		  "FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.\n";

	print "You should have received a copy of the GNU General Public License along with\n".
		  "this program; if not, write to the Free Software Foundation, Inc., 51 Franklin\n".
		  "Street, Fifth Floor, Boston, MA  02110-1301, USA.\n";

	exit;
}








__END__

=head1 NAME

ips.pl - Patches a file with records provided from an IPS patch.

=head1 SYNOPSIS

	ips.pl [--verbose] myfilepatch.ips my.file my.file2 my.file3

=head1 DESCRIPTION

ips.pl is a reimplementation of a Perl script found in the wild (L<http://www.zophar.net/utilities/patchutil/ips-pl.html>) which will apply patches in the IPS format to the file specified.  The IPS file format can be found at L<http://zerosoft.zophar.net/ips.php>.  It supports RLE (Run Length Encoded) IPS patches as well.

=head2 Flags

=over 4

=item * ips.pl --verbose patch.ips file.rom

Prints details on each applied patch record to STDOUT.

=back

=head1 HOMEPAGE

L<http://github.com/chinesefood/ips.pl/tree/master>

=head1 COPYRIGHT

Copyright 2003, 2009 chinesefood (eat.more.goawayspam.chinese.food@goawayspam.gmail.com)

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

The original author is unknown at the time of release.

=cut