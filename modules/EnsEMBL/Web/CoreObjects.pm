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
      'variation'  => undef,
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

sub location {
### a
  my $self = shift;
  $self->{objects}{location} = shift if @_;
  return $self->{objects}{location};
}

sub _centre_point {
  my $self = shift;
  return int( ($self->location->end + $self->location->start) /2);
}

sub location_short_caption {
  my $self = shift;
  return '-' unless $self->location;
  my $label = $self->location->seq_region_name.':'.$self->thousandify($self->location->start).'-'.$self->thousandify($self->location->end);
  #return $label;
  return "Location: $label";
}

sub location_long_caption {
  my $self = shift;
  return '-' unless $self->location;
  return "Location: ".$self->location->seq_region_name.':'.$self->thousandify($self->_centre_point);
}

sub variation {
### a
  my $self = shift;
  $self->{objects}{variation} = shift if @_;
  return $self->{objects}{variation};
}

sub variation_short_caption {
  my $self = shift;
  return '-' unless $self->variation;
  my $label = $self->variation->name;
  if( length($label)>30) {
    return "Var: $label";
  } else {
    return "Variation: $label";
  }
}

sub variation_long_caption {
  my $self = shift;
  return '-' unless $self->variation;
  return "Variation: ".$self->variation->name;
}

sub param {
  my $self = shift;
  return $self->{input}->param(@_);
}

sub _generate_objects {
  my $self = shift;

  return if $ENV{'ENSEMBL_SPECIES'} eq 'common';

#  if( $self->param('variation')) {
#    $self->variation($vardb_adaptor->get_VariationAdaptor->fetch_by_name($self->param('variation'), $self->param('source')));
#    unless ($self->param('r')){ $self->_check_if_snp_unique_location; }
  if( $self->param('v')) {
    my $vardb = $self->{'parameters'}{'vdb'} = $self->param('vdb') || 'variation';
    my $vardb_adaptor = $self->database('variation');
    $self->variation($vardb_adaptor->get_VariationAdaptor->fetch_by_name($self->param('v'), $self->param('source')));
    unless ($self->param('r')){ $self->_check_if_snp_unique_location; }
  }  
  if( $self->param('t') ) {
    my $tdb    = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    $self->transcript( $tdb_adaptor->get_TranscriptAdaptor->fetch_by_stable_id( $self->param('t')) );
    $self->_get_gene_location_from_transcript;
  }
  if( !$self->transcript && $self->param('g') ) {
    my $tdb    = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    $self->gene(       $tdb_adaptor->get_GeneAdaptor->fetch_by_stable_id(       $self->param('g')) );
    $self->_get_location_from_gene;
  }
  if( $self->param('r') ) {
    my($r,$s,$e) = $self->param('r') =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)/;
    my $db_adaptor= $self->database('core');
    $self->location(   $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e ) );
  }
  $self->{'parameters'}{'r'} = $self->location->seq_region_name.':'.$self->location->start.'-'.$self->location->end if $self->location;
  $self->{'parameters'}{'t'} = $self->transcript->stable_id if $self->transcript;
  $self->{'parameters'}{'g'} = $self->gene->stable_id       if $self->gene;
  $self->{'parameters'}{'v'} = $self->variation->name       if $self->variation;
}

sub _get_location_from_gene {
  my( $self ) = @_;
  return unless $self->gene;

  my $slice = $self->gene->feature_Slice;
     $slice = $slice->invert() if $slice->strand < 0;
  $self->location( $slice );
}

sub _get_gene_transcript_from_location {
  my( $self ) = @_;
  return unless $self->location;
  return;
  my $db = $self->{'parameters'}{'db'}||'core';
  my $genes = $self->location->get_all_Genes( undef, $db, 1 );
  my $nearest_transcript = [ undef, undef ];
  my $nearest_distance   = 1e20;

  my $s = $self->location->start;
  my $e = $self->location->end;
  my $c = ($s+$e)/2;
  my @transcripts;
  foreach my $g ( @$genes ) {
    foreach my $t ( @{$g->get_all_Transcripts} ) {
      my $ts = $t->seq_region_start;
      my $te = $t->seq_region_end;
      if( $ts <= $c && $te >= $c ) {
        push @transcripts, [ $g,$t ];
        $nearest_distance = 0;
      }
    }
  }
  if( @transcripts ) {
    my($T) = sort { 
      $a->[0]->stable_id cmp $b->[0]->stable_id || $a->[1]->stable_id cmp $b->[1]->stable_id 
    } @transcripts;
    $self->gene(       $T->[0] );
    $self->transcript( $T->[1] );
  }
}

sub _check_if_snp_unique_location {
  my ( $self ) = @_;
  return unless $self->variation;
  my $db_adaptor = $self->database('core');
  my $vardb =  $self->database('variation') ; 
  my $vf_adaptor = $vardb->get_VariationFeatureAdaptor; 
  my @features = @{$vf_adaptor->fetch_all_by_Variation($self->variation)};

  unless (scalar @features > 1){
   my $s =  $features[0]->start; warn $s;
   my $e = $features[0]->end;
   my $r = $features[0]->seq_region_name;
   $self->location(   $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e ) );
  } 
 
}
1;
