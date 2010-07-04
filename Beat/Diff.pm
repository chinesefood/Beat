package Beat::Diff;


use strict;
use warnings;
use diagnostics;

use Carp;
use List::Util qw(sum);


use Beat::File;
use Beat::Record::V1;
use Beat::Record::V2;
use Beat::Record::RLE;


sub new {
    my ($class, $args_ref) = @_;


    return bless \do { my $anon_scalar; }, ref($class) || $class;
}








sub generate_records {
    my ($self, $args_ref) = @_;
    
    
    my @records = $self->_make_records($args_ref);


    if ($self->_needs_v2($args_ref)) {
        push @records, $self->_make_v2_record($args_ref);
    }

    return @records;
}



# sub generate_rle_records {
    # my ($self, $args_ref) = @_;
    
    
    # my @records = $self->_make_records($args_ref);
    # my @rle_records;
    
    # for (my $i = 0; $i < @records; $i++) {
        # my $r = $records[$i];
        
        # my @rle = $self->_make_rle_records($r->get_data, $r->get_offset());
        
        # push @rle_records, @rle;
    # }
    
    
    # if ($self->_needs_v2($args_ref)) {
        # push @rle_records, $self->_make_v2_record($args_ref);
    # }
    
    # return @rle_records;
# }





{
    sub _make_records {
        my ($self, $args_ref) = @_;

        my ($of, $nf) = $self->_open_files($args_ref);

        my @deltas;

        
        my $is_v2 = 0;
        if ($of->get_size() > $nf->get_size()) {
            $is_v2 = 1;
        }

        my $new_is_larger = 0;
        if ($of->get_size() < $nf->get_size()) {
            $new_is_larger = 1;
        }

        my $file_size = ($new_is_larger) ? $nf->get_size() : $of->get_size();

        my $offset = 0;

        while (!$of->eof() && !$nf->eof()) {
            my $chunk_size = 2 ** 16;

            if ($of->get_size() - $of->tell() < 2 ** 16) {
                $chunk_size = $of->get_size() - $of->tell();
            }

            if ($nf->get_size() - $nf->tell() < $chunk_size) {
                $chunk_size = $nf->get_size() - $nf->tell();
            }


            my $of_chunk = $of->read({
                'length'    => $chunk_size,
            });

            my $nf_chunk = $nf->read({
                'length'    => $chunk_size,
            });


            FIND_DELTAS:
            for (my $i = 0; $i < $chunk_size;) {
                if (substr($of_chunk, $i, 1) eq substr($nf_chunk, $i, 1)) {
                    $i++;
                    next FIND_DELTAS;
                }


                my $r = Beat::Record::V1->new({
                    'data'      => '',
                    'offset'    => $offset + $i,
                });


                while (substr($of_chunk, $i, 1) ne substr($nf_chunk, $i, 1)) {
                    $$r .= substr($nf_chunk, $i, 1);
                    $i++;
                }

                push @deltas, $r;
            }


            $offset += $chunk_size;
        }


        if ($new_is_larger) {
            my $offset = $nf->tell();

            while (!$nf->eof()) {
                my $chunk_size = 2 ** 16;

                if ($nf->get_size() - $nf->tell() < $chunk_size) {
                    $chunk_size = $nf->get_size() - $nf->tell();
                }

                my $nf_chunk = $nf->read({
                    'length'    => $chunk_size,
                });

                push @deltas, Beat::Record::V1->new({
                    'data'      => $nf_chunk,
                    'offset'    => $offset,
                });

                $offset += $chunk_size;
            }
        }


        return @deltas;
    }








    sub _needs_v2 {
        my ($self, $args_ref) = @_;

        my ($of, $nf) = $self->_open_files($args_ref);
        
        
        if ($of->get_size() > $nf->get_size()) {
            return 1;
        }

        return 0;
    }








    sub _make_v2_record {
        my ($self, $args_ref) = @_;
        
        my (undef, $nf) = $self->_open_files($args_ref);
        
        
        return Beat::Record::V2->new({
            'offset'    => $nf->get_size(),
        });
    }
    
    
    
    
    
    
    
    
    sub _open_files {
        my ($self, $args_ref) = @_;
        
        
        my $of = Beat::File->new({
            'read_from' => $args_ref->{'old_file'},
        });
        
        my $nf = Beat::File->new({
            'read_from' => $args_ref->{'new_file'},
        });
        
        return ($of, $nf);
    }
    
    
    
    
    
    
    
    
    # sub _make_rle_records {
        # my ($self, $d, $o) = @_;

        # my @records;

        # my $d_copy = $d;
        # my $o_copy = $o;
        
        # ENCODE:
        # while ($d ne '') {    
            # my $het = Beat::Record::V1->new({
                # 'data'      => '',
                # 'offset'    => $o,
            # });

            # HETEROGENEOUS:
            # while (substr($d, 0, 1) ne substr($d, 1, 1)) {
                # $$het .= substr $d, 0, 1, '';

                # if ($d eq '') {
                    # if (defined $$het) {
                        # push @records, $het;
                    # }

                    # last ENCODE;
                # }
            # }
            
            # if (defined $$het) {
                # $o += length $$het;
                
                # push @records, $het;
            # }

            # my $uni = Beat::Record::RLE->new({
                # 'data'      => '',
                # 'offset'    => $o,
            # });

            # UNIFORM:
            # if (substr($d, 0, 1) eq substr($d, 1, 1)) {
                # $$uni .= substr $d, 0, 1, '';

                # while (substr($$uni, 0, 1) eq substr($d, 0, 1)) {
                    # $$uni .= substr $d, 0, 1, '';
                    # if ($d eq '') {
                        # if ($het ne $records[-1] && defined $$het) {
                            # push @records, $het;
                        # }

                        # push @records, $uni;
                        
                        
                        # last ENCODE;
                    # }
                # }
            # }
            
            # if (defined $$uni) {
                # $o += length $$uni;

                # push @records, $uni;
            # }
        # }

        # if ($d_copy ne join("", map { $$_ } (@records))) {
            # croak "Could not break apart delta properly:\nOriginal:  "
                # . unpack("A*", $d_copy) . "\nRebuilt:   "
                # . unpack("A*", join "", map {$$_} (@records))
                # . "\n";
        # }
        

        # my $length = sum(map { $$_ } (@records));
        
        
        # return @records;
    # }
}


1;
