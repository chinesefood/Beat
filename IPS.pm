package IPS;

use strict;
use warnings;

# These constants are defined to improve clarity.

use constant IPS_HEADER                 => 'PATCH';
use constant IPS_HEADER_SIZE            => 5;
use constant IPS_DATA_OFFSET_SIZE       => 3;
use constant IPS_DATA_SIZE              => 2;

use constant IPS_RLE_LENGTH             => 2;
use constant IPS_RLE_DATA_SIZE          => 1;

use constant IPSv2_TRUNCATION_OFFSET_SIZE => 3;

use Fcntl qw( SEEK_SET SEEK_CUR SEEK_END );
use Carp;

use IPS::Record;

our $VERSION = 0.01;

=head1 NAME

IPS - A Perl module that provides an interface for handling patches
      in the International Patching System format.

=head1 SYNOPSIS

    use IPS;

    # Apply an IPS patch to a file.
    my $ips = IPS->new('patch_file' => $ARGV[0]);
    $ips->apply_ips_patch($ARGV[1]);

=head1 DESCRIPTION

The International Patching System (IPS) is a patch format that was
originally developed for patching Amiga games.  It is now the main
patch format for distributing fan translations of console games.

=head2 File Format

What was one patch format has speciated into many patch formats.  An
IPS file can contain Run Length Encoding (RLE) to save space, but
compression techology has improved past the point where this became
useless.  Creating new RLE patches is strongly, really, mega
discouraged.  Use UPS instead.

    At a Glance
    Offset  Value   Size    Purpose

    0       PATCH   5       IPS patch header
    6       Varies  Varies  Patch records (see below)
    EOF - 3 EOF     3       Marks End Of File (EOF)

    Standard Patch Record
    Offset  Size    Purpose

    0       3       ROM offset value
    3       2       Size of new data
    5       Varies  Data

    RLE Patch Record

    Offset  Size    Purpose
    0       3       ROM offset value
    3       2       This is zero to mark this is a RLE record.
    5       2       Length of data to be patched.
    7       1       Data byte

=cut

=head2 Methods

The interface is not finished.  Do expect changes.

=over 4

=item * $ips->new()

Instantiates a new IPS object, initalizes it if a patch file is
passed, and returns the reference to it.  A hash can be passed at
instantiation to override defaults:

    patch_file       => $filename   # Specify an IPS patch.
                                    # Required for initialization.
                                    #
    patch_filehandle => $fh         # Filehandle optionally used in
                                    # IPS package implementation
                                    #
    is_rle           => 'yes'       # Set to string literal 'yes'
                                    # internally but can be anything
                                    # to declare this patch is RLE
                                    #
    truncation_point => $value      # 24 bit value indicating where
                                    # to truncate file
                                    #
    records          => \@array     # A reference to an array of
                                    # IPS::Records.

=cut

# Construct a new IPS instance.

sub new {
    my ($class, %override_of) = @_;

    # Supply default instance data.

    my $self = {

        # No test to determine if patch is RLE.  Set if RLE record is found.

        'is_rle'            => undef,

        # Path stored to provide default method behavior.

        'patch_file'        => undef,

        # Filehandle stored to provide default behavior.

        'patch_filehandle'  => undef,

        # Truncation point offset stored as it is a property of the patch.

        'truncation_offset' => undef,

        # Used to store IPS record objects.

        'patch_records'     => [],
    };

    # This loop allows one to provide values overriding the default data.

    foreach my $key ( keys %override_of ) {
        $self->{$key} = $override_of{$key} if exists $self->{$key};
    }

    bless $self, ref $class || $class;

    # The init can be done again, but doing it automatically saves typing.

    $self->init() if $self->get_patch_filename();

    return $self;
}

=item * $ips->init()

Sets the patch filehandle, checks the IPS patch header, and reads
the patch records into memory.  Also detects a truncation value.

=cut

# Intializing the constructor with records provides access to the patch.

sub init {
    my ($self) = @_;

    # Default method behavior depends on setting the filehandle attribute.

    my $patch_filehandle = $self->_open_file( $self->get_patch_file() );
    $self->set_patch_filehandle( $patch_filehandle );

    # Stop everything if the file isn't an IPS patch.

    unless( $self->check_header() ) {
        croak "Header mismatch; " . $self->get_patch_file()
            ." not an IPS patch";
    }

    # Move the actual patch data into memory to allow access.

    $self->read_patch_records($patch_filehandle);

    # Find truncation value, if any, to ensure we patch correctly later on.

    if ( $self->is_ips_v2() ) {
        my $truncation_point = $self->read_truncation_point();
        $self->set_truncation_point( $truncation_point );
    }
}

=item * $ips->read_records(*FH)

Reads and sets the patch records from the patch filehandle set or by
a filehandle passed at runtime.

=cut

# Provides an easy way to reload all records of an IPS patch into memory.

sub read_patch_records {
    my ($self, $patch_filehandle) = @_;

    # The first record of an IPS patch is always at offset 5, so move here.

    my $filehandle_position = 5;
    seek $patch_filehandle, $filehandle_position, SEEK_SET;

    # The loop does the reading from here.

    READ_RECORDS: for (my $i = 0; ; $i++) {

        # Provide an interface for the record data.

        my $new_record = IPS::Record->new(
            'num'           => $i,

            # Storing the record offset provides disk access to it later.

            'record_offset' => $filehandle_position,

            # Set to allow the record to find where to write itself to disk.

            'ips_patch'     => $self,
        );

        # This provides a way to exit the loop if at the end of the records.

        last READ_RECORDS if $new_record->read_rom_offset() eq 'EOF';

        # Set the record and its data to ease patching operations.

        $new_record->memorize_data();
        $self->set_record( $i => $new_record );

        # Calculate the next IPS record's position for the next iteration.

        $filehandle_position += IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE;

        # RLE records are a fixed size while regular records vary in size.
        # The position of the next record will vary depending on the size of
        # this record, and this is tests for those variations.

        if ( $new_record->is_rle() ) {
            $filehandle_position += IPS_RLE_LENGTH + IPS_RLE_DATA_SIZE;
        }
        else {
            $filehandle_position += $new_record->get_data_size();
        }
    }
}

{
    # Internal file opening method for code reuse.

    sub _open_file {
        my ($self, $file) = @_;

        # Open a file and set binary mode for Windows compatibility.

        unless ( open FH, "+<$file"  ) {
            croak "Could not open() " . $file . " for read/write access";
        }
        binmode FH;

        return *FH;
    }
}

=item * my $value = $ips->read_truncation_point(*FH)

Reads the offset stored in IPSv2 patches that instruct the patcher
to truncate the patched file at said offset.  Default behavior is
to check the initialized filehandle, but a filehandle can be passed
at runtime.

Returns undef if no value is found.  Returns the offset if it is
found.

=cut

# Provides a reusable way to read the truncation offset in an IPSv2 patch.

sub read_truncation_point {
    my ($self, $fh) = @_;

    # Use the default filehandle unless one has been passed.

    $fh = $self->get_patch_filehandle() unless $fh;

    # The truncation point is at the end, so the position is adjusted.

    seek $fh, -3, SEEK_END;

    # Prevent the wrong data from being loaded as the truncation offset.

    my $truncation_point;
    unless ( read($fh, $truncation_point, IPSv2_TRUNCATION_OFFSET_SIZE)
        == IPSv2_TRUNCATION_OFFSET_SIZE ) {
        croak "read(): Error checking for Lunar IPS patch";
    }

    # Indicate we accidently looked for a truncation point in an IPSv1 patch.

    return if $truncation_point eq 'EOF';

    # 24-bit numbers have no template in unpack, so this is done instead.

    return hex unpack "H*", $truncation_point;
}

=item * $ips->truncate_file(*FH)

Truncates the file at the value returned by get_truncation_point.
Default behavior is to truncate the initialized filehandle, but a
filehandle can be passed at runtime and it will be truncated.
Returns the value of the truncate function.

=cut

# Modified files smaller than the originals are truncated in IPSv2.

sub truncate_file {
    my ($self, $fh) = @_;

    # Use the default filehandle unless one was passed.

    $fh = $self->get_patch_filehandle() unless $fh;

    # truncate will not automatically seek to the end of the file.

    seek $fh, 0, SEEK_END;

    # Truncation will ensure the program is IPSv2 compliant.

    return truncate $fh, $self->get_cut_offset();
}

=item * my $success = $ips->check_header($fh)

Check the filehandle provided to see if it points to an IPS patch.
Only checks for "PATCH" in the first five bytes.  Returns 1 if they
match.  Otherwise returns undef.

Default behavior is to check the initialized filehandle, but if a
filehandle is passed at runtime, it will be checked instead.

=cut

# Provide a quick way to see if a file is an IPS patch.

sub check_header {
    my ($self, $patch_filehandle) = @_;

    # Use the default filehandle unless one was provided.

    $patch_filehandle = $self->get_patch_filehandle()
        unless $patch_filehandle;

    # Setting the position to zero ensure we read the correct data.

    seek $patch_filehandle, 0, SEEK_SET;

    # Prevent reading the wrong data in case something happens.

    my $patch_header;
    my $bytes_read = read $patch_filehandle, $patch_header, IPS_HEADER_SIZE;
    unless( $bytes_read == IPS_HEADER_SIZE ) {
        croak "read(): Error reading IPS patch header";
    }

    # Report whether or not this file is an IPS patch.

    return unless $patch_header eq IPS_HEADER;
    return 1;
}

=item * my $success = $ips->is_ips_v2()

Checks for a truncation offset at the end of the patchfile.  Returns
1 if found, otherwise returns undef.

Checks the initialized filehandle unless a filehandle is passed at
runtime.

=cut

# Checking for a truncation point ensures IPSv2 compliant patching.

sub is_ips_v2 {
    my ($self, $patch_filehandle) = @_;

    # Use default filehandle unless told not to.

    $patch_filehandle = $self->get_patch_filehandle()
        unless $patch_filehandle;

    # Truncation offsets are stored at the end of the patch.

    seek $patch_filehandle, -3, SEEK_END;

    # Make sure we don't read the wrong data in case a read error occurs.

    my $truncation_offset;
    my $bytes_read =  read $patch_filehandle, $truncation_offset,
                           IPSv2_TRUNCATION_OFFSET_SIZE
                           ;

    unless ( $bytes_read == IPSv2_TRUNCATION_OFFSET_SIZE ) {
        croak "read(): Error reading IPS truncation offset";
    }

    return 1;
}


=item * $ips->apply_ips_patch($file, [$ips_patch])

Applies the loaded IPS patch to $file.  If another IPS patch
filename is passed then another IPS object is constructed and
initialized.  apply_ips_patch is then called through that object.

Returns the value of close on $file's filehandle.

=cut

# Provide a method for applying an IPS patch.

sub apply_ips_patch {
    my ($self, $rom_filename, $patch_filename) = @_;

    my $rom_filehandle = $self->_open_file($rom_filename);

    # Find out if another IPS instance has to be constructed.

    if ($patch_filename) {
        my $ips = IPS->new( 'patch_filename' => $patch_filename );

        $ips->apply_ips_patch($rom_filename);
    }
    else {

        # This loop provides the means of patching files.

        WRITE_RECORDS: foreach my $record ( $self->get_all_patch_records() ) {
            $record->write_to_file($rom_filehandle);
        }
    }

    # Truncate if needed.
    $self->truncate_file($rom_filehandle) if $self->get_truncation_offset();

    close $rom_filehandle;
}

=item * $ips->write_ips_patch( $other_ips_filename )

Writes an IPS patch to either $other_ips_filename or to whatever is
returned by get_patch_file().  Returns the value of close.

=cut

# Provide a way to write records to a new IPS file.

sub write_ips_patch {
    my ($self, $patch_filename) = @_;

    # Use the default patch filename unless told not to use it.

    $patch_filename = $self->get_patch_filename() unless $patch_filename;

    # Open the file for writing.

    open PATCH, ">$patch_filename"
        or croak "open():  Could not create IPS patch $patch_filename";
    binmode PATCH;

    # Write the header to identify the patch as an IPS patch.

    print PATCH IPS_HEADER;

    # This loop will create the instructions for patching by writing each
    # record to disk.

    foreach my $record ( $self->get_all_patch_records() ) {
        $record->write_to_ips_patch(*PATCH)
    }

    # 'EOF' is written at the end of the file to indicate the last record.

    print PATCH 'EOF';

    # A truncation point has to be set if the modified file is smaller.

    print PATCH pack "H*", sprintf "%06X", $self->get_truncation_point()
        if $self->get_truncation_point();

    return close PATCH;
}

=item * $ips->is_rle()

Returns true if the patch is RLE.  Returns undef if not.

=cut

# Provide a way to see if the patch contains at least one RLE record.

sub is_rle {
    my ($self) = @_;

    return $self->{'is_rle'};
}

=item * $ips->set_rle()

Flags the patch for RLE.  Please don't do this anymore.

=cut

# Provide a way to set the current patch to contain RLE records.

sub set_rle {
    my ($self) = @_;

    return $self->{'is_rle'} = 'yes';
}

=item * $ips->not_rle()

Flags the patch as a standard IPS patch.  This is the way to go.

=cut

# Provide a method to set the current patch to not contain RLE records.

sub not_rle {
    my ($self) = @_;

    return $self->{'is_rle'} = undef;
}

=item * $ips->push_record(@records)

Pushes records onto the internal records array.  Returns the number
of records in the array.

=cut

# Implement a push method for the records array.

sub push_record {
    my ($self, @records) = @_;

    return push @{ $self->{'records'} }, @records;
}

=item * $popped_record = $ips->pop_record()

Pops the last record on the internal records array.  Returns the
popped record.

=cut

# Implement a pop method for the records array.

sub pop_record {
    my ($self) = @_;

    return pop @{ $self->{'records'} };
}

=item * $shifted_record = $ips->shift_record()

Shifts the first record off the internal records array.  Returns the
record shifted.

=cut

# Implement a shift method for the records array.

sub shift_record {
    my ($self) = @_;

    return shift @{ $self->{'records'} };
}

=item * $ips->unshift_record(@records)

Unshifts the records to the beginning of the internal records array.
Returns the number of items in the records array.

=cut

# Implement an unshift method for the records array.

sub unshift_record {
    my ($self, @records) = @_;

    return unshift @{ $self->{'records'} }, @records;
}

=item * $ips->get_patch_file()

Returns the path to the patch file.

=item * $ips->set_patch_file( $ips_patch )

Sets the patch file to $ips_patch.

=item * $ips->get_record( @args )

Returns IPS::Records by the array indices passed to it.  Returns a
scalar if only one index is provided.  Returns a list if more than
one index is passed.

=item * $ips->set_record( %args )

Sets the record at the index provided in the hash key to the record
at the hash value.  One can also set one record at a time:

    $ips->set_record( 0    => $record );

Retuns the value of the assignment.

=item * $ips->get_all_records()

Returns a list of all the records in the patch.

=item * $ips->get_truncation_point()

Returns the value of the truncation offset of the patched file.

=item * $ips->set_truncation_point($offset)

Sets the truncation offset off the patched file.

=item * $ips->get_patch_filehandle()

If the IPS instance has been initialized, then this returns the
opened filehandle.  Otherwise returns undef.

=item * $ips->set_patch_filehandle(*FH)

Sets the filehandle for the IPS instance.

=cut

# Modify the package's symbol table to generate anonymous subroutines that
# provide access to simple attribute data.

BEGIN {
    no strict 'refs';

    my @scalar_methods = (
        'patch_filename',
        'truncation_offset',
        'patch_filehandle',
    );

    # Iterating over an array of method names allows easier addition of
    # new accessors.

    foreach my $method (@scalar_methods) {
        my $get_method = "get_$method";
        my $set_method = "set_$method";

        # Build an accessor to retrieve attributes.

        *{__PACKAGE__."::$get_method"} = sub {
            my ($self) = @_;

            return $self->{$method};
        };

        # Build an accessor to set attributes.

        *{__PACKAGE__."::$set_method"} = sub {
            my ($self, $arg) = @_;

            return $self->{$method} = $arg;
        };
    }

    my @array_methods = (
        'patch_record',
    );

    foreach my $method (@array_methods) {
        my $get_method      = "get_$method",
        my $set_method      = "set_$method";
        my $get_all_method  = "get_all_${method}s";

        *{__PACKAGE__."::$get_method"} = sub {
            my ($self, @args) = @_;

            # A scalar receiving a list containing one element would assign
            # incorrectly, so map isn't used in that case.

            return $self->{ "${method}s" }->[ $args[0] ] if @args == 1;

            # This allows retrieving elements in any order we choose.

            return map { $self->{ "${method}s" }->[$_] } @args;
        };

        *{__PACKAGE__."::$set_method"} = sub {
            my ($self, %args) = @_;

            # Set this way so we can pass a hash of values to be stored in
            # any order we want.

            foreach my $key ( keys %args ) {
                $self->{ "${method}s" }->[$key] = $args{$key};
            }

            return 1;
        };

        *{__PACKAGE__."::$get_all_method"} = sub {
            my ($self) = @_;

            return @{ $self->{ "${method}s" } };
        };
    }
}

1;

=back

=head1 AUTHOR

chinesefood (eat.more.chinese.food@gmail.com)

=head1 HOMEPAGE

L<http://github.com/chinesefood/ips.pl/tree/master>

=head1 COPYRIGHT

Copyright 2003, 2009 chinesefood

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

This work is based on ips.pl v0.01.

=head1 SEE ALSO

IPS::Record

=cut
