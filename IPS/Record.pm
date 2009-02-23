package IPS::Record;

use strict;
use warnings;

use constant IPS_DATA_OFFSET_SIZE       => 3;
use constant IPS_DATA_SIZE              => 2;
use constant IPS_DATA_POSITION
    => IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE;

use constant IPS_RLE_LENGTH             => 2;
use constant IPS_RLE_LENGTH_POSITION    => IPS_DATA_POSITION;
use constant IPS_RLE_DATA_SIZE          => 1;
use constant IPS_RLE_DATA_POSITION
    => IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE + IPS_RLE_LENGTH;

use Fcntl qw(SEEK_SET);
use Carp;

our $VERSION = 0.01;


=head1 NAME

IPS::Record - A package for storing IPS record data.

=head1 SYNOPSIS

    my $r = IPS::Record->new(
        'num'           => 0,
        'rom_offset'    => 1234,
        'size'          => 83,
        'data'          => $data,
    );

=head1 DESCRIPTION

IPS patches contain a series of records that declare what data
should be patched where and how much data is to be patched.  This
package provides a container and methods for this data.

=head2 Methods

The interface is not finished.  Do expect changes.

=over 4

=item * $r->new(%args)

Instantiates a new IPS::Record object and returns a reference to
that object.  A hash may be passed to override default values:

    'num'           => 3,       # Record number, does nothing
                                # special yet
    'data'          => $data,   # Raw, packed data to be smashed
                                # into an IPS patch
    'rom_offset'    => 0x0F10,  # Offset declaring where to start
                                # patching in the file
    'data_size'     => 0x100,   # Size of this data to determine
                                # where the next record starts in
                                # the IPS patch
    'rle_length'    => undef,   # Length of RLE decoded data
    'ips_patch'     => $ips,    # Parent IPS object this record
                                # belongs to

=cut

# Construct a new IPS::Record instance.

sub new {
    my ($class, %args) = @_;

    # Supply default instance data.

    my $self = {

        # The record number.

        'num'           => undef,

        # The packed data loaded from the patch.

        'data'          => undef,

        # The file offset of the record in the IPS patch.

        'record_offset' => undef,

        # The file offset of the data to be patched.

        'rom_offset'    => undef,

        # The size of the data held in the patch.

        'data_size'     => undef,

        # Flag indicating if the record is a RLE record.

        'is_rle'        => undef,

        # Length of the RLE data in the new file.

        'rle_length'    => undef,

        # Holds the object to which the IPS record is associated.

        'ips_patch'     => undef,
    };

    # Replaces the default data with data passed at runtime.

    foreach my $key ( keys %args ) {
        $self->{$key} = $args{$key} if exists $self->{$key};
    }

    return bless $self, ref $class || $class;
}

=item * $r->is_rle()

Returns 'yes' if the record is RLE.  Returns undef if not.

=cut

# Writing and applying patches depends on determining if the record is RLE.

sub is_rle {
    my ($self) = @_;

    # A data size of zero is not used in IPSv1 patches, so it marks RLE data.

    return 'yes' if $self->get_data_size() == 0;
    return;
}

=item * $r->set_rle()

This method sets the data_size to 0, making the record RLE.

=cut

# The user should be able to decide whether or not they want RLE records.

sub set_rle {
    my ($self) = @_;

    # A data size of zero marks the record RLE.

    return $self->set_data_size(0);
}

=item * $r->not_rle()

This method sets the data_size to undef, leaving its status to be
determined.

=cut

sub not_rle {
    my ($self) = @_;

    # A data size of undef marks the record uninitialized.

    return $self->set_data_size(undef);
}

=item * $r->num(), $r->num($num)

Returns the record number of the object.  If a number is passed then
sets the record number to $num.

=cut

# A record number might be useful in writing patches in order later.

sub num {
    my ($self, $num) = @_;

    return $self->{'num'} = $num if $num;
    return $self->{'num'};
}

=item * $r->write_to_file(*FH)

Write the record to the filehandle opened by the IPS object or the
optional filehandle passed at runtime.  Returns true if writing is
successful.

=cut

# To experience the fruit of one's labor, provide a way to patch a file.

sub write_to_file {
    my ($self, $fh_rom) = @_;

    # The filehandle passed is set to the file offset to ensure accuracy.

    seek $fh_rom, $self->get_rom_offset(), SEEK_SET;

    # RLE records have a different structure and must be patched differently.

    print $fh_rom $self->get_data() unless $self->is_rle();

    # Implement run length decoding for patching accuracy.

    if ( $self->is_rle() ) {

        # RLE data and unencoded data are stored in the same attribute.
        my $rle_data = $self->get_data();

        # Repeat the string the specified number of times to ensure accuracy.

        print $fh_rom "$rle_data" x $self->get_rle_length();
    }

    return 1;
}

=item * $r->write_to_ips_patch(*FH)

Writes the IPS record to either the internal filehandle or the
filehandle passed.

=cut

# IPS patches are shared with others, so provide a way to write patches.

sub write_to_ips_patch {
    my ($self, $fh) = @_;

    # Can use the default patch filehandle unless otherwise specified.

    $fh = $self->get_ips_patch()->get_patch_filehandle() unless $fh;

    # Load record data for writing.

    my $rom_offset  = $self->get_rom_offset();
    my $data_size   = $self->get_data_size();
    my $rle_length  = $self->get_rle_length();
    my $patch_data  = $self->get_data();

    # Pack the values to ensure the right values are written to the patch.

    foreach my $patch_value ($rom_offset, $data_size, $rle_length) {
        $patch_value = pack "H*", sprintf "%06X", $patch_value;
    }

    # Writing RLE records is a different process, so test for it.

    if ( $self->is_rle() ) {
        print $fh $rom_offset, $data_size, $rle_length, $patch_data;
    }
    else {
        print $fh $rom_offset, $data_size, $patch_data;
    }
}

=item * $r->read_rom_offset()

For this IPS record, the ROM offset is read from the filehandle
opened by IPS::init().  The offset is returned.

=cut

# Reading the offset from the IPS patch ensurce patching is done accurately.

sub read_rom_offset {
    my ($self) = @_;

    # The record doesn't know where to read, so let the programmer know.

    unless ( $self->get_ips_patch() ) {
        croak("This record is not associated with an IPS object");
    }

    # We want to use the patch filehandle associated with the record.

    my $fh = $self->get_ips_patch()->get_patch_filehandle();

    # The filehandle position could be anywhere, so save it and correct it.

    _hold_fh_position( $fh, $self->get_record_offset() );

    # Read the data and check if it's correct.

    my $rom_offset;
    my $bytes_read = read($fh, $rom_offset, IPS_DATA_OFFSET_SIZE);
    unless( $bytes_read == IPS_DATA_OFFSET_SIZE ) {
        croak "read():  Error reading ROM offset";
    }

    # Return the filehandle position to its previous location to prevent loss.

    _restore_fh_position($fh);

    # Let the program know the last record was already read if we read it.

    return 'EOF' if $rom_offset eq 'EOF';

    # Unpack doesn't have a 24-bit template, so this unpacks correctly.

    return hex unpack "H*", $rom_offset;
}

=item * $r->read_data_size()

The size of the new data stored in the IPS patch is read from the
filehandle provided by the IPS object associated with the record.
The data size is returned.

=cut

#  The data size is used to calculate the position of the next patch record.

sub read_data_size {
    my ($self) = @_;

    # Let them know the record doesn't know where to read from.

    unless ( $self->get_ips_patch() ) {
        croak "This record is not associated with an IPS object";
    }

    # We want to use the patch filehandle associated with the record.

    my $fh = $self->get_ips_patch()->get_patch_filehandle();

    # The filehandle position could be anywhere, so save it and correct it.

    my $data_size_offset = $self->get_record_offset() + IPS_DATA_OFFSET_SIZE;
    _hold_fh_position( $fh, $data_size_offset );

    # Read the data and ensure it's correct.

    my $data_size;
    my $bytes_read = read($fh, $data_size, IPS_DATA_SIZE);
    unless( $bytes_read == IPS_DATA_SIZE ) {
        croak "read(): Error reading ROM data size";
    }

    # Return the filehandle position to its previous location to prevent loss.

    _restore_fh_position($fh);

    # Unpack correctly.

    return hex unpack "H*", $data_size;
}

=item * $r->read_rle_length()

If the record is an RLE record, then this returns the length of the
RLE decoded data from the filehandle opened by IPS::init().

=cut

# The correct RLE length ensures correct data is written to the patched file.

sub read_rle_length {
    my ($self) = @_;

    # Let them know the record doesn't know where to read from.

    unless ( $self->get_ips_patch() ) {
        croak("This record is not associated with an IPS object");
    }

    # We want to use the patch filehandle associated with the record.

    my $fh = $self->get_ips_patch()->get_patch_filehandle();

    # The filehandle position could be anywhere, so save it and correct it.

    my $length_offset = $self->get_record_offset() + IPS_RLE_LENGTH_POSITION;
    _hold_fh_position( $fh, $length_offset );

    # Read the data and ensure it's correct.

    my $rle_length;
    my $bytes_read = read($fh, $rle_length, IPS_RLE_LENGTH);
    unless( $bytes_read == IPS_RLE_LENGTH ) {
        croak "read(): Error reading RLE size";
    }

    # Return the filehandle position to its previous location to prevent loss.

    _restore_fh_position($fh);

    # Unpack correctly.

    return hex unpack "H*", $rle_length;
}

=item * $r->read_rle_data() {

Reads the RLE data byte from the IPS patch file associated with this
record.  Returns the packed data byte.

=cut

# We need to know which byte needs to be repeated in the patched file.

sub read_rle_data {
    my ($self) = @_;

    # Let them know the record doesn't know where to read from.

    unless ( $self->get_ips_patch() ) {
        croak "This record is not associated with an IPS object";
    }

    # We want to use the patch filehandle associated with the record.

    my $fh = $self->get_ips_patch()->get_patch_filehandle();

    # The filehandle position could be anywhere, so save it and correct it.

    my $rle_data_offset = $self->get_record_offset() + IPS_RLE_DATA_POSITION;
    _hold_fh_position( $fh, $rle_data_offset );

    # Read the data and ensure it's correct.

    my $rle_data;
    my $bytes_read = read($fh, $rle_data, IPS_RLE_DATA_SIZE);
    unless( $bytes_read == IPS_RLE_DATA_SIZE ) {
        croak "read(): Error reading RLE data";
    }

    # Return the filehandle position to its previous location to prevent loss.

    _restore_fh_position($fh);

    # The module doesn't need to know the value of the data, so no unpacking.

    return $rle_data;
}

=item * $r->read_data() {

Reads the data from the patch associated with the record and returns
it.

=cut

# The data is read to allow writing to file later.

sub read_data {
    my ($self) = @_;

    # Let them know the record doesn't know where to read from.

    unless ( $self->get_ips_patch() ) {
        croak "This record is not associated with an IPS object";
    }

    # We want to use the patch filehandle associated with the record.

    my $fh = $self->get_ips_patch()->get_patch_filehandle();

    # The filehandle position could be anywhere, so save it and correct it.

    my $data_offset = $self->get_record_offset() + IPS_DATA_POSITION;
    _hold_fh_position( $fh, $data_offset );

    # Since data size isn't a fixed length, the size is read from the patch.

    my $data_size = $self->get_data_size()
        or croak "read_data(): No data size set";

    # Read the data and ensure it's correct.

    my $data;
    my $bytes_read = read($fh, $data, $data_size);
    unless ( $bytes_read == $data_size ) {
        croak "read(): Error reading data to be patched";
    }

    # Set to the original position to prevent unusual behavior.

    _restore_fh_position($fh);

    # The module doesn't need to know what the data is, so it stays packed.

    return $data;
}

=item * $r->memorize_data()

Reads in all data needed to build a proper IPS::Record in memory
from the IPS patch.

=cut

# An easy way to read the patch record into memory.

sub memorize_data {
    my ($self) = @_;

    # The file offset and the data size are the same for all types of records.

    $self->set_rom_offset( $self->read_rom_offset() );
    $self->set_data_size( $self->read_data_size() );

    # Check if the record is RLE and read accordingly.

    if ( $self->is_rle() ) {
        $self->set_rle_length( $self->read_rle_length() );
        $self->set_data( $self->read_rle_data() );
    }
    else {
        $self->set_data( $self->read_data() );
    }

}

# These methods are private to the package.

{
    # The position of the filehandle is just temporary, so it's stored here.

    my $old_fh_position;

    # This code is used often enough to warrant developing a subroutine to
    # remember the previous position of the filehandle about to be worked
    # with.

    sub _hold_fh_position {
        my ($fh, $new_fh_position) = @_;

        # Grab the filehandle position to store it.

        $old_fh_position = tell $fh;

        # Set the new filehandle position to read from the correct offset.

        seek $fh, $new_fh_position, SEEK_SET;
    }

    # Provide a way to reset the filehandle to its old position to prevent
    # wonkiness.

    sub _restore_fh_position {
        my ($fh) = @_;

        # Move the filehandle position to the old position so we can move on.

        seek $fh, $old_fh_position, SEEK_SET;
    }
}

=item * $r->get_data()

Returns data recovered from IPS patch.

=item * $r->set_data($data)

Sets the IPS data to the value stored in $data.  Returns the value
of assignment.

=item * $r->get_rom_offset()

Returns the location of the first byte to be patched in the file.

=item * $r->set_rom_offset($offset)

Sets the location of the first byte to be patched in the file.  This
number cannot be greater than 2^24 - 1.  Returns the value of
assignment.

=item * $r->get_data_size()

Returns the size in bytes of the data contained in the IPS patch
record.

=item * $r->set_data_size($size)

Sets the size in bytes of the data contained in the IPS patch
record.  This cannot be larger than 65535.  If set to zero, flags
record as RLE.

=item * $r->get_rle_length()

Returns the length in bytes of RLE bytes to patch into the file.

=item * $r->set_rle_length($length)

Sets the length in bytes of RLE bytes to patch into the file.
Cannot be larger than 65535.  Returns the value of assignment.

=item * $r->get_ips_patch()

Returns parent IPS object of this record.

=item * $r->set_ips_patch()

Sets parent IPS object of this record.

=item * $r->get_record_offset()

Returns the offset of the record in the IPS patch.

=item * $r->set_record_offset($offset)

Sets the offset in the IPS patch of the current record.

=cut

# Modify the package's symbol table to generate anonymous subroutines that
# provide access to simple attribute data.

BEGIN {
    no strict 'refs';

    my @scalar_methods = (
        'rom_offset',
        'data',
        'data_size',
        'rle_length',
        'ips_patch',
        'record_offset',
    );

    # Iterating over an array of method names allows easier addition of
    # new accessors.

    foreach my $method (@scalar_methods) {
        my ($get_method, $set_method) = (
            "get_$method",
            "set_$method",
        );

        *{__PACKAGE__."::$get_method"} = sub {
            my ($self) = @_;

            return $self->{$method};
        };

        *{__PACKAGE__."::$set_method"} = sub {
            my ($self, $arg) = @_;

            return $self->{$method} = $arg;
        };
    }

    # This is commented out because we have no array attributes at the moment.

    # my @array_methods = (
        # ,
    # );

    # foreach my $method (@array_methods) {
        # my ($get_method, $set_method, $get_all_method) = (
            # "get_$method",
            # "set_$method",
            # "get_all_${method}s",
        # );

        # *{__PACKAGE__."::$get_method"} = sub {
            # my ($self, @args) = @_;

            # return $self->{ "${method}s" }->[ $args[0] ] if @args == 1;

            # return map { $self->{ "${method}s" }->[$_] } @args;
        # };

        # *{__PACKAGE__."::$set_method"} = sub {
            # my ($self, %args) = @_;

            # foreach my $key ( keys %args ) {
                # $self->{ "${method}s" }->[$key] = $args{$key};
            # }

            # return 1;
        # };

        # *{__PACKAGE__."::$get_all_method"} = sub {
            # my ($self) = @_;

            # return @{ $self->{ "${method}s" } };
        # };
    # }
}

1;

__END__

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

This work is based on ips.pl v0.01

=head1 SEE ALSO

IPS

=cut
