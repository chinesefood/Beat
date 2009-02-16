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
		'rle_length'		=> undef,

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
