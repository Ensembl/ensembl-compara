#$Id: #
package Bio::EnsEMBL::GlyphSet::fg_segmentation_features;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }

sub features {
  my ($self) = @_;
  
  my $slice = $self->{'container'};    
  my $db_type  = $self->my_config('db_type')||'funcgen';
  my $fg_db;  
  
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }
  my $reg_features = $self->fetch_features($fg_db, $slice);

  return $reg_features;
}

sub fetch_features {
  my ($self, $db, $slice ) = @_;

  my $cell_line = $self->my_config('cell_line');  
  my $fsa = $db->get_FeatureSetAdaptor();
  my $cta = $db->get_CellTypeAdaptor;
  my @rf_ref;
  
  if (!$fsa || !$cta) {
    warn ("Cannot get get adaptors: $fsa");
    return [];
  }
  
  my $ctype = $cta->fetch_by_name($cell_line);
  my @fsets = @{$fsa->fetch_all_displayable_by_type('segmentation', $ctype)}; 
  
  if(scalar(@fsets) != 1){
 	  warn("Failed to get unique $cell_line segmentation feature set");
  }
  
  push(@rf_ref, @{$fsets[0]->get_Features_by_Slice($slice)});
  
  $self->{'config'}->{'fg_segmentation_features_legend_features'}->{'fg_segmentation_features'} = { 'priority' => 1020, 'legend' => [] };  
  return \@rf_ref;
}

sub href {
  my ($self, $f) = @_;
  
  my $cell_line = $self->my_config('cell_line');  
  my $dbid      = $f->dbID;

  my $href = $self->_url
  ({'action'   => 'SegFeature',
    'ftype'    => "Regulation",
    'dbid'     => $dbid,
    'species'  => $self->species,
    'fdb'      => 'funcgen',
    'cl'       => $cell_line,
  });

  return $href;
}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name();
  
  if ($type =~/Repressed/){$type = 'predicted_repressed';}
  elsif ($type =~/CTCF/){$type = 'ctcf';}
  elsif ($type =~/Enhancer/){$type = 'predicted_enhancer';}
  elsif ($type =~/Flank/){$type = 'predicted_promoter'}
  elsif ($type =~/TSS/){$type = 'predicted_tss'}
  elsif ($type =~/Transcribed/){$type = 'predicted_region'}
  elsif ($type =~/Weak/){$type = 'predicted_weak'}
  else  {$type = 'default';}
  
  return lc($type);
}
1;