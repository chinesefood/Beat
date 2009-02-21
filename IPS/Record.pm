package IPS::Record;

use strict;
use warnings;

use constant IPS_DATA_OFFSET_SIZE	=> 3;
use constant IPS_DATA_SIZE			=> 2;

use constant IPS_RLE_LENGTH			=> 2;
use constant IPS_RLE_DATA_SIZE		=> 1;

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

sub new {
	my ($class, %args) = @_;

	my $self = {
		'num'			=> undef,
		'data'			=> undef,

		'record_offset'	=> undef,
		'rom_offset'	=> undef,
		'data_size'		=> undef,

		'is_rle'		=> undef,
		'rle_length'	=> undef,

		'ips_patch'		=> undef,
	};

	foreach my $key ( keys(%args) ) {
		$self->{$key} = $args{$key} if exists $self->{$key};
	}

	return bless($self, ref($class) || $class);
}

=item * $r->is_rle()

Returns 'yes' if the record is RLE.  Returns undef if not.

=cut

sub is_rle {
	my ($self) = @_;

	return 'yes' if $self->get_data_size() == 0;
	return;
}

=item * $r->set_rle()

This method sets the data_size to 0, making the record RLE.

=cut

sub set_rle {
	my ($self) = @_;

	return $self->set_data_size(0);
}

=item * $r->not_rle()

This method sets the data_size to undef, leaving its status to be determined.

=cut

sub not_rle {
	my ($self) = @_;

	return $self->set_data_size(undef);
}

=item * $r->num(), $r->num($num)

Returns the record number of the object.  If a number is passed then
sets the record number to $num.

=cut

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

sub write_to_file {
	my ($self, $fh_rom) = @_;

	seek($fh_rom, $self->get_rom_offset(), SEEK_SET);

	print $fh_rom $self->get_data() unless $self->is_rle();

	if ( $self->is_rle() ) {
		my $rle_data = $self->get_data();
		print $fh_rom "$rle_data" x $self->get_rle_length();
	}

	return 1;
}

=item * $r->write_to_ips_patch(*FH)

Writes the IPS record to either the internal filehandle or the
filehandle passed.

=cut

sub write_to_ips_patch {
	my ($self, $fh) = @_;
	$fh = $self->get_ips_patch()->get_patch_filehandle() unless $fh;

	my $rom_offset = $self->get_rom_offset();
	my $data_size = $self->get_data_size();
	my $rle_length = $self->get_rle_length();
	my $patch_data = $self->get_data();

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

sub read_rom_offset {
	my ($self) = @_;

	unless ( $self->get_ips_patch() ) {
		croak("This record is not associated with an IPS object");
	}

	my $fh = $self->get_ips_patch()->get_patch_filehandle();
	my $fh_initial_position = tell($fh);
	seek($fh, $self->get_record_offset(), SEEK_SET);

	my $rom_offset;
	unless( read($fh, $rom_offset, IPS_DATA_OFFSET_SIZE) == IPS_DATA_OFFSET_SIZE ) {
		croak("read():  Error reading ROM offset");
	}

	seek($fh, $fh_initial_position, SEEK_SET);

	return 'EOF' if $rom_offset eq 'EOF';
	return hex( unpack("H*", $rom_offset) );
}

=item * $r->read_data_size()

The size of the new data stored in the IPS patch is read from the
filehandle provided by the IPS object associated with the record.
The data size is returned.

=cut

sub read_data_size {
	my ($self) = @_;

	unless ( $self->get_ips_patch() ) {
		croak("This record is not associated with an IPS object");
	}

	my $fh = $self->get_ips_patch()->get_patch_filehandle();
	my $fh_initial_position = tell($fh);
	seek($fh, $self->get_record_offset() + IPS_DATA_OFFSET_SIZE, SEEK_SET);

	my $data_size;
	unless( read($fh, $data_size, IPS_DATA_SIZE) == IPS_DATA_SIZE ) {
		croak("read(): Error reading ROM data size");
	}

	seek($fh, $fh_initial_position, SEEK_SET);

	return hex( unpack("H*", $data_size) );
}

=item * $r->read_rle_length()

If the record is an RLE record, then this returns the length of the
RLE decoded data from the filehandle opened by IPS::init().

=cut

sub read_rle_length {
	my ($self) = @_;

	unless ( $self->get_ips_patch() ) {
		croak("This record is not associated with an IPS object");
	}

	my $fh = $self->get_ips_patch()->get_patch_filehandle();
	my $fh_initial_position = tell($fh);
	seek($fh, $self->get_record_offset() + IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE, SEEK_SET);

	my $rle_length;
	unless( read($fh, $rle_length, IPS_RLE_LENGTH) == IPS_RLE_LENGTH ) {
		croak("read(): Error reading RLE size");
	}

	seek($fh, $fh_initial_position, SEEK_SET);

	return hex( unpack("H*", $rle_length) );
}

=item * $r->read_rle_data() {

Reads the RLE data byte from the IPS patch file associated with this
record.  Returns the packed data byte.

=cut

sub read_rle_data {
	my ($self) = @_;

	unless ( $self->get_ips_patch() ) {
		croak("This record is not associated with an IPS object");
	}

	my $fh = $self->get_ips_patch()->get_patch_filehandle();
	my $fh_initial_position = tell($fh);
	seek($fh, $self->get_record_offset() + IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE + IPS_RLE_LENGTH, SEEK_SET);

	my $rle_data;
	unless( read($fh, $rle_data, IPS_RLE_DATA_SIZE) == IPS_RLE_DATA_SIZE ) {
		croak("read(): Error reading RLE data");
	}

	seek($fh, $fh_initial_position, SEEK_SET);

	return $rle_data;
}

=item * $r->read_data() {

Reads the data from the patch associated with the record and returns
it.

=cut

sub read_data {
	my ($self) = @_;

	unless ( $self->get_ips_patch() ) {
		croak("This record is not associated with an IPS object");
	}

	my $fh = $self->get_ips_patch()->get_patch_filehandle();
	my $fh_initial_position = tell($fh);
	seek($fh, $self->get_record_offset() + IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE, SEEK_SET);

	my $data;
	my $data_size = $self->get_data_size() or croak("read_data(): No data size set");
	unless ( read($fh, $data, $data_size) == $data_size ) {
		croak("read(): Error reading data to be copied in the file to be patched");
	}

	seek($fh, $fh_initial_position, SEEK_SET);

	return $data;
}

=item * $r->memorize_data()

Reads in all data needed to build a proper IPS::Record in memory
from the IPS patch.

=cut

sub memorize_data {
	my ($self) = @_;

	$self->set_rom_offset( $self->read_rom_offset() );
	$self->set_data_size( $self->read_data_size() );

	if ( $self->is_rle() ) {
		$self->set_rle_length( $self->read_rle_length() );
		$self->set_data( $self->read_rle_data() );
	}
	else {
		$self->set_data( $self->read_data() );
	}

}

=item * $r->get_data()

Returns data recovered from IPS patch.

=item * $r->set_data($data)

Sets the IPS data to the value stored in $data.  Returns the value of assignment.

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

BEGIN {
	no strict 'refs';

	foreach my $method qw(rom_offset data data_size rle_length ips_patch record_offset) {
		my ($get_method, $set_method) = ("get_$method", "set_$method");

		*{__PACKAGE__."::$get_method"} = sub {
			my ($self) = @_;

			return $self->{$method};
		};

		*{__PACKAGE__."::$set_method"} = sub {
			my ($self, $arg) = @_;

			return $self->{$method} = $arg;
		};
	}

	# foreach my $method qw() {
		# my ($get_method, $set_method, $get_all_method) =
			# ("get_$method", "set_$method", "get_all_${method}s");

		# *{__PACKAGE__."::$get_method"} = sub {
			# my ($self, @args) = @_;

			# return $self->{"${method}s"}->[ $args[0] ] if @args == 1;

			# return map { $self->{"${method}s"}->[$_] } @args;
		# };

		# *{__PACKAGE__."::$set_method"} = sub {
			# my ($self, %args) = @_;

			# foreach my $key ( keys(%args) ) {
				# $self->{"${method}s"}->[$key] = $args{$key};
			# }

			# return 1;
		# };

		# *{__PACKAGE__."::$get_all_method"} = sub {
			# my ($self) = @_;

			# return @{$self->{"${method}s"}};
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

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

This work is based on ips.pl v0.01

=head1 SEE ALSO

IPS

=cut
