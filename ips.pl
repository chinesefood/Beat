#!/usr/bin/perl -w

use strict;
use Getopt::Long;

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








BEGIN {
	{
		package IPS;

		use strict;
		use warnings;

		use constant IPS_MAGIC_BYTES	=> 'PATCH';
		use constant IPS_HEADER_LENGTH	=> 5;
		use constant IPS_OFFSET_SIZE	=> 3;
		use constant IPS_DATA_SIZE		=> 2;

		use constant IPS_RLE_LENGTH		=> 2;
		use constant IPS_RLE_DATA_SIZE	=> 1;

		use Fcntl qw(SEEK_CUR);
		use Carp;

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

				return hex( unpack("H*", $rom_offset) );
			}

			sub _read_data_size {
				my ($self, $fh) = @_;

				my $data_size;
				unless( read($fh, $data_size, IPS_DATA_SIZE) == IPS_DATA_SIZE ) {
					croak("read(): Error reading ROM data size");
				}

				return hex( unpack("H*", $data_size) );
			}

			sub _read_rle_length {
				my ($self, $fh) = @_;

				$self->set_rle() unless $self->is_rle();

				my $rle_length;
				unless( read($fh, $rle_length, IPS_RLE_LENGTH) == IPS_RLE_LENGTH ) {
					croak("read(): Error reading RLE size");
				}
				return hex( unpack("H*", $rle_length) );
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

			return unless $header eq IPS_MAGIC_BYTES;
			return 1;
		}

		# Change this to accept a hash.
		sub apply_ips_patch {
			my ($self, $rom_file, $patch_file) = @_;

			my $fh_rom = $self->_open_file($rom_file);

			if ( $patch_file ) {
				my $ips = IPS->new( 'patch_file' => $patch_file );

				$ips->apply_ips_patch($rom_file);
			}
			else {
				WRITE_RECORDS: foreach my $record ( $self->get_all_records() ) {
					$record->write($fh_rom);
				}
			}

			return close($fh_rom);
		}

		sub write_ips_patch {
			my ($self, $ips_filename) = @_;

			$ips_filename = $self->get_patch_file() unless $ips_filename;

			open(FH_IPS, ">$ips_filename") or croak("open():  Could not create IPS patch $ips_filename");
			binmode(FH_IPS);

			print FH_IPS IPS_MAGIC_BYTES;

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

			return close(FH_IPS);
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
	}

	{
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
	}
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