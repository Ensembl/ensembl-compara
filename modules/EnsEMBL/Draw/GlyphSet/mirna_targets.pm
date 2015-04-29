=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::mirna_targets;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::regulatory_regions);

sub squish { return 1; }

sub get_feature_sets {
  my ($self, $fg_db) = @_;

  my $logic_name = $self->my_config('logic_name')
                   || $self->my_config('description');
  my $aa  =  $fg_db->get_AnalysisAdaptor;
  my $fsa = $fg_db->get_FeatureSetAdaptor;
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  return $fsa->fetch_all_by_feature_class('mirna_target',undef,{
    constraints => {
      analyses => [$analysis],
    },
  });
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
  my $mirna_adaptor  = $efg_db->get_MirnaTargetFeatureAdaptor;
  my $f = $mirna_adaptor->fetch_all_by_Slice_FeatureSets($slice, \@fsets);

  ## cache colours
  foreach my $feat (@$f){
    $wuc->cache($feat->evidence, lc($feat->evidence));   
  } 

  return $f;
}

sub href {
  my ($self, $f) = @_;
  my $id = $f->display_label;
  my $dbid = $f->dbID;
  my $analysis =  $f->analysis->logic_name;

  my $href = $self->_url
  ({'action'   => 'MicroRnaTarget',
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
  my $colour = $wuc->cache($f->evidence);
  return $colour;
}

1;
