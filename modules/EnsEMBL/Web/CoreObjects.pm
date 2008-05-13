package EnsEMBL::Web::CoreObjects;

use strict;

use base qw(EnsEMBL::Web::Root);

sub new {
  my( $class, $input, $dbconnection ) = @_;
  my $self = {
    'input'      => $input,
    'dbc'        => $dbconnection,
    'objects' => {
      'transcript' => undef,
      'gene'       => undef,
      'location'   => undef,
      'snp'        => undef,
    },
    'parameters' => {}
  };
  bless $self, $class;
  $self->_generate_objects;
  return $self;
}

sub database {
  my $self = shift;
  return $self->{'dbc'}->get_DBAdaptor(@_);
}
sub transcript {
### a
  my $self = shift;
  $self->{objects}{transcript} = shift if @_;
  return $self->{objects}{transcript};
}

sub transcript_short_caption {
  my $self = shift;
  return '-' unless $self->transcript;
  my $dxr = $self->transcript->display_xref;
  my $label = $dxr ? $dxr->display_id : $self->transcript->stable_id;
  return length( $label ) < 15 ? "Transcript: $label" : "Trans: $label";
}

sub transcript_long_caption {
  my $self = shift;
  return '-' unless $self->transcript;
  my $dxr = $self->transcript->display_xref;
  my $label = $dxr ? " (".$dxr->display_id.")" : '';
  return "Transcript: ".$self->transcript->stable_id.$label;
}

sub transcript_disabled {
  my $self = shift;
  return "There is no default gene for this location";
}

sub gene {
### a
  my $self = shift;
  $self->{objects}{gene} = shift if @_;
  return $self->{objects}{gene};
}

sub gene_short_caption {
  my $self = shift;
  return '-' unless $self->gene;
  my $dxr = $self->gene->display_xref;
  my $label = $dxr ? $dxr->display_id : $self->gene->stable_id;
  return "Gene: $label";
}

sub gene_long_caption {
  my $self = shift;
  return '-' unless $self->gene;
  my $dxr = $self->gene->display_xref;
  my $label = $dxr ? " (".$dxr->display_id.")" : '';
  return "Gene: ".$self->gene->stable_id.$label;
}

sub gene_disabled {
  my $self = shift;
  return "There is no default gene for this location";
}

sub location {
### a
  my $self = shift;
  $self->{objects}{location} = shift if @_;
  return $self->{objects}{location};
}

sub location_short_caption {
  my $self = shift;
  return '-' unless $self->location;
  my $midpoint = int($self->location->end - $self->location->start) + $self->location->start;
  my $label = $self->location->seq_region_name.':'.$self->thousandify($midpoint);
  #return $label;
  if( length($label)>30) {
    return "Loc: $label";
  } else {
    return "Location: $label";
  }
}

sub location_long_caption {
  my $self = shift;
  return '-' unless $self->location;
  my $midpoint = int($self->location->end - $self->location->start) + $self->location->start;
  return "Location: ".$self->location->seq_region_name.':'.$self->thousandify($midpoint);
}

sub location_disabled {
  my $self = shift;
  return "";
}

sub snp {
### a
  my $self = shift;
  $self->{objects}{snp} = shift if @_;
  return $self->{objects}{snp};
}

sub snp_short_caption {
  my $self = shift;
  return '-' unless $self->snp;
  my $label = $self->snp->name;
  if( length($label)>30) {
    return "Var: $label";
  } else {
    return "Variation: $label";
  }
}

sub snp_long_caption {
  my $self = shift;
  return '-' unless $self->snp;
  return "Variation: ".$self->snp->name;
}

sub snp_disabled {
  my $self = shift;
  return "No variation data has been selected";
}

sub param {
  my $self = shift;
  return $self->{input}->param(@_);
}

sub _generate_objects {
  my $self = shift;
  my $db = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
  my $db_adaptor = $self->database($db);
  if( $self->param('t') ) {
    $self->transcript( $db_adaptor->get_TranscriptAdaptor->fetch_by_stable_id( $self->param('t')) );
    $self->_get_gene_location_from_transcript;
  }
  if( !$self->transcript && $self->param('g') ) {
    $self->gene(       $db_adaptor->get_GeneAdaptor->fetch_by_stable_id(       $self->param('g')) );
    $self->_get_location_transcript_from_gene;
  }
  if( $self->param('r') ) {
    my($r,$s,$e) = $self->param('r') =~ /^([^:]+):(\w+)-(\w+)/;
    $self->location(   $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e ) );
  }
  $self->_get_gene_transcript_from_location unless $self->transcript;
  $self->{'parameters'}{'r'} = $self->location->seq_region_name.':'.$self->location->start.'-'.$self->location->end
    if $self->location;
  $self->{'parameters'}{'t'} = $self->transcript->stable_id if $self->transcript;
  $self->{'parameters'}{'g'} = $self->gene->stable_id       if $self->gene;
}

sub _get_gene_location_from_transcript {
  my $self = shift;
  return unless $self->transcript;
  $self->gene(
    $self->transcript->adaptor->db->get_GeneAdaptor->fetch_by_transcript_stable_id(
      $self->transcript->stable_id
    )
  );
  $self->location( $self->transcript->feature_Slice );
}

sub _get_location_transcript_from_gene {
  my( $self ) = @_;
  return unless $self->gene;
## Replace this with canonical transcript calculation!!
  $self->transcript(
    sort {
      ( $b->display_xref ? $b->display_xref->priority : 0 ) <=> ( $a->display_xref ? $a->display_xref->priority : 0 ) ||
      $a->stable_id cmp $b->stable_id
    } @{$self->gene->get_all_Transcripts} );
  $self->location(   $self->gene->feature_Slice );
}

sub _get_gene_transcript_from_location {
  my( $self ) = @_;
  return unless $self->location;
  my $db = $self->{'parameters'}{'db'}||'core';
  my $genes = $self->location->get_all_Genes( undef, $db, 1 );
  my $nearest_transcript = [ undef, undef ];
  my $nearest_distance   = 1e20;

  my $s = $self->location->start;
  my $e = $self->location->end;
  my $c = ($s+$e)/2;
  my @transcripts;
  my $distance;
  foreach my $g ( @$genes ) {
    foreach my $t ( @{$g->get_all_Transcripts} ) {
      my $ts = $t->seq_region_start;
      my $te = $t->seq_region_end;
      if( $ts <= $c && $te >= $c ) {
        push @transcripts, [ $g,$t ];
        $nearest_distance = 0;
      } else {
        $distance = $te<$c ? $c-$te : $ts-$c;
        if( $distance < $nearest_distance ) {
          $nearest_transcript = [ $g, $t ];
          $nearest_distance   = $distance;
        }
      }
    }
  }
  if( @transcripts ) {
    my($T) = sort { 
      ( $b->[1]->display_xref ? $b->[1]->display_xref->priority : 0 ) <=> ( $a->[1]->display_xref ? $a->[1]->display_xref->priority : 0 ) ||
      $a->[0]->stable_id cmp $b->[0]->stable_id ||
      $a->[1]->stable_id cmp $b->[1]->stable_id 
    } @transcripts;
    $self->gene(       $T->[0] );
    $self->transcript( $T->[1] );
  } elsif( $nearest_transcript->[1] ) {
    $self->gene(       $nearest_transcript->[0] );
    $self->transcript( $nearest_transcript->[1] );
  }
}

1;
