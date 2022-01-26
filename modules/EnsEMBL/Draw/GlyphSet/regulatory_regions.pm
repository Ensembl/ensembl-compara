=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::regulatory_regions;

### Draws miscellaneous regulatory regions (e.g. cisRED)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::Simple);

sub init {
  my $self = shift;
  $self->{'my_config'}->set('bumped', 1);
}

sub get_data {
  my ($self) = @_;
  my $slice = $self->{'container'};
  my $config = $self->{'config'};
 
  my $fg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }

  my $reg_feats = $self->get_features($fg_db, $slice);

  my $priority = $self->my_config('priority');
  if($priority) {
    my %p;
    $p{$priority->[$_]} = @$priority-$_ for(0..$#$priority);
    $reg_feats = [ sort { $p{$b->feature_type->name} <=> $p{$a->feature_type->name} } @$reg_feats ]; 
  }

  ## Assign this track a "random" colour if none set
  my $default_colour_key = int(rand(16));

  my $features = [];
  my $colour_lookup = {};
  foreach my $rf (@$reg_feats){
    my $label = $rf->display_label;
    my $colour_key = $self->colour_key($rf) || $config->cache($label) || $default_colour_key;
    my $colour = $colour_lookup->{$colour_key};
    unless ($colour) {
      $rf->{'colour_key'} = $colour_key;
      my $colours         = $self->get_colours($rf);
      $colour             = $colours->{'feature'};
    } 
    $colour_lookup->{$colour_key} = $colour;
    ## Now create feature hash
    push @$features, {
                      'start'   => $rf->start,
                      'end'     => $rf->end,
                      'colour'  => $colour,
                      'label'   => $label,
                      'href'    => $self->href($rf, $label),
                      };
  } 

  return [{'features' => $features}];
}

sub get_features {
  my ($self, $fg_db, $slice) = @_;

  my $logic_name = $self->my_config('logic_name')
                   || $self->my_config('description');
  my $fg_a_a =  $fg_db->get_AnalysisAdaptor;
  my $fg_fs_a = $fg_db->get_FeatureSetAdaptor;
  my $analysis = $fg_a_a->fetch_by_logic_name($logic_name);
  my $fsets = $fg_fs_a->fetch_all_by_feature_class('external', 
                                               undef,
                                               {constraints => {analyses => [$analysis]}},
                                              );
  my $external_Feature_adaptor  = $fg_db->get_ExternalFeatureAdaptor;
  return $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $fsets);
}

sub href {
  my ($self, $rf, $id) = @_;
  my $dbid      = $rf->dbID;
  my $analysis  = $rf->analysis->logic_name;
  
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
  my ($self, $rf) = @_;
  my $config = $self->{'config'};

  ## Check if we actually have a configured colour for this feature type
  my $type = lc $rf->feature_type->name;
  $type =~ s/[^a-z0-9]/_/g;
  my $colour = $self->my_colour($type, undef, '');
  return $type if $colour;
}

1;
