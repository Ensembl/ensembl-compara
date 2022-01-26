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

package EnsEMBL::Web::ZMenu::Transcript_sf;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $db           = $hub->param('fdb') || $hub->param('db') || 'core'; 
  my $db_adaptor   = $hub->database(lc $db);
  my $object_type  = $hub->param('ftype');
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;
  my $features     = $feat_adap->fetch_all_by_Slice($object->slice,$hub->param('ln'));

  $self->caption($hub->param('id'));

  $self->add_entry({
    type  => 'Location',
    label => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end,
  });

  $self->add_entry({
    type  => 'Score',
    label => $features->[0]->score,
  });

  $self->add_entry({
    label_html => $features->[0]->analysis->description
  });
}

1;
