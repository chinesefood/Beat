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








sub eof {
    my ($self) = @_;
    
    
    return $fh_of{$self}->eof();
}








sub get_char {
    my ($self) = @_;
    
    
    return $self->read({
        'length'    => 1,
    });
}








{
    sub _open_file {
        my ($self, $args_ref) = @_;

        my $f = $args_ref->{'file'};
        my $m = $args_ref->{'mode'};
        
        
        if (!(-e $f)) {
            $m = '>';
        }
        
        
        my $fh = IO::File->new(
            $f,
            $m,
        );

        if (!defined $fh) {
            croak "Error opening $args_ref->{'file'}";
        }


        binmode $fh;

        return $fh;
    }








    sub _read {
        my ($self, $args_ref) = @_;
        
        
        if (defined $args_ref->{'offset'}) {
            $self->seek($args_ref->{'offset'});
        }
        
        
        my $size = $args_ref->{'length'};
        
        
        my $num_bytes_read = CORE::read(
            ${$fh_of{$self}},
            my $data,
            $size,
        );
        
        unless ($num_bytes_read == $size) {
            croak "Incorrect number of bytes read: $num_bytes_read bytes read "
                . "when expecting $args_ref->{'length'}";
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