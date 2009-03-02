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

        # Extract seqname, start and end from the request
        my ($region_name, $region_start, $region_end) = ($s->name);
        if ($s->name =~ /^([-\w\.]+):([\.\w]+),([\.\w]+)$/ ) {
            ($region_name,$region_start,$region_end) = ($1,$2,$3);
        }

        my $slice = $s->slice;
        my $current_cs = $slice->coord_system;
        my $current_rank = $current_cs->rank;

        if ( ! defined ($region_end)) {
            my $path;
            eval { $path = $slice->project($current_cs->name); };
            if ($path) {
                $path = $path->[0]->to_Slice;
                ($region_start, $region_end) = ($path->start, $path->end);
            }
        }

        my $csa = $slice->coord_system->{adaptor};
        my %projections_by_rank = ();

        # Start by gathering slice data for coordinate systems +- 2 ranks
        # We go 2 ranks beyond the query coordsys because we want to tell the
        # the client if there are parts of the assembly above/below those returned
        for (my $rank=$current_rank-2; $rank <= $current_rank+2; $rank++) {
            $projections_by_rank{$rank} = [];
            $rank > 0 || next;
            my $cs = $csa->fetch_by_rank($rank);
            # Check this level of coordinate system exists and is current
            if ($cs && $cs->is_default) {
                # Project the query segment to the other coordsys
                $projections_by_rank{$rank} = $slice->project( $cs->name, $cs->version );
            }
        }
        
        my @ss = ();
        
        # Now for the coordinate systems +- 1 rank, make actual features
        for (my $rank=$current_rank-1; $rank <= $current_rank+1; $rank++) {
            for my $psegment (@{ $projections_by_rank{$rank} }) {
                my $pslice  = $psegment->to_Slice;
                my $feature = {
                  'ID'     => $pslice->seq_region_name,
                  # position/strand relative to query coordinate system
                  'START'       => $psegment->from_start + $slice->start - 1,
                  'END'         => $psegment->from_end   + $slice->start - 1,
                  'ORIENTATION' => $self->ori( $pslice->strand ),
                  # position relative to slice's coordinate system
                  'TARGET' => {
                    'ID'    => $pslice->seq_region_name,
                    'START' => $pslice->start,
                    'STOP'  => $pslice->end,
                  },
                  'REFERENCE' => 'yes',
                  'TYPE'      => $pslice->coord_system->name,
                  # Is this coordsystem at a higher level than the query?
                  'CATEGORY'  => $rank < $current_rank ? 'supercomponent' : 'component',
                  # Does this coordsystem have any higher-level slices?
                  'SUPERPARTS' => scalar @{ $projections_by_rank{$rank-1} } ? 'yes' : 'no',
                  # Does this coordsystem have any lower-level slices?
                  'SUBPARTS'   => scalar @{ $projections_by_rank{$rank+1} } ? 'yes' : 'no',
                };
                push @ss, $feature;
            }
        }

        my @rfeatures = ();
        # Apply feature type filters if specified
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
