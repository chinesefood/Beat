package Beat::File;


use strict;
use warnings;
use diagnostics;


use IO::File;
use Carp;




my %fh_of;








sub new {
    my ($class, $args_ref) = @_;

    my $self = bless \do { my $anon_scalar }, ref($class) || $class;

    if (defined $args_ref->{'read_from'}) {
        $fh_of{$self} = $self->_open_file({
            'file'  => $args_ref->{'read_from'},
            'mode'  => '<',
        });
    }
    elsif (defined $args_ref->{'write_to'}) {
        $fh_of{$self} = $self->_open_file({
            'file'  => $args_ref->{'write_to'},
            'mode'  => '+<',
        });
    }

    return $self;
}








sub read {
    my ($self, $args_ref) = @_;

    return $self->_read($args_ref);
}








sub write {
    my ($self, $data) = @_;
    
    
    $self->_write($data);
}








sub seek {
    my ($self, $p) = @_;


    $self->_seek($p);
}








sub tell {
    my ($self) = @_;

    return $self->_tell();
}








sub get_size {
    my ($self) = @_;


    return $self->_get_size();
}








sub get_line {
    my ($self) = @_;
    
    
    return $self->_get_line();
}








sub truncate {
    my ($self, $o) = @_;
    
    
    CORE::truncate($fh_of{$self}, $o);
}








{
    sub _open_file {
        my ($self, $args_ref) = @_;


        my $fh = IO::File->new(
            $args_ref->{'file'},
            $args_ref->{'mode'},
        );

        if (!defined $fh) {
            croak "Error opening $args_ref->{'file'}";
        }


        binmode $fh;

        return $fh;
    }








    sub _read {
        my ($self, $args_ref) = @_;
        
        
        my $num_bytes_read = CORE::read(
            ${$fh_of{$self}},
            my $data,
            $args_ref->{'length'},
        );
        
        unless ($num_bytes_read == $args_ref->{'length'}) {
            croak "Incorrect number of bytes read";
        }
        
        return $data;
    }








    sub _write {
        my ($self, $data) = @_;
        
        
        print {$fh_of{$self}} $data;
    }
    
    
    
    
    
    
    
    
    sub _seek {
        my ($self, $p) = @_;


        $fh_of{$self}->seek($p, SEEK_SET);
    }








    sub _tell {
        my ($self) = @_;


        return $fh_of{$self}->tell();
    }








    sub _get_size {
        my ($self) = @_;


        return (-s $fh_of{$self});
    }
    
    
    
    
    
    
    
    
    sub _get_line {
        my ($self) = @_;
        
        
        return readline $fh_of{$self};
    }
}








sub DESTROY {
    my ($self) = @_;
    
    
    delete $fh_of{$self};
}


1;