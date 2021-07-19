=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::AltSeqAlignment;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;

  my $hub          = $self->hub;
  my $id           = $hub->param('id');
  my $db           = $hub->param('db') || 'core';
  my $object_type  = $hub->param('ftype');
  my $logic_name   = $hub->param('ln');
  my $db_adaptor   = $hub->database(lc($db));
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;

  my $feature = $feat_adap->fetch_by_dbID($id); 
  my $external_db_id = $feature->can('external_db_id') ? $feature->external_db_id : '';
  my $extdbs         = $external_db_id ? $hub->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
  my $hit_db_name    = $extdbs->{$external_db_id}->{'db_name'} || 'External Feature';
  my $ref_seq_name  = $feature->display_id;
  my $ref_seq_start = $feature->hstart < $feature->hend ? $feature->hstart : $feature->hend;
  my $ref_seq_end   = $feature->hend < $feature->hstart ? $feature->hstart : $feature->hend;
  my $ref_location .= $ref_seq_name .':' .$ref_seq_start . '-' . $ref_seq_end;
  my $hit_strand    = $feature->hstart > $feature->hend  ? '(- strand)' : '(+ strand)';

  $self->caption("$ref_location ($hit_db_name)");


  $self->add_entry ({
    label   => "$ref_location $hit_strand",
    link    => $hub->url({
      type    => 'Location',
      action  => 'View',
      r       => $ref_location,
      __clear => 1
    })
  });  

  $self->add_entry({
    label => 'View all hits',
    link  => $hub->url({
      type        => 'Location',
      action      => 'Genome',
      ftype       => 'DnaAlignFeature',
      logic_name  => 'alt_seq_mapping',
      id          => $feature->slice->seq_region_name,
      __clear     => 1
    })
  });

}

1;
