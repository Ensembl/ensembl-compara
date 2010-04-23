package EnsEMBL::Web::CoreObjects;

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Fake;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $input, $dbconnection, $flag) = @_;
  
  my $self = {
    input      => $input,
    dbc        => $dbconnection,
    parameters => {},
    objects    => {}
  };
  
  bless $self, $class;
  
  $self->_generate_objects;
  
  return $self;
}

sub location   :lvalue { $_[0]->{'objects'}{'location'};   }
sub gene       :lvalue { $_[0]->{'objects'}{'gene'};       }
sub transcript :lvalue { $_[0]->{'objects'}{'transcript'}; }
sub variation  :lvalue { $_[0]->{'objects'}{'variation'};  }
sub regulation :lvalue { $_[0]->{'objects'}{'regulation'}; }

sub param    { my $self = shift; return $self->{'input'}->param(@_); }
sub database { my $self = shift; return $self->{'dbc'}->get_DBAdaptor(@_); }

sub long_caption {
  my ($self, $type) = @_;
  
  return '-' unless $self->$type;
  
  my $dxr   = $self->$type->can('display_xref') ? $self->$type->display_xref : undef;
  my $label = $dxr ? ' (' . $dxr->display_id . ')' : '';
  
  return $self->$type->stable_id . $label;
}

sub transcript_short_caption {
  my $self = shift;  
  
  return '-' unless $self->transcript;
  return ucfirst($self->transcript->type) . ': ' . $self->transcript->stable_id if $self->transcript->isa('EnsEMBL::Web::Fake');
  
  my $dxr   = $self->transcript->can('display_xref') ? $self->transcript->display_xref : undef;
  my $label = $dxr ? $dxr->display_id : $self->transcript->stable_id;
  
  return length $label < 15 ? "Transcript: $label" : "Trans: $label";
}

sub gene_short_caption {
  my $self = shift;
  
  return '-' unless $self->gene;
  
  my $dxr   = $self->gene->can('display_xref') ? $self->gene->display_xref : undef;
  my $label = $dxr ? $dxr->display_id : $self->gene->stable_id;
  
  return "Gene: $label";
}

sub location_short_caption {
  my $self = shift;
  
  return '-' unless $self->location;
  return 'Genome' if $self->location->isa('EnsEMBL::Web::Fake');
  
  my $label = $self->location->seq_region_name . ':' . $self->thousandify($self->location->start) . '-' . $self->thousandify($self->location->end);
  
  return "Location: $label";
}

sub variation_short_caption {
  my $self = shift;
  
  return '-' unless $self->variation;
  
  my $label = $self->variation->name;
  
  return (length $label > 30 ? 'Var: ' : 'Variation: ') . $label;
}

sub regulation_short_caption {
  my $self = shift;
  
  return '-' unless $self->regulation;
  return 'Regulation: ' . $self->regulation->stable_id;
}

sub _generate_objects {
  my $self = shift;

  return if $ENV{'ENSEMBL_SPECIES'} eq 'common';

  $self->_generate_regulation if $self->param('rf');
  $self->_generate_variation  if $self->param('v');
  $self->_generate_transcript;
  $self->_generate_gene;
  $self->_generate_location;
  
  $self->param($_, $self->{'parameters'}->{$_}) for keys %{$self->{'parameters'}};
  
  $self->{'parameters'}{'h'} = $self->param('h') if $self->param('h');
}

sub _generate_location {
  my $self  = shift;
  my $slice = shift;
  
  if ($slice) {
    $slice = $slice->invert if $slice->strand < 0;
    
    if (!$slice->is_toplevel) {
      my $toplevel_projection = $slice->project('toplevel');
      
      if (my $seg = shift @$toplevel_projection) {
          $slice = $seg->to_Slice;
      }
    }

    $self->location = $slice;
  } elsif ($self->param('r')) {
    my ($r, $s, $e, $strand) = $self->param('r') =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)(?::(-\d+))?/;
    $r ||= $self->param('r');
    
    if ($r) {      
      eval {
        $slice = $self->_get_slice($r, $s, $e);
      };
      
      if ($slice) {
        $self->location = $slice;
        $self->{'parameters'}{'r'} = $slice->seq_region_name;
        $self->{'parameters'}{'r'} .= ':' . $slice->start . '-' . $slice->end . ($strand ? ":$strand" : '') if $s || $e;
      }
    }
  }
  
  $self->{'parameters'}{'r'} ||= $self->location->seq_region_name . ':' . $self->location->start . '-' . $self->location->end if $self->location;
  
  if (!$self->location) {
    if ($self->param('m')) {
      $self->location = new EnsEMBL::Web::Fake({ 
        'view'    => 'Marker', 
        'type'    => 'Marker', 
        'markers' => $self->database($self->param('db') || 'core')->get_adaptor('Marker')->fetch_all_by_synonym($self->param('m'))
      });
    } else {
      $self->location = new EnsEMBL::Web::Fake({ view => 'Genome', type => 'Genome' });
    }
  }
}

sub _generate_gene {
  my $self = shift;
  
  if (!$self->transcript && $self->param('g')) {
    my $tdb         = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
    my $tdb_adaptor = $self->database($tdb);
    
    if ($tdb_adaptor) {
      my $g = $tdb_adaptor->get_GeneAdaptor->fetch_by_stable_id($self->param('g'));
      
      if ($g) {
        $self->gene = $g;
        
        my $transcripts = $g->get_all_Transcripts;
        
        # set the transcript if there is only one;
        if (scalar @$transcripts == 1) {
          my $t = $transcripts->[0];
          $self->transcript = $t;
          $self->{'parameters'}{'t'} = $t->stable_id;
        }
        
        $self->_generate_location($self->gene->feature_Slice);
      } else {
        my $a = $tdb_adaptor->get_ArchiveStableIdAdaptor;
        $g = $a->fetch_by_stable_id($self->param('g')); 
        $self->gene = $g if $g;
      }
    }
  }
  
  if (!$self->gene && $self->param('family')) {
    my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'compara');
    
    if ($compara_db) {
      my $fa = $compara_db->get_FamilyAdaptor;
      
      if ($fa) {
        my $f = $fa->fetch_by_stable_id($self->param('family'));
        $self->gene = $f if $f;
        $self->{'parameters'}{'family'} = $self->param('family') if $f;
      }
    }   
  }
  
  $self->{'parameters'}{'g'} = $self->gene->stable_id if $self->gene && !$self->gene->isa('EnsEMBL::Web::Fake');
}

sub _generate_transcript {
  my $self = shift;
  
  if ($self->param('t')) {
    my $tdb = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
    my $tdb_adaptor = $self->database($tdb);
    
    if ($tdb_adaptor) {
      my $t = $tdb_adaptor->get_TranscriptAdaptor->fetch_by_stable_id($self->param('t'));
      
      if ($t) {
        $self->transcript = $t;
        $self->_get_gene_location_from_transcript($tdb_adaptor);
      } else {
        my $a = $tdb_adaptor->get_ArchiveStableIdAdaptor;
        
        $t = $a->fetch_by_stable_id($self->param('t')); 
        $self->transcript = $t if $t;
      }
      
      $self->{'parameters'}{'t'} = $t->stable_id if $t;
    }
  }
  
  if ($self->param('pt')) {
    my $tdb         = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
    my $tdb_adaptor = $self->database($tdb);
    
    if ($tdb_adaptor) {
      my $t = $tdb_adaptor->get_PredictionTranscriptAdaptor->fetch_by_stable_id($self->param('pt'));
      
      if ($t) {
        $self->transcript = $t;
        
        my $slice = $self->transcript->feature_Slice;
        $slice = $slice->invert if $slice->strand < 0;
        
        $self->location = $slice;
        
        $self->{'parameters'}{'pt'} = $t->stable_id;
      }
    }
  }
  
  if (!$self->transcript && ($self->param('protein') || $self->param('p'))) {
    my $tdb         = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
    my $trans_id    = $self->param('protein') || $self->param('p'); 
    my $tdb_adaptor = $self->database($tdb);
    my $a           = $tdb_adaptor->get_ArchiveStableIdAdaptor;
    my $p           = $a->fetch_by_stable_id($trans_id);
    
    if ($p) {
      if ($p->is_current) {
        my $t = $tdb_adaptor->get_TranscriptAdaptor->fetch_by_translation_stable_id($trans_id);
        $self->transcript = $t;
        $self->_get_gene_location_from_transcript($tdb_adaptor);
      } else {
        my $assoc_transcript = shift @{$p->get_all_transcript_archive_ids};
        
        if ($assoc_transcript) {
          my $t = $a->fetch_by_stable_id($assoc_transcript->stable_id);
          $self->transcript = $t;
        } else { 
          $self->transcript = new EnsEMBL::Web::Fake({ view => 'Idhistory/Protein', type => 'history_protein', id => $trans_id , adaptor => $a });
          $self->{'parameters'}{'protein'} = $trans_id; 
        }  
      }
    }
  }
  
  if (!$self->transcript && $self->param('domain')) {
    my $tdb         = $self->{'parameters'}{'db'} = $self->param('db') || 'core';
    my $tdb_adaptor = $self->database($tdb);
    
    if ($tdb_adaptor) {
      my $sth = $tdb_adaptor->dbc->db_handle->prepare('select i.interpro_ac, x.display_label, x.description from interpro as i left join xref as x on i.interpro_ac = x.dbprimary_acc where i.interpro_ac = ?');
      $sth->execute($self->param('domain'));
      my ($t, $n, $d) = $sth->fetchrow;
      
      if ($t) {
        $self->transcript = new EnsEMBL::Web::Fake({ view => 'Domains/Genes', type => 'Interpro Domain', id => $t, name => $n, description => $d, adaptor => $tdb_adaptor->get_GeneAdaptor });
        $self->{'parameters'}{'domain'} = $self->param('domain');
      }
    }
  }
}

sub _generate_variation {
  my $self = shift; 
  my $vardb         = $self->{'parameters'}{'vdb'} = $self->param('vdb') || 'variation';
  my $vardb_adaptor = $self->database($vardb);
  
  return unless $vardb_adaptor;
  
  $self->variation = $vardb_adaptor->get_VariationAdaptor->fetch_by_name($self->param('v'), $self->param('source'));
  
  return unless $self->variation;
  
  $self->{'parameters'}{'v'} = $self->variation->name;
  
  my $vf       = $self->param('vf');
  my @features = @{$vardb_adaptor->get_VariationFeatureAdaptor->fetch_all_by_Variation($self->variation)};
  
  return unless @features && (scalar @features == 1 || $vf);
  
  my $var_feat;
  
  # give snp unique identifier
  if (scalar @features == 1) {
    $var_feat = $features[0];
    $self->{'parameters'}{'vf'} = $var_feat->dbID; 
    $self->param('vf', $var_feat->dbID);
  } else {
    ($var_feat) = map $_->dbID eq $vf ? $_ : (), @features;
    $self->{'parameters'}{'vf'} = $vf;
  }
  
  if ($self->variation && !$self->param('r') && !$self->param('region')) {
    my $context    = $self->param('vw') || 500;
    my $s          = $var_feat->start;
    my $e          = $var_feat->end;
    my $r          = $var_feat->seq_region_name;
    my $slice;
    
    eval {
      $slice = $self->_get_slice($r, $s - $context, $e + $context);
    };
    
    $self->location = $slice if $slice;
  }
}

sub _generate_regulation {
  my $self = shift;
  my $funcgen_db     = $self->{'parameters'}{'fdb'} = $self->param('fdb') || 'funcgen';
  my $funcdb_adaptor = $self->database($funcgen_db);
  
  if ($funcdb_adaptor) { 
    $self->regulation = $funcdb_adaptor->get_RegulatoryFeatureAdaptor->fetch_by_stable_id($self->param('rf'));
    
    return unless $self->regulation;
    
    $self->{'parameters'}{'rf'} = $self->regulation->stable_id if $self->regulation->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature');
    
    my $r = $self->regulation->slice->seq_region_name;
    my $s = $self->regulation->start;
    my $e = $self->regulation->end;
    my $slice;
    
    eval {
      $slice = $self->_get_slice($r, $s, $e);
    };
    
    $self->location = $slice if $slice;
  }
}

sub _get_slice {
  my $self = shift;
  my ($r, $s, $e) = @_;
  my $db_adaptor  = $self->database('core');
  
  return unless $db_adaptor;
  
  my $slice_adaptor = $db_adaptor->get_SliceAdaptor;
  my $slice;
  
  eval {
    $slice = $slice_adaptor->fetch_by_region('toplevel', $r, $s, $e);
  };
  
  # Checks to see if top-level as "toplevel" above is correct
  return if $slice && !scalar @{$slice->get_all_Attributes('toplevel')||[]};

  if ($slice && $s < 1 || $e > $slice->seq_region_length) {
    $s = 1 if $s < 1;
    $s = $slice->seq_region_length if $s > $slice->seq_region_length;
    
    $e = 1 if $e < 1;
    $e = $slice->seq_region_length if $e > $slice->seq_region_length;
    
    $slice = undef;
    
    eval {
      $slice = $slice_adaptor->fetch_by_region('toplevel', $r, $s, $e);
    };
  }
  
  return $slice;
}

sub _get_gene_location_from_transcript {
  my ($self, $db_adaptor) = @_;
  
  return unless $self->transcript && $db_adaptor;
  
  $self->gene = $db_adaptor->get_GeneAdaptor->fetch_by_transcript_stable_id($self->transcript->stable_id);
  $self->_generate_location($self->transcript->feature_Slice);        
}

1;
