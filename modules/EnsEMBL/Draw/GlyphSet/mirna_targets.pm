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

package EnsEMBL::Draw::GlyphSet::mirna_targets;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::regulatory_regions);

sub get_features {
  my ($self, $fg_db, $slice) = @_;
  my $mirna_adaptor  = $fg_db->get_MirnaTargetFeatureAdaptor;
  return $mirna_adaptor->fetch_all_by_Slice($slice);
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
  my ($self, $rf) = @_;
  return lc($rf->evidence);
}

1;
