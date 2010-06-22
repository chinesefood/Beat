package Beat;


use strict;
use warnings;
use diagnostics;


use Carp;
use Fcntl qw(:seek);
use IO::File;


use Beat::Record;
use Beat::File;
use Beat::Diff;
use Beat::V1;
use Beat::V2;

use constant START_OF_FILE => 0;


my %filename_of;    # Stores filenames of objects
my %filehandle_of;  # Stores filehandles for IPS patches
my %records_of;     # Store IPS records



sub new {
    my ($class, $args_ref) = @_;


    my $self = bless \do { my $anon_scalar }, ref($class) || $class;

    if (defined($args_ref->{'filename'})
        or (defined($args_ref->{'old_file'}) and defined($args_ref->{'new_file'}))) {
        return $self->_init($args_ref);
    }

    return $self;
}








sub make {
    my ($self, $args_ref) = @_;

    my $diff = Beat::Diff->new();
    
    my @records = (
        Beat::Record::Header->new(),
        ($diff->generate_records($args_ref)),
        Beat::Record::EOF->new(),
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


    foreach my $r ($self->get_all_records()) {
        $r->write({
            'filehandle'    => $fh,
        });
    }
}








sub patch {
    my ($self, $args_ref) = @_;
    
    
    my $fh = Beat::File->new({
        'write_to'  => $args_ref->{'filename'},
    });
    
    
    foreach my $r ($self->get_all_patch_records()) {
        $r->patch({
            'filehandle'    => $fh
        });
    }
}








sub get_record {
    my ($self, @r) = @_;


    my $records_ref = $records_of{$self};

    if (@r == 1) {
        return $records_ref->[$r[0]];
    }

    return map { $records_ref->[$_] } ( @r );
}








sub set_record {
    my ($self, $args_ref) = @_;


    my $records_ref = $records_of{$self};

    foreach my $i (keys %$args_ref) {
        $records_ref->[$i] = $args_ref->{$i};
    }
}








sub get_all_records {
    my ($self) = @_;

    return @{$records_of{$self}};
}








sub get_all_patch_records {
    my ($self) = @_;


    return grep {
        ref($_) ne 'Beat::Record::Header' &&
        ref($_) ne 'Beat::Record::EOF';
    } $self->get_all_records();
}








sub set_all_records {
    my ($self, $records_ref) = @_;


    $records_of{$self} = $records_ref;
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


    push @{$records_of{$self}}, @r;
}








sub pop_record {
    my ($self) = @_;


    return pop @{$records_of{$self}};
}








sub shift_record {
    my ($self) = @_;


    return shift @{$records_of{$self}};
}








sub unshift_record {
    my ($self, @r) = @_;


    unshift @{$records_of{$self}}, @r;
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
    my %filehandle_of;


    sub _init {
        my ($self, $args_ref) = @_;


        if (defined($args_ref->{'old_file'}) and defined($args_ref->{'new_file'})) {
            $self->make($args_ref);
            return $self;
        }
        
        $records_of{$self} = [];


        my $fh = Beat::File->new({
            'read_from' => $args_ref->{'filename'},
        });

        if ($fh->get_size() == 0) {
            return $self;
        }


        my @records;
        my $is_v2 = 0;

        
        LOAD_RECORDS: {
            my $r = Beat::Record->new({
                'filehandle'    => $fh
            });

            if (!$r) {
                last LOAD_RECORDS;
            }

            if (ref($r) eq 'ARRAY') {
                $is_v2 = 1;

                push @records, @$r;
            }
            else {
                push @records, $r;
            }

            if ($r) {
                redo LOAD_RECORDS;
            }
        }

        if ($is_v2) {
            return Beat::V2->new({
                %$args_ref,
                'records'   => \@records,
            });
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
    delete $filehandle_of{$self};
    delete $records_of{$self};
}    

    
1;
