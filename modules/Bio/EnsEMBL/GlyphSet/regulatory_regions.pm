package Bio::EnsEMBL::GlyphSet::regulatory_regions;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }

sub get_feature_sets {
  my ($self, $fg_db) = @_;
  my @fsets;
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;
  my $logic_name = $self->my_config('logic_name') || $self->my_config('description'); 

  if ($logic_name =~/Nested/){$logic_name = 'BioTIFFIN';} 
  my @sources = @{$self->{'config'}->species_defs->databases->{'DATABASE_FUNCGEN'}->{'FEATURE_SETS'}};
  foreach my $name ( @sources){ 
    next if  $name =~ /cisRED\s+search\s+regions/;
    if ($name =~/$logic_name/ || $logic_name =~/$name/ ) {
      push @fsets, $feature_set_adaptor->fetch_by_name($name);
    }
  }
  
  return \@fsets;
}

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};
  my $wuc = $self->{'config'};
 
  my $efg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $efg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$efg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }


  my @fsets = @{$self->get_feature_sets($efg_db)}; 
  my $external_Feature_adaptor  = $efg_db->get_ExternalFeatureAdaptor;
  my $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, \@fsets);

  # count used for colour assignment
  my $count = 0;
  foreach my $feat (@$f){
    $wuc->cache($feat->display_label, $count);   
    $count ++;
    if ($count >= 15) {$count = 0;} 
  } 

  return $f;
}

sub href {
  my ($self, $f) = @_;
  my $id = $f->display_label;
  my $dbid = $f->dbID;
  my $analysis =  $f->analysis->logic_name;

  my $href = $self->_url
  ({'action'   => 'RegFeature',
    'fid'      => $id,
    'ftype'    => $analysis,
    'dbid'     => $dbid, 
    'species'  => $self->species, 
  });

  return $href;
}



sub colour_key {
  my ($self, $f) = @_;
  my $wuc = $self->{'config'}; 
  my $colour = $wuc->cache($f->display_label); 
  return $colour;
}



1;
