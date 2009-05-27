package Bio::EnsEMBL::GlyphSet::regulatory_search_regions;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "cisRED search regions"; }

sub my_description { return "cisRED search regions"; }

# This for 
sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    my $slice = $self->{'container'};
    my $fg_db = undef;
    my $db_type  = $self->my_config('db_type')||'funcgen';
    unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
      if(!$fg_db) {
        warn("Cannot connect to $db_type db");
        return [];
      }
    }
 
    my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;  
    my $feature_set = $feature_set_adaptor->fetch_by_name('cisRED search regions'); 
    my $species = $self->{'config'}->{'species'}; 
    if ($species eq 'Drosophila_melanogaster' ){return;} 
   my $external_Feature_adaptor = $fg_db->get_ExternalFeatureAdaptor;
  my $gene = $self->{'config'}->{'_draw_single_Gene'};
 # warn ">>> $gene <<<";
  if( $gene ) {
    my $data =  $feature_set->get_Features_by_Slice($slice);
    return $data;
  } else 
 { 
   foreach my $search_region_feature(@{$feature_set->get_Features_by_Slice($slice)}){
    # warn "Found ".$search_region_feature->feature_type->class."\n";
   }
      return $feature_set->get_Features_by_Slice($slice);
  }
}

sub href {
  my ($self, $f) = @_;
  my $id = $f->display_label;
  my ($start,$end) = $self->slice2sr( $f->start, $f->end );

  my $analysis = $f->analysis->logic_name;
  if ($analysis =~/cisRED/){$analysis = "cisred_search";}
  my $dbid = $f->dbID;

  my $href = $self->_url
  ({'action'    => 'Regulation',
    'fid'       => $id,
    'ftype'     => $analysis,
    'dbid'      => $dbid,
  });

  return $href;
}


# Search regions with similar analyses should be in the same colour

sub colour_key {
  my ($self, $f) = @_;
  my $name = $f->feature_type->name;
  if ($name =~/cisRED\sSearch\sRegion/){return 'cisred_search'; }
  else { return};
}

sub colour {
  my ($self, $f) = @_;
  my $name = $f->analysis->logic_name;
  if ($name =~/cisRED/){$name = "cisred_search";}
  my $colour =  $self->{'config'}->colourmap->{'colour_sets'}->{'regulatory_search_regions'}{$name}[0];
  return $colour if $colour;

  unless ( exists $self->{'config'}{'pool'} ) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  unless( $colour ) {
    $colour = $self->{'config'}{'_regulatory_search_region_colours'}{"$name"} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)  %@{$self->{'config'}{'pool'}} ];
  }
  return $colour;
}



1;
