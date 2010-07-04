package Beat;


use strict;
use warnings;
use diagnostics;


use Carp;
use Fcntl qw(:seek);


use Beat::Record;
use Beat::File;
use Beat::Diff;
use Beat::V1;
use Beat::V2;

use constant START_OF_FILE => 0;


my %filename_of;    # Stores filenames of objects

my $header = Beat::Record::Header->new();
my $eof    = Beat::Record::EOF->new();

sub new {
    my ($class, $args_ref) = @_;
    
    my $self = bless [], ref($class) || $class;
    
    return $self->_init($args_ref);
}








# sub make_rle {
    # my ($self, $args_ref) = @_;

    # my $diff = Beat::Diff->new();
    
    # my @records = (
        # $diff->generate_rle_records($args_ref),
    # );
    
    # $self->set_all_records(\@records);
# }








sub make {
    my ($self, $args_ref) = @_;

    my $diff = Beat::Diff->new();
    
    my @records = (
        $diff->generate_records($args_ref),
    );
    
    $self->set_all_records(\@records);
}








sub read {
    my ($self, $args_ref) = @_;


    my $fh;

    if ($args_ref->{'filename'}) {
        $fh = Beat::File->new({
            'read_from' => $args_ref->{'filename'},
        });
    }
    else {
        $fh = Beat::File->new({
            'read_from'  => $self->get_filename()
        });
    }


    if ($fh->get_size() == 0) {
        return undef;
    }


    $self->load_records({
        'filehandle'    => $fh,
    });

    return 1;
}








sub write {
    my ($self, $args_ref) = @_;


    my $fh = Beat::File->new({
        'write_to'  => $self->get_filename(),
    });

    if (defined $args_ref->{'filename'}) {
        $fh = Beat::File->new({
            'write_to'  => $args_ref->{'filename'},
        });
    }
    
    my ($v2) = grep { ref $_ eq 'Beat::Record::V2' } ($self->get_all_records());
    
    foreach my $r ($header, $self->get_all_records(), $eof) {
        if (defined($v2) && $r == $v2) {
            next;
        }
        
        $r->write({
            'filehandle'    => $fh,
        });
    }
    
    if ($v2) {
        $v2->write({'filehandle'    => $fh});
    }
}








sub patch {
    my ($self, $args_ref) = @_;
    
    
    my $fh = Beat::File->new({
        'write_to'  => $args_ref->{'filename'},
    });
    
    my ($v2) = grep { ref $_ eq 'Beat::Record::V2' } ($self->get_all_records());
    
    foreach my $r ($self->get_all_records()) {
        if (defined($v2) && $r == $v2) {
            next;
        }
        
        $r->patch({
            'filehandle'    => $fh
        });
    }
    
    if ($v2) {
        $v2->patch({'filehandle'    => $fh});
    }
}








sub get_record {
    my ($self, @r) = @_;
    

    if (@r == 1) {
        return $self->[shift @r];
    }

    return map { $self->[$_] } ( @r );
}








sub set_record {
    my ($self, $args_ref) = @_;


    foreach my $i (keys %$args_ref) {
        $self->[$i] = $args_ref->{$i};
    }
}








sub get_all_records {
    my ($self) = @_;

    return @{$self};
}








sub set_all_records {
    my ($self, $r_ref) = @_;
    
    splice @$self, 0;
    
    $self->push_record(@$r_ref);
}






    
    
sub get_filename {
    my ($self) = @_;

    return $filename_of{$self};
}








sub set_filename {
    my ($self, $filename) = @_;

    $filename_of{$self} = $filename;
}








sub push_record {
    my ($self, @r) = @_;


    push @$self, @r;
}








sub pop_record {
    my ($self) = @_;


    return pop @$self;
}








sub shift_record {
    my ($self) = @_;


    return shift @$self;
}








sub unshift_record {
    my ($self, @r) = @_;


    unshift @$self, @r;
}








sub push_patch_record {
    my ($self, @r) = @_;
    
    
    my $eof = $self->pop_record();
    
    $self->push_record(@r, $eof);
}







sub pop_patch_record {
    my ($self) = @_;
    
    
    my $eof = $self->pop_record();
    
    my $r = $self->pop_record();
    
    $self->push_record($eof);
    
    return $r;
}








{
    sub _init {
        my ($self, $args_ref) = @_;

        my $of       = $args_ref->{'old_file'};
        my $nf       = $args_ref->{'new_file'};
        my $f        = $args_ref->{'filename'};
        my $records  = $args_ref->{'records'};
        
        $self->set_filename($f);
        
        if ($of and $nf) {
            $self->make($args_ref);
            return $self;
        }

        if (defined $records) {
            $self->push_record(@$records);
            return $self;
        }
        
        
        my $fh;
        if (defined $f) {
            $fh = Beat::File->new({
                'read_from' => $f,
            });
        }

        if ($fh && $fh->get_size() == 0) {
            return $self;
        }


        my @records;
        my $is_v2 = 0;

        my $r;
        while ($fh && ($r = Beat::Record->new({'filehandle'    => $fh}))) {
            my $class = ref $r;

            if ($class eq 'ARRAY') {
                $is_v2 = 1;

                push @records, $r->[1];
                
                last;
            }
            elsif ($class eq 'Beat::Record::Header') {
                next;
            }
            elsif ($class eq 'Beat::Record::EOF') {
                last;
            }
            else {
                push @records, $r;
            }
        }

        if ($is_v2) {
            my $v2 = Beat::V2->new({
                %$args_ref,
                'records'   => \@records,
            });
            
            my ($v2r) = grep { ref($_) eq 'Beat::Record::V2' } (@records);
            
            if ($v2r) {
                $v2->set_truncation_offset($v2r->get_offset());
            }
            else {
                croak "Could not find truncation offset";
            }
            
            return $v2;
        }
        else {
            return Beat::V1->new({
                %$args_ref,
                'records'   => \@records,
            });
        }
    }
}


sub DESTROY {
    my ($self) = @_;
    
    delete $filename_of{$self};
}    

    
1;
