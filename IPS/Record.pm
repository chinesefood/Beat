package IPS::Record;

use strict;
use warnings;

use Fcntl qw(SEEK_SET);

our $VERSION = 0.01;

BEGIN {
	no strict 'refs';

	foreach my $method qw(data rom_offset data_size rle_length ips_patch) {
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

sub new {
	my ($class, %args) = @_;

	my $self = {
		'num'			=> undef,
		'data'			=> undef,

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

sub is_rle {
	my ($self) = @_;

	return 'yes' if $self->get_data_size() == 0;
	return;
}

sub set_rle {
	my ($self) = @_;

	return $self->set_data_size(0);
}

sub not_rle {
	my ($self) = @_;

	return $self->set_data_size(undef);
}

sub num {
	my ($self, $num) = @_;

	return $self->{'num'} = $num if $num;
	return $self->{'num'};
}

sub write {
	my ($self, $fh_rom) = @_;

	seek($fh_rom, $self->get_rom_offset(), SEEK_SET);

	print $fh_rom $self->get_data() unless $self->is_rle();

	if ( $self->is_rle() ) {
		my $rle_data = $self->get_data();
		print $fh_rom "$rle_data" x $self->get_rle_length();
	}
}

1;

__END__

=head1 NAME

IPS::Record - A package for storing IPS record data.

=head1 SYNOPSIS

	my $r = IPS::Record->new(
		'num'			=> 0,
		'rom_offset'	=> 1234,
		'size'			=> 83,
		'data'			=> $data,
	);

=head1 DESCRIPTION

IPS patches contain a series of records that declare what data should be patched where and how much data is to be patched.  This package provides a container and methods for this data.

=head2 Methods

The interface is not finished.  Do expect changes.

=over 4

=item * $r->new(%args)

Instantiates a new IPS::Record object and returns a reference to that object.  A hash may be passed to override default values:

	'num'			=> 3,		# Record number, does nothing special yet
	'data'			=> $data,	# Raw, packed data to be smashed into an IPS patch

	'rom_offset'	=> 0x0F10,	# Offset declaring where to start patching in the file
	'data_size'		=> 0x100,	# Size of this data to determine where the next record starts in the
								# IPS patch

	'rle_length'	=> undef,	# Length of RLE decoded data

	'ips_patch'		=> $ips,	# Parent IPS object this record belongs to

=item * $r->get_data()

Returns data recovered from IPS patch.

=item * $r->set_data($data)

Sets the IPS data to the value stored in $data.  Returns the value of assignment.

=item * $r->get_rom_offset()

Returns the location of the first byte to be patched in the file.

=item * $r->set_rom_offset($offset)

Sets the location of the first byte to be patched in the file.  This number cannot be greater than 2^24 - 1.  Returns the value of assignment.

=item * $r->get_data_size()

Returns the size in bytes of the data contained in the IPS patch record.

=item * $r->set_data_size($size)

Sets the size in bytes of the data contained in the IPS patch record.  This cannot be larger than 65535.  If set to zero, flags record as RLE.

=item * $r->get_rle_length()

Returns the length in bytes of RLE bytes to patch into the file.

=item * $r->set_rle_length($length)

Sets the length in bytes of RLE bytes to patch into the file.  Cannot be larger than 65535.  Returns the value of assignment.

=item * $r->get_ips_patch()

Returns parent IPS object of this record.

=item * $r->set_ips_patch()

Sets parent IPS object of this record.

=item * $r->num(), $r->num($num)

Returns the record number of the object.  If a number is passed then sets the record number to $num.

=item * $r->is_rle()

Returns 'yes' if the record is RLE.  Returns undef if not.

=item * $r->set_rle()

This method sets the data_size to 0, making the record RLE.

=item * $r->not_rle()

This method sets the data_size to undef, leaving its status to be determined.

=item * $r->write(*FH)

Writes the IPS record to the filehandle passed.  Will write both standard and RLE records.

=back

=head1 AUTHOR

chinesefood (eat.more.chinese.food@gmail.com)

=head1 COPYRIGHT

Copyright 2003, 2009 chinesefood

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

The original author is unknown at the time of release.

=head1 SEE ALSO

IPS

=cut
