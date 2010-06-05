package IPS::Record;


use strict;
use warnings;
use diagnostics;


use Carp;


use IPS::Record::Header;
use IPS::Record::V1;
use IPS::Record::RLE;
use IPS::Record::EOF;
use IPS::Record::V2;





sub new {
    my ($class, $args_ref) = @_;

    my $self = bless \do { my $anon_scalar }, ref($class) || $class;

    if (defined $args_ref->{'filehandle'}) {
        return $self->_init($args_ref);
    }

    return $self;
}








{
    sub _init {
        my ($self, $args_ref) = @_;

        my ($init_pos, $cur_pos, $file_size);
        my $fh = $args_ref->{'filehandle'};

        
        $init_pos = $fh->tell();
        $cur_pos = $init_pos;
        $file_size = $fh->get_size();

        
        my $is_header = $self->_check_for_header($fh);
        my $is_v2     = $self->_check_for_v2($fh);
        my $is_eof    = $self->_check_for_eof($fh);
        
        
        if ($is_header) {
            return IPS::Record::Header->new($args_ref);
        }
        elsif ($cur_pos == $file_size) {
            return undef;
        }
        elsif (!$is_v2 && !$is_eof) {
            if ($self->_check_for_rle($fh)) {
                return IPS::Record::RLE->new($args_ref);
            }

            return IPS::Record::V1->new($args_ref);
        }

        if ($is_v2) {
            return [
                IPS::Record::EOF->new($args_ref),
                IPS::Record::V2->new($args_ref),
            ];
        }

        return IPS::Record::EOF->new($args_ref);
    }
    
    
    
    
    



    sub _check_for_header {
        my ($self, $fh) = @_;
        
        
        if ($fh->tell() == 0) {
            return 1;
        }
        
        return 0;
    }








    sub _check_for_rle {
        my ($self, $fh) = @_;


        my $init_pos = $fh->tell();
        
        $fh->seek($init_pos + 3);

        my $flag = $fh->read({
            'length'        => IPS::Record::V1::IPS_RECORD_SIZE_LENGTH,
        });

        $flag = hex unpack "H*", $flag;

        $fh->seek($init_pos);

        if ($flag == 0) {
            return 1;
        }

        return 0;
    }








    sub _check_for_eof {
        my ($self, $fh) = @_;
        
        
        if ($fh->get_size() - $fh->tell() == 3) {
            return 1;
        }


        return 0;
    }








    sub _check_for_v2 {
        my ($self, $fh) = @_;
        
        
        if ($fh->get_size() - $fh->tell() == 6) {
            return 1;
        }


        return 0;
    }
}

1;
