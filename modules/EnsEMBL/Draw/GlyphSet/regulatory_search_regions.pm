=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::regulatory_search_regions;

### GlyphSet specifically for the cisRED search regions track

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

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
  ({'action'    => 'RegFeature',
    'fid'       => $id,
    'ftype'     => $analysis,
    'dbid'      => $dbid,
    'species'   => $self->species,
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
