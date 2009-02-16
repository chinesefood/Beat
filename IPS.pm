package IPS;

use strict;
use warnings;

use constant IPS_HEADER_LENGTH	=> 5;
use constant IPS_OFFSET_SIZE	=> 3;
use constant IPS_DATA_SIZE		=> 2;

use constant IPS_RLE_LENGTH		=> 2;
use constant IPS_RLE_DATA_SIZE	=> 1;

use Fcntl qw(SEEK_CUR);
use Carp;

use IPS::Record;

our $VERSION = 0.01;

BEGIN {
	no strict 'refs';

	foreach my $method qw(patch_file) {
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

sub new {
	my ($class, %args) = @_;

	my $self = {
		'is_rle'		=> undef,
		'patch_file'	=> undef,

		'records'		=> [],
	};

	foreach my $key ( keys(%args) ) {
		$self->{$key} = $args{$key} if exists $self->{$key};
	}

	bless($self, ref($class) || $class);

	$self->init() if $self->get_patch_file();

	return $self;
}

sub init {
	my ($self) = @_;

	my $fh_patch = $self->_open_file( $self->get_patch_file() );

	unless( $self->check_header($fh_patch) ) {
		croak("Header mismatch; " . $self->get_patch_file() . " not an IPS patch");
	}

	READ_RECORDS: for (my $i = 0; ; $i++) {
		my $rom_offset = $self->_read_rom_offset($fh_patch);
		last READ_RECORDS if $rom_offset eq 'EOF';

		my $data_size = $self->_read_data_size($fh_patch);

		my $record = IPS::Record->new(
			'num'			=> $i,
			'rom_offset'	=> $rom_offset,
			'ips_patch'		=> $self,
			'data_size'		=> $data_size,
		);

		if ( $record->is_rle() ) {
			my $rle_length = $self->_read_rle_length($fh_patch);
			my $rle_data = $self->_read_rle_data($fh_patch);

			$record->set_rle_length($rle_length);
			$record->set_data($rle_data);
		}
		else {
			my $data = $self->_read_data($data_size, $fh_patch);

			$record->set_data($data);
		}

		$self->set_record($i => $record);
	}

	close($fh_patch);
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

	sub _read_rom_offset {
		my ($self, $fh) = @_;

		my $rom_offset;
		unless( read($fh, $rom_offset, IPS_OFFSET_SIZE) == IPS_OFFSET_SIZE ) {
			croak("read():  Error reading ROM offset");
		}

		return 'EOF' if $rom_offset eq 'EOF';

		$rom_offset = hex( unpack("H*", $rom_offset) );

		return $rom_offset;
	}

	sub _read_data_size {
		my ($self, $fh) = @_;

		my $data_size;
		unless( read($fh, $data_size, IPS_DATA_SIZE) == IPS_DATA_SIZE ) {
			croak("read(): Error reading ROM data size");
		}
		$data_size = hex( unpack("H*", $data_size) );

		return $data_size;
	}

	sub _read_rle_length {
		my ($self, $fh) = @_;

		$self->set_rle() unless $self->is_rle();

		my $rle_length;
		unless( read($fh, $rle_length, IPS_RLE_LENGTH) == IPS_RLE_LENGTH ) {
			croak("read(): Error reading RLE size");
		}
		$rle_length = hex( unpack("H*", $rle_length) );

		return $rle_length;
	}

	sub _read_rle_data {
		my ($self, $fh) = @_;

		my $rle_data;
		unless( read($fh, $rle_data, IPS_RLE_DATA_SIZE) == IPS_RLE_DATA_SIZE ) {
			croak("read(): Error reading RLE data");
		}

		return $rle_data;
	}

	sub _read_data {
		my ($self, $data_size, $fh) = @_;

		my $data;
		unless ( read($fh, $data, $data_size) == $data_size ) {
			croak("read(): Error reading data to be copied in the file to be patched");
		}

		return $data;
	}
}

sub check_header {
	my ($self, $fh) = @_;

	my $header;
	unless( read($fh, $header, IPS_HEADER_LENGTH) == IPS_HEADER_LENGTH ) {
		croak("read(): Error reading IPS patch header");
	}

	return unless $header eq 'PATCH';
	return 1;
}

sub patch_file {
	my ($self, $rom_file, $patch_file) = @_;

	my $fh_rom = $self->_open_file($rom_file);

	if ( $patch_file ) {
		my $ips = IPS->new( 'patch_file' => $patch_file );

		$ips->patch_file($rom_file);
	}
	else {
		WRITE_RECORDS: foreach my $record ( $self->get_all_records() ) {
			$record->write($fh_rom);
		}
	}

	close($fh_rom);
}

sub is_rle {
	my ($self) = @_;

	return $self->{'is_rle'};
}

sub set_rle {
	my ($self) = @_;

	return $self->{'is_rle'} = 'yes';
}

sub not_rle {
	my ($self) = @_;

	return $self->{'is_rle'} = undef;
}

1;
