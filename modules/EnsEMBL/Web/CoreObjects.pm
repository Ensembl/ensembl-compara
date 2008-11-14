package EnsEMBL::Web::CoreObjects;

use strict;

use base qw(EnsEMBL::Web::Root);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Fake;
use Bio::EnsEMBL::Registry;

sub new {
  my( $class, $input, $dbconnection, $flag ) = @_;
  my $self = {
    'input'      => $input,
    'dbc'        => $dbconnection,
    'objects' => {
      'transcript' => undef,
      'gene'       => undef,
      'location'   => undef,
      'variation'  => undef,
      'search'     => undef,
    },
    'parameters' => {}
  };
  bless $self, $class;
  if( $flag ) {
    $self->_generate_objects_lw;
  } else {
    $self->_generate_objects;
  }
  return $self;
}

sub timer_push {
  my $self = shift;
  $ENSEMBL_WEB_REGISTRY->timer->push(@_);
}

sub compara_db {
  my $self = shift;
  my $key  = shift;
  return Bio::EnsEMBL::Registry->get_DBAdaptor( 'multi', $key );
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
  return ucfirst($self->transcript->type).': '.$self->transcript->stable_id if $self->transcript->isa('EnsEMBL::Web::Fake');
  my $dxr = $self->transcript->can('display_xref') ? $self->transcript->display_xref : undef;
  my $label = $dxr ? $dxr->display_id : $self->transcript->stable_id;
  return length( $label ) < 15 ? "Transcript: $label" : "Trans: $label";
}

sub transcript_long_caption {
  my $self = shift;
  return '-' unless $self->transcript;
  my $dxr = $self->transcript->can('display_xref') ? $self->transcript->display_xref : undef;
  my $label = $dxr ? " (".$dxr->display_id.")" : '';
  return $self->transcript->stable_id.$label;
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
  my $dxr = $self->gene->can('display_xref') ? $self->gene->display_xref : undef;
  my $label = $dxr ? $dxr->display_id : $self->gene->stable_id;
  return "Gene: $label";
}

sub gene_long_caption {
  my $self = shift;
  return '-' unless $self->gene;
  my $dxr = $self->gene->can('display_xref') ? $self->gene->display_xref : undef;
  my $label = $dxr ? " (".$dxr->display_id.")" : '';
  return $self->gene->stable_id.$label;
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
  return 'Genome' if $self->location->isa('EnsEMBL::Web::Fake');
  my $label = $self->location->seq_region_name.':'.$self->thousandify($self->location->start).'-'.$self->thousandify($self->location->end);
  #return $label;
  return "Location: $label";
}

sub location_long_caption {
  my $self = shift;
  return '-' unless $self->location;
  return 'Genome' if $self->location->isa('EnsEMBL::Web::Fake');
  return $self->location->seq_region_name.':'.$self->thousandify($self->_centre_point);
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
  return $self->variation->name;
}

sub param {
  my $self = shift;
  return $self->{input}->param(@_);
}

sub _generate_objects_lw {
  my $self = shift;
  my $action = '_generate_objects_'.$ENV{'ENSEMBL_TYPE'};
  $self->timer_push( 'Lightweight core objects call' );
  foreach (qw(pt t g r db v vdb source _referer)) {
    $self->{'parameters'}{$_} = $self->param($_);
  }
  $self->$action;
}

sub _generate_objects_Location {
  my $self = shift;
  my($r,$s,$e) = $self->{'parameters'}{'r'} =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)/;
  my $db_adaptor= $self->database('core');
  my $t = $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e );
  if($t && $s < 1 || $e > $t->seq_region_length ) {
    $s = 1 if $s<1;
    $e = $t->seq_region_length if $e > $t->seq_region_length;
    $t = $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e );
  }
  $self->timer_push( 'Location fetched', undef, 'fetch' );
  $self->location( $t );
}

sub _generate_objects_Transcript {
  my $self = shift;
  $self->{'parameters'}{'db'} ||= 'core';
  my $db_adaptor = $self->database($self->{'parameters'}{'db'});
  if( $self->{'parameters'}{'t'} ) {
    my $t = $db_adaptor->get_TranscriptAdaptor->fetch_by_stable_id( $self->{'parameters'}{'t'} );
    $self->timer_push( 'Transcript fetched', undef, 'fetch' );
    $self->transcript( $t );
  } elsif( $self->{'parameters'}{'pt'} ) {
    my $t = $db_adaptor->get_PredictionTranscriptAdaptor->fetch_by_stable_id( $self->{'parameters'}{'pt'} );
    $self->timer_push( 'Transcript fetched', undef, 'fetch' );
    $self->transcript( $t );
  }
}

sub _generate_objects_Gene {
  my $self = shift;
  $self->{'parameters'}{'db'} ||= 'core';
  my $db_adaptor = $self->database($self->{'parameters'}{'db'});
  warn "G = ".$self->{'parameters'}{'g'};
  my $t = $db_adaptor->get_GeneAdaptor->fetch_by_stable_id( $self->{'parameters'}{'g'} );
  $self->timer_push( 'Gene fetched', undef, 'fetch' );
  $self->gene( $t );
}

sub _generate_objects_Variation {
  my $self = shift; 
  $self->{'parameters'}{'vdb'} ||= 'variation';
  my $db_adaptor = $self->database($self->{'parameters'}{'vdb'});
  my $t = $db_adaptor->getVariationAdaptor->fetch_by_name( $self->{'parameters'}{'v'}, $self->{'parameters'}{'source'} );
  $self->timer_push( 'Gene fetched', undef, 'fetch' );
  warn $t;
  $self->variation( $t );
  $self->timer_push( 'Fetching location', undef );
  $self->_generate_objects_Location;
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
    if( $vardb_adaptor ) {
    $self->variation($vardb_adaptor->get_VariationAdaptor->fetch_by_name($self->param('v'), $self->param('source')));
    unless ($self->param('r')){ $self->_check_if_snp_unique_location; }
    $self->_give_snp_unique_identifier($self->param('vf'));
    }
  }  
  if( $self->param('t') ) {
    my $tdb    = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    if( $tdb_adaptor ) {
    my $t = $tdb_adaptor->get_TranscriptAdaptor->fetch_by_stable_id( $self->param('t'));
    if( $t ) {
      $self->transcript( $t );
      $self->_get_gene_location_from_transcript;
    } else {
      my $a = $tdb_adaptor->get_ArchiveStableIdAdaptor;
      $t = $a->fetch_by_stable_id( $self->param('t') ); 
      $self->transcript( $t ) if $t;
    }
    }
  }
  if( $self->param('pt') ) {
    my $tdb    = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    if( $tdb_adaptor ) {
    my $t = $tdb_adaptor->get_PredictionTranscriptAdaptor->fetch_by_stable_id( $self->param('pt') );
    if( $t ) {
      $self->transcript( $t );
      my $slice = $self->transcript->feature_Slice;
         $slice = $slice->invert() if $slice->strand < 0;
      $self->location( $slice );
    }
    }
  }
  if( !$self->transcript &&  $self->param('domain') ) {
    my $tdb         = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    if( $tdb_adaptor ) {
    my $sth = $tdb_adaptor->dbc()->db_handle()->prepare( 'select i.interpro_ac,x.display_label, x.description from interpro as i left join xref as x on i.interpro_ac=x.dbprimary_acc where i.interpro_ac = ?' );
    $sth->execute( $self->param('domain') ); 
    my ($t,$n,$d) = $sth->fetchrow();
    if( $t ) {
      $self->transcript( new EnsEMBL::Web::Fake({ 'view' => 'Domains/Genes', 'type'=>'Interpro Domain', 'id' => $t, 'name' => $n, 'description' => $d, 'adaptor' => $tdb_adaptor->get_GeneAdaptor }) );
      $self->{'parameters'}{'domain'} = $self->param('domain');
    }
    }
  }
  if( !$self->transcript && $self->param('g') ) {
    my $tdb    = $self->{'parameters'}{'db'}  = $self->param('db')  || 'core';
    my $tdb_adaptor = $self->database($tdb);
    if( $tdb_adaptor ) {
    my $g = $tdb_adaptor->get_GeneAdaptor->fetch_by_stable_id(       $self->param('g') );
    if( $g ) {
      $self->gene( $g );
      if( @{$g->get_all_Transcripts} == 1 ) {
        my $t = $g->get_all_Transcripts->[0];
        $self->transcript( $t );
        $self->{'parameters'}{'t'} = $t->stable_id;
      }
      $self->_get_location_from_gene;
    } else {
      my $a = $tdb_adaptor->get_ArchiveStableIdAdaptor;
      $g = $a->fetch_by_stable_id( $self->param('g') ); 
      $self->gene( $g ) if $g;
    }
    }
  }
  if( !$self->gene && $self->param('family') ) {
    my $compara_db = $self->compara_db( 'compara' );
    if( $compara_db ) {
      my $fa = $compara_db->get_FamilyAdaptor;
      if( $fa ) {
        my $f = $fa->fetch_by_stable_id( $self->param('family') );
        $self->gene( $f ) if $f;
        $self->{'parameters'}{'family'} = $self->param('family') if $f;
      }
    }   
  }
  $self->{'parameters'}{'r'} = $self->location->seq_region_name.':'.$self->location->start.'-'.$self->location->end if $self->location;
  if( $self->param('r') ) {
    my($r,$s,$e) = $self->param('r') =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)/;
    $r ||= $self->param('r');
    if( $r ) {
      if( ($s||$e) ) {
        my $db_adaptor= $self->database('core');
        if($db_adaptor){
        my $t = $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e );
        if( $t ) {
          my @attrib = @{ $t->get_all_Attributes( 'toplevel' )||[] }; ## Check to see if top-level as "toplevel" above is b*ll*cks
          if( @attrib && ( $s < 1 || $e > $t->seq_region_length ) ) {
            $s = 1 if $s<1;
            $e = $t->seq_region_length if $e > $t->seq_region_length;
            $t = $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s, $e );
          }
          if( $t && @attrib ) {
            $self->location( $t );
            $self->{'parameters'}{'r'} = $t->seq_region_name.':'.$t->start.'-'.$t->end;
          }
        }
        }
      } else {
        my $db_adaptor= $self->database('core');
        if($db_adaptor){
        my $slice = $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r );
        if( $slice ) {
          my @attrib = @{ $slice->get_all_Attributes( 'toplevel' )||[] };  ## Check to see if top-level as "toplevel" above is b*ll*cks
          if(@attrib){ 
            $self->location( $slice );
            $self->{'parameters'}{'r'} = $slice->seq_region_name;
          }
        }
        }
      }
    }
  }
  if( !$self->location ) {
    $self->location( new EnsEMBL::Web::Fake({ 'view' => 'Genome', 'type'=>'Genome' } ) );
  }

  if( $self->transcript ) {
    if( $self->transcript->isa('EnsEMBL::Web::Fake') ) {
      ## Do nothing!
    } elsif( $self->transcript->isa('Bio::EnsEMBL::StableIdHistoryTree') ) {
      $self->{'parameters'}{'t'} = $self->param('t');
    } else {
      $self->{'parameters'}{$self->transcript->isa('Bio::EnsEMBL::PredictionTranscript')?'pt':'t'} = $self->transcript->stable_id;
    }
  }
  if( $self->gene ) {
    if( $self->gene->isa( 'Bio::EnsEMBL::Gene') ) {
      $self->{'parameters'}{'g'} = $self->gene->stable_id;
    }
  }
  $self->{'parameters'}{'v'} = $self->variation->name       if $self->variation;
  unless( keys %{$self->{'parameters'}} ) {
    $self->{'parameters'}{'_referer'} = $self->param('_referer') if $self->param('_referer');
  }
  $self->{'parameters'}{'h'} = $self->param('h') if $self->param('h');
}

sub _get_gene_location_from_transcript {
  my $self = shift; 	 
  return unless $self->transcript; 	 
  $self->gene( 	 
    $self->transcript->adaptor->db->get_GeneAdaptor->fetch_by_transcript_stable_id( 	 
      $self->transcript->stable_id 	 
    ) 	 
  ); 	 
  my $slice = $self->transcript->feature_Slice; 	 
     $slice = $slice->invert() if $slice->strand < 0; 	 
  $self->location( $slice ); 	 
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
}

sub _check_if_snp_unique_location {
  my ( $self, $vf ) = @_;
  return unless $self->variation;
  my $db_adaptor = $self->database('core');
  my $vardb =  $self->database('variation') ; 
  my $vf_adaptor = $vardb->get_VariationFeatureAdaptor; 
  my @features = @{$vf_adaptor->fetch_all_by_Variation($self->variation)};

  my $context = $self->param('vw')||500;
  unless (scalar @features > 1){
   my $s =  $features[0]->start; 
   my $e = $features[0]->end;
   my $r = $features[0]->seq_region_name;
   $self->location(   $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s-$context, $e+$context ) );
  } elsif (scalar @features > 1 && $vf){
    foreach my $var_feat( @features){
      if ($var_feat->dbID eq $vf ) {
        my $s =  $features[0]->start;
        my $e = $features[0]->end;
        my $r = $features[0]->seq_region_name;
        $self->location(   $db_adaptor->get_SliceAdaptor->fetch_by_region( 'toplevel', $r, $s-$context, $e+$context ) );
      }
    }
  } 
}

sub _give_snp_unique_identifier {
  my ( $self, $vf ) = @_;
  return unless $self->variation;
  my $db_adaptor = $self->database('core');
  my $vardb =  $self->database('variation') ;
  my $vf_adaptor = $vardb->get_VariationFeatureAdaptor;
  my @features = @{$vf_adaptor->fetch_all_by_Variation($self->variation)};
  if (scalar @features == 1){
    $self->{'parameters'}{'vf'} = $features[0]->dbID; 
    $self->param( 'vf', $features[0]->dbID );
    return;
  } elsif (scalar @features > 1 && $vf){
    my $flag =0;
    foreach my $var_feat( @features){
      if ($var_feat->dbID eq $vf ) { 
        $self->{'parameters'}{'vf'} = $var_feat->dbID;
        unless ($self->param('r')){ $self->_check_if_snp_unique_location($var_feat->dbID); }
        $flag =1;    
      }
    }
    if ($flag == 0) { $self->{'parameters'}{'vf'};}
  }
}
1;
