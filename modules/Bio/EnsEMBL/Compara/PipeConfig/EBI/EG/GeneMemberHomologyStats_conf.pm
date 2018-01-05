=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::GeneMemberHomologyStats_conf

=head1 SYNOPSIS

    init_pipeline.pl 
      Bio::EnsEMBL::Compara::PipeConfig::EGGeneMemberHomologyStats_conf 
      -curr_rel_db mysql://ensrw:XXX\@server/merged_compara_db 
      -collection collection_name

=head1 DESCRIPTION

    A simple pipeline to populate the gene_member_hom_stats table
    for a single collection.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::GeneMemberHomologyStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStats_conf');

sub pipeline_analyses {
  my ($self) = @_;
  
  my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_hom_stats($self);
  $pipeline_analyses->[0]->{'-input_ids'} = [ {
          'db_conn'         => $self->o('curr_rel_db'),
          'collection'      => $self->o('collection'),
          'clusterset_id'   => 'default',
      } ],
  
  return $pipeline_analyses;
}

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes},
    'default' => { 'LSF' => '-q production-rh7' },
  };
}

1;
