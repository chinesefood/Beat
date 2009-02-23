#!/usr/bin/perl -w

use strict;
use Getopt::Long;

use IPS;

our $VERSION = "0.05";

# Check for flags in arguments.

my $verbose = undef;
my $merge   = undef;
GetOptions(
    "verbose"   => \$verbose,
    "merge=s"   => \$merge,
);

# Let the user know they didn't specify any actions.

print_usage_statement() unless (@ARGV);

# Construct an IPS instance here to use its methods.

my $ips = IPS->new();

# Merge patches together into one patch.

if ($merge) {

    # Perform the merge by pushing all patch records into one IPS instance.

    foreach (@ARGV) {
        my $ips_to_merge = IPS->new( 'patch_file' => $_ );
        $ips->push_record( $ips->get_all_records() );
    }

    # Finalize the merge by writing to disk.

    $ips->write_ips_patch($merge);
    exit;
}

# The argument list is parsed to allow for multiple patches per file.

my %patches = build_patch_hash();
foreach my $rom ( keys %patches ) {
    print "Patching $rom...\n";

    # Patches are applied to arrive at the modified file.

    foreach my $patch ( @{ $patches{$rom} } ) {
        print "\tApplying $patch\n";
        $ips->apply_ips_patch($rom, $patch);
    }
}

exit;

# A hash of filenames pointing to an arrayref of patches makes patching easy.

sub build_patch_hash {
    my %patches;

    # FIND_ROMS crawls across all arguments looking for files to patch.

    FIND_ROMS: for (my $i = 0; $i < @ARGV; $i++) {

        # Open the file to find if it is a file to be patched.

        my $file = $ARGV[$i];
        open ROM, $file or die "Couldn't open $file.\n";

        # The loop will eventually bump into a non-patch file and next along.

        unless ( $ips->check_header(*ROM) ) {
            my @patches;

            # The list of patches is built here.  $i + 1 is the first patch.

            PUSH_PATCHES: for (my $j = $i + 1; $j < @ARGV; $j++) {

                # Open the file to find if it is a patch.

                my $possible_patch = $ARGV[$j];
                open PATCH, $possible_patch
                    or die "Couldn't open $possible_patch.\n";

                # This test determines if a non-patch file was found.

                my $result = $ips->check_header(*PATCH);
                close PATCH;

                # Exit the loop and start building another patch array.

                last PUSH_PATCHES unless $result;

                # Add to the patch array.

                push @patches, $possible_patch;
            }

            # The list of patches is stored in the patch hash to be accessed.

            $patches{$file} = \@patches;
        }
        else {
            close ROM;

            # Start building another patch array.

            next FIND_ROMS;
        }
    }

    return %patches;
}

# Let the user know they didn't provide enough arguments.

sub print_usage_statement {
    print
        "ips.pl v$VERSION\n\n",
        "Usage: ips.pl [--verbose] IPS_PATCH FILE1 FILE2 ...\n",
        "Patches FILES using an IPS patch.\n\n",

        "Copyright 2003, 2009 chinesefood (eat.more.chinese.food\@gmail.com)\n",
        "Homepage:  http://github.com/chinesefood/ips.pl/tree/master\n\n",

        "This program is free software; you can redistribute it and/or modify it under\n",
        "the terms of the GNU General Public License as published by the Free Software\n",
        "Foundation; either version 2 of the License, or (at your option) any later\n",
        "version.\n\n",

        "This program is distributed in the hope that it will be useful, but WITHOUT\n",
        "ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS\n",
        "FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.\n\n",

        "You should have received a copy of the GNU General Public License along with\n",
        "this program; if not, write to the Free Software Foundation, Inc., 51 Franklin\n",
        "Street, Fifth Floor, Boston, MA  02110-1301, USA.\n",
        ;

    exit;
}








__END__

=head1 NAME

ips.pl - Patches a file with records provided from IPS patches.

=head1 SYNOPSIS

    ips.pl file1 patch1.ips ... file2 patch2.ips ...

=head1 DESCRIPTION

ips.pl is a reimplementation of a Perl script found in the wild
(L<http://www.zophar.net/utilities/patchutil/ips-pl.html>) which
will apply patches in the IPS format to the file specified.  The IPS
file format can be found at L<http://zerosoft.zophar.net/ips.php>.
It supports RLE (Run Length Encoded) IPS patches as well.

=head2 Flags

=over 4

=item * ips.pl --merge=newpatch.ips patch1.ips patch2.ips

Merges multiple IPS patches into one IPS patch.

=back

=head1 HOMEPAGE

L<http://github.com/chinesefood/ips.pl/tree/master>

=head1 COPYRIGHT

Copyright 2003, 2009 chinesefood (eat.more.chinese.food@gmail.com)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301, USA.

The original author is unknown at the time of release.

=cut