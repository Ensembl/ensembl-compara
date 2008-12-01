package EnsEMBL::Web::Object::DAS::reference;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Features {
    my $self = shift;

    my @segments = $self->Locations;
    my @features;
    my @fts = grep { $_ } @{$self->FeatureTypes || []};

    foreach my $s (@segments) {
    if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
        push @features, $s;
        next;
    }

    my ($region_name, $region_start, $region_end) = ($s->name);
    if ($s->name =~ /^([-\w\.]+):([\.\w]+),([\.\w]+)$/ ) {
        ($region_name,$region_start,$region_end) = ($1,$2,$3);
    }

#    my $slice = $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region('', $region_name, $region_start, $region_end, $s->seq_region_strand); 

    my $slice = $s->slice;

    my $subparts = 'yes';
    my $superparts = 'no';

# Get current coordinate system
    my $current_cs = $slice->coord_system;
    my @coord_systems = ($current_cs);

    if ( ! defined ($region_end)) {
        my $path;
        eval { $path = $slice->project($current_cs->name); };
        if ($path) {
        $path = $path->[0]->to_Slice;
        ($region_start, $region_end) = ($path->start, $path->end);
        }
    }
    my $current_rank = $current_cs->rank;

# Check if there are super and/or sub parts
    my $csa = $slice->coord_system->{adaptor};
    my $higher_cs = $csa->fetch_by_rank($current_rank - 1);
    if ($higher_cs && ! $higher_cs->is_top_level) { 
        push @coord_systems, $higher_cs;
        $superparts = 'yes';
    }

    my $lower_cs = $csa->fetch_by_rank($current_rank + 1);
    if ($lower_cs) { 
        push @coord_systems, $lower_cs;
        if ($lower_cs->is_sequence_level) {
        $subparts = 'no';
        }
    }


    my @segment_features;
    my @projected_segments = @{$slice->project("seqlevel") || []};
    foreach my $psegment (@projected_segments) {
        my $start      = $psegment->from_start;
        my $end        = $psegment->from_end;
        my $ctg_slice  = $psegment->to_Slice;
        my $ORI        = $ctg_slice->strand;
        my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name, 'strand' => $ORI };


        foreach ( @coord_systems ) {
        my $path;
        eval { $path = $ctg_slice->project($_->name); };
        next unless(@$path);
        $path = $path->[0]->to_Slice;
        $feature->{'locations'}{$_->rank} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
        }
        push @segment_features, $feature;
        
    }
    my ($ids, $sids);

    foreach my $f (@segment_features) {
        my $id = $f->{'locations'}{ ($current_rank + 1) }->[0] || next;
        my $start = $f->{'locations'}{ ($current_rank) }->[1];
        my $end = $f->{'locations'}{ ($current_rank) }->[2];
        my $fstrand = $f->{'locations'}{ ($current_rank) }->[3];

        my $target_start = $f->{'locations'}{ ($current_rank + 1) }->[1];
        my $target_end = $f->{'locations'}{ ($current_rank + 1) }->[2];
        
        if (exists($ids->{$id})) {
        $ids->{$id}->[2] = $end;
        $ids->{$id}->[4] = $target_end;
        } else {
        if ($lower_cs) {
            $ids->{$id} = [ $lower_cs->name, $start, $end, $target_start, $target_end, $fstrand ];
        }
        }

        if ($higher_cs && ! $higher_cs->is_top_level) {
        my $id = $f->{'locations'}{ ($current_rank-1) }->[0];
        my $pstart = $f->{'locations'}{ ($current_rank - 1) }->[1];
        my $pend = $f->{'locations'}{ ($current_rank - 1) }->[2];
        my $pstrand = $f->{'locations'}{ ($current_rank - 1) }->[3];

        if (exists($sids->{$id})) {
            $sids->{$id}->[2] = $end;
            $sids->{$id}->[4] = $pend;
        } else {
            $sids->{$id} = [$higher_cs->name, $start, $end, $pstart, $pend, $pstrand,
                    $higher_cs->rank == 1 ? 'no' : 'yes'];
        }

        }
    } 

    my @ss;
    $ids ||= {};
    push @ss, {
        'ID' => $slice->seq_region_name, 
        'START' => $slice->start, 
        'END' => $slice->end,
        'ORIENTATION' => $self->ori( $slice->strand ),  
        'TARGET' => {
          'ID'    => $slice->seq_region_name, 
          'START' => $slice->start, 
          'STOP'   => $slice->end
        },
        'REFERENCE' => 'yes',
        'TYPE' => $current_cs->name, 
        'SUPERPARTS' => $superparts, 
        'SUBPARTS' => %$ids ? 'yes' : 'no', 
        'CATEGORY' => 'component',
        };

    foreach my $id ( keys %$ids ) {
        push @ss, {
        'ID' =>  "$id", 
        'START' => $ids->{$id}->[1], 
        'END' => $ids->{$id}->[2],
        'ORIENTATION' => $self->ori($ids->{$id}->[5]),
        'TARGET' => {
          'ID'    => $id,
          'START' => $ids->{$id}->[3],
          'STOP'   => $ids->{$id}->[4]
        },
        'REFERENCE' => 'yes',
        'TYPE' => $ids->{$id}->[0], 
        'SUBPARTS' => $subparts,
        'SUPERPARTS' => 'yes',
        'CATEGORY' => 'component',
        };
    }

    foreach my $id ( keys %$sids ) {
        push @ss, {
        'ID' =>  "$id", 
        'START' => $sids->{$id}->[1], 
        'END' => $sids->{$id}->[2],
        'ORIENTATION' =>  $self->ori($ids->{$id}->[5]),
        'TARGET' => {
          'ID'    => $id,
          'START' => $sids->{$id}->[3],
          'STOP'   => $sids->{$id}->[4]
        },
        'REFERENCE' => 'yes',
        'TYPE' => $sids->{$id}->[0], 
        'SUPERPARTS' => $sids->{$id}->[6], 
        'SUBPARTS' => 'yes',
        'CATEGORY' => 'supercomponent',
        };
    }


    my @rfeatures = ();
    if (@fts > 0) {
        foreach my $ft (@ss) {
        next unless grep {$_ eq $ft->{'TYPE'}} @fts;
        push @rfeatures, $ft
        }
    } else {
        @rfeatures = @ss;
    }

    push @features, {
        'REGION' => $region_name, 
        'START'  => $region_start, 
        'STOP'   => $region_end,
        'FEATURES' => \@rfeatures
        };
    }


 #   warn(Data::Dumper::Dumper(\@features));

    return \@features;
}

sub Types {
    my ($self) = @_;

    my $collection;
    my $csa = $self->database('core', $self->real_species)->get_CoordSystemAdaptor();

    foreach my $cs (@{$csa->fetch_all()}) {
      push @$collection, { 'id' => $cs->name, 'method' => $cs->version };
    }
    return $collection;
}


sub EntryPoints {
    my ($self) = @_;

    my $slice_adaptor = $self->database('core', $self->real_species)->get_SliceAdaptor();


#    my @chromosome_slices = @{$slice_adaptor->fetch_all('chromosome')};
    my $collection;

    my @toplevel_slices = @{$slice_adaptor->fetch_all('toplevel', undef, 1)};

#    foreach my $chromosome_slice (@chromosome_slices) {
    foreach my $chromosome_slice (@toplevel_slices) {
    my ($ctype, $build, $region, $start, $end, $ori) = split(/:/,$chromosome_slice->name());
    push @$collection, [$region, $start, $end, $ori > 0 ? '+': '-', $region];
    }

    return $collection;
}


sub DNA {
  my $self = shift;
  my @segments = $self->Locations;
  my @features;

  foreach my $s (@segments) {
    if( ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR' ) {
      push @features, $s;
      next;
    }

    my( $region_name, $region_start, $region_end ) = ($s->name);

    if($s->name =~ /^([-\w\.]+):([\.\w]+),([\.\w]+)$/ ) {
      ($region_name,$region_start,$region_end) = ($1,$2,$3);
    }

    unless(defined $region_start ) {
	my $slice = $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region(undef, $region_name, $region_start, $region_end, 1 );
      $region_start = $slice->start;
      $region_end   = $slice->end;
    }

    push @features, {
      'REGION' => $region_name, 
      'START'  => $region_start, 
      'STOP'   => $region_end,

    };
  }

  return \@features;
}

sub Stylesheet { 
  my $self = shift;
  $self->_Stylesheet({
    'component'=> {
                 'chromosome'  => [{
                                    'type'  => 'hidden',
                                  }],
                 'scaffold'    => [{
                                    'type'  => 'box',
                                    'attrs' => { 'fgcolor' => 'darkgreen', 'bgcolor' => 'darkgreen' }
                                  }],
                 'supercontig' => [{
                                    'type'  => 'box',
                                    'attrs' => { 'fgcolor' => 'green', 'bgcolor' => 'green' }
                                  }],
                 'contig'      => [{
                                    'type'  => 'box',
                                    'attrs' => { 'fgcolor' => 'contigblue1', 'bgcolor' => 'contigblue1' }
                                  }],
                 'clone'       => [{
                                    'type'  => 'box',
                                    'attrs' => { 'fgcolor' => 'orange', 'bgcolor' => 'orange' }
                                  }],
                 'default'     => [{
                                    'type'  => 'box',
                                    'attrs' => { 'fgcolor' => 'black', 'bgcolor' => 'black' }
                                  }]
                }
  });
}

sub subslice {
  my( $self, $sr, $start, $end ) = @_;

  my $dba = $self->database('core', $self->real_species);

  return $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region(undef, $sr, $start, $end, 1 );
}
1;
