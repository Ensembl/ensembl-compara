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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf

=head1 DESCRIPTION  

Calculate synteny coverage statistics.

=head1 SYNOPSIS

 $ init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf -reg_conf ${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline/production_reg_conf.pl -host compara1 -division compara_prev

=cut

package Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'synteny_stats_'.$self->o('ensembl_release'),
    division      => 'Multi',
    mlss_id       => undef,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    division => $self->o('division'),
    reg_conf => $self->o('reg_conf'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name      => 'FetchMLSS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::FetchMLSS',
      -max_retry_count => 0,
      -parameters      => {
                            mlss_id  => $self->o('mlss_id'),
                          },
      -input_ids       => [ {} ],
      -flow_into       => ['SyntenyStats'],
    },
    
    {
      -logic_name      => 'SyntenyStats',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats',
      -max_retry_count => 0,
    },
    
  ];
}

1;
