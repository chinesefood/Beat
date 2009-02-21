package IPS;

use strict;
use warnings;

use constant IPS_HEADER					=> 'PATCH';
use constant IPS_HEADER_SIZE			=> 5;
use constant IPS_DATA_OFFSET_SIZE		=> 3;
use constant IPS_DATA_SIZE				=> 2;

use constant IPS_RLE_LENGTH				=> 2;
use constant IPS_RLE_DATA_SIZE			=> 1;

use constant LUNAR_IPS_TRUNCATE_SIZE	=> 3;

use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
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

	patch_file       => $filename	# Specify an IPS patch.
	                                # Required for initialization.
	                                #
	patch_filehandle => $fh         # Filehandle optionially used in
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

sub new {
	my ($class, %args) = @_;

	my $self = {
		'is_rle'			=> undef,
		'patch_file'		=> undef,
		'patch_filehandle'	=> undef,
		'cut_offset'		=> undef,

		'records'			=> [],
	};

	foreach my $key ( keys(%args) ) {
		$self->{$key} = $args{$key} if exists $self->{$key};
	}

	bless($self, ref($class) || $class);

	$self->init() if $self->get_patch_file();

	return $self;
}

=item * $ips->init()

Sets the patch filehandle, checks the IPS patch header, and reads
the patch records into memory.  Also detects a truncation value.

=cut

sub init {
	my ($self) = @_;

	my $fh_patch = $self->_open_file( $self->get_patch_file() );
	$self->set_patch_filehandle( $fh_patch );

	unless( $self->check_header() ) {
		croak("Header mismatch; " . $self->get_patch_file() . " not an IPS patch");
	}

	$self->read_records($fh_patch);

	if ( $self->is_lunar_ips() ) {
		my $truncation_point = $self->read_truncation_point();

		$self->set_truncation_point( $truncation_point );
	}
}

=item * $ips->read_records(*FH)

Reads and sets the patch records from the patch filehandle set or by
a filehandle passed at runtime.

=cut

sub read_records {
	my ($self, $fh) = @_;

	my $fh_position = 5;
	seek($fh, $fh_position, SEEK_SET);

	READ_RECORDS: for (my $i = 0; ; $i++) {
		my $record = IPS::Record->new(
			'num'			=> $i,
			'record_offset'	=> $fh_position,
			'ips_patch'		=> $self,
		);

		last READ_RECORDS if $record->read_rom_offset eq 'EOF';

		$record->memorize_data();

		$self->set_record($i => $record);

		$fh_position += IPS_DATA_OFFSET_SIZE + IPS_DATA_SIZE;

		if ( $record->is_rle() ) {
			$fh_position += IPS_RLE_LENGTH + IPS_RLE_DATA_SIZE;
		}
		else {
			$fh_position += $record->get_data_size();
		}
	}
}

{
	sub _open_file {
		my ($self, $file) = @_;

		unless ( open( FH, "+<$file" ) ) {
			croak("Could not open() " . $file . " for read/write access");
		}
		binmode(FH);

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

sub read_truncation_point {
	my ($self, $fh) = @_;
	$fh = $self->get_patch_filehandle() unless $fh;

	seek($fh, -3, SEEK_END);

	my $truncation_point;
	unless ( read($fh, $truncation_point, LUNAR_IPS_TRUNCATE_SIZE) == LUNAR_IPS_TRUNCATE_SIZE ) {
		croak("read(): Error checking for Lunar IPS patch");
	}

	return if $truncation_point eq 'EOF';

	return hex( unpack("H*", $truncation_point) );
}

=item * $ips->truncate_file(*FH)

Truncates the file at the value returned by get_truncation_point.
Default behavior is to truncate the initialized filehandle, but a
filehandle can be passed at runtime and it will be truncated.
Returns the value of the truncate function.

=cut

sub truncate_file {
	my ($self, $fh) = @_;
	$fh = $self->get_patch_filehandle() unless $fh;

	seek($fh, 0, SEEK_END);

	return truncate( $fh, $self->get_cut_offset() );
}

=item * my $success = $ips->check_header($fh)

Check the filehandle provided to see if it points to an IPS patch.
Only checks for "PATCH" in the first five bytes.  Returns 1 if they
match.  Otherwise returns undef.

Default behavior is to check the initialized filehandle, but if a
filehandle is passed at runtime, it will be checked instead.

=cut

sub check_header {
	my ($self, $fh) = @_;
	$fh = $self->get_patch_filehandle() unless $fh;

	seek($fh, 0, SEEK_SET);
	my $header;
	unless( read($fh, $header, IPS_HEADER_SIZE) == IPS_HEADER_SIZE ) {
		croak("read(): Error reading IPS patch header");
	}

	return unless $header eq IPS_HEADER;
	return 1;
}

=item * my $success = $ips->is_lunar_ips()

Checks for a truncation offset at the end of the patchfile.  Returns
1 if found, otherwise returns undef.

Checks the initialized filehandle unless a filehandle is passed at
runtime.

=cut

sub is_lunar_ips {
	my ($self, $fh) = @_;
	$fh = $self->get_patch_filehandle() unless $fh;

	seek($fh, -3, SEEK_END);

	my $truncation_point;
	unless ( read($fh, $truncation_point, LUNAR_IPS_TRUNCATE_SIZE) == LUNAR_IPS_TRUNCATE_SIZE ) {
		return;
	}

	return 1;
}


=item * $ips->apply_ips_patch($file, [$ips_patch])

Applies the loaded IPS patch to $file.  If another IPS patch
filename is passed then another IPS object is constructed and
initialized.  apply_ips_patch is then called through that object.

Returns the value of close on $file's filehandle.

=cut

sub apply_ips_patch {
	my ($self, $rom_file, $patch_file) = @_;

	my $fh_rom = $self->_open_file($rom_file);

	if ( $patch_file ) {
		my $ips = IPS->new( 'patch_file' => $patch_file );

		$ips->apply_ips_patch($rom_file);
	}
	else {
		WRITE_RECORDS: foreach my $record ( $self->get_all_records() ) {
			$record->write_to_file($fh_rom);
		}
	}

	$self->truncate_file($fh_rom) if $self->get_truncation_point();
	return close($fh_rom);
}

=item * $ips->write_ips_patch( $other_ips_filename )

Writes an IPS patch to either $other_ips_filename or to whatever is
returned by get_patch_file().  Returns the value of close.

=cut

sub write_ips_patch {
	my ($self, $ips_filename) = @_;

	$ips_filename = $self->get_patch_file() unless $ips_filename;

	open(FH_IPS, ">$ips_filename") or croak("open():  Could not create IPS patch $ips_filename");
	binmode(FH_IPS);

	print FH_IPS IPS_HEADER;

	foreach my $record ( $self->get_all_records() ) {

		# Pretty tough to pack 24 bit unsigned integers.
		print FH_IPS pack("H*", sprintf("%06X", $record->get_rom_offset() ) );

		print FH_IPS pack("H*", sprintf("%04X", $record->get_data_size() ) );

		if ( $record->is_rle() ) {
			print FH_IPS pack("H*", sprintf("%04X", $record->get_rle_length() ) );
		}

		print FH_IPS $record->get_data();
	}

	print FH_IPS 'EOF';
	print FH_IPS pack("H*", sprintf("%06X", $self->get_truncation_point() ) ) if $self->get_truncation_point();

	return close(FH_IPS);
}



=item * $ips->is_rle()

Returns true if the patch is RLE.  Returns undef if not.

=cut

sub is_rle {
	my ($self) = @_;

	return $self->{'is_rle'};
}

=item * $ips->set_rle()

Flags the patch for RLE.  Please don't do this anymore.

=cut

sub set_rle {
	my ($self) = @_;

	return $self->{'is_rle'} = 'yes';
}

=item * $ips->not_rle()

Flags the patch as a standard IPS patch.  This is the way to go.

=cut

sub not_rle {
	my ($self) = @_;

	return $self->{'is_rle'} = undef;
}

=item * $ips->push_record(@records)

Pushes records onto the internal records array.  Returns the number
of records in the array.

=cut

sub push_record {
	my ($self, @records) = @_;

	return push( @{$self->{'records'}}, @records);
}

=item * $popped_record = $ips->pop_record()

Pops the last record on the internal records array.  Returns the
popped record.

=cut

sub pop_record {
	my ($self) = @_;

	return pop( @{$self->{'records'}} );
}

=item * $shifted_record = $ips->shift_record()

Shifts the first record off the internal records array.  Returns the
record shifted.

=cut

sub shift_record {
	my ($self) = @_;

	return shift( @{$self->{'records'}} );
}

=item * $ips->unshift_record(@records)

Unshifts the records to the beginning of the internal records array.
Returns the number of items in the records array.

=cut

sub unshift_record {
	my ($self, @records) = @_;

	return unshift( @{$self->{'records'}}, @records );
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

	$ips->set_record( 0	=> $record );

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

BEGIN {
	no strict 'refs';

	foreach my $method qw(patch_file truncation_point patch_filehandle) {
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

	foreach my $method qw(record) {
		my ($get_method, $set_method, $get_all_method) =
			("get_$method", "set_$method", "get_all_${method}s");

		*{__PACKAGE__."::$get_method"} = sub {
			my ($self, @args) = @_;

			return $self->{"${method}s"}->[ $args[0] ] if @args == 1;

			return map { $self->{"${method}s"}->[$_] } @args;
		};

		*{__PACKAGE__."::$set_method"} = sub {
			my ($self, %args) = @_;

			foreach my $key ( keys(%args) ) {
				$self->{"${method}s"}->[$key] = $args{$key};
			}

			return 1;
		};

		*{__PACKAGE__."::$get_all_method"} = sub {
			my ($self) = @_;

			return @{$self->{"${method}s"}};
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

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

This work is based on ips.pl v0.01.

=head1 SEE ALSO

IPS::Record

=cut
