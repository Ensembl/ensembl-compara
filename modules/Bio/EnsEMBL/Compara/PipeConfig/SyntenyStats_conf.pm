=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf \
        -compara_db compara_curr -division $COMPARA_DIV -mlss_id_list '[1234,5678]' \
        -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION  

Calculate synteny coverage statistics for the specified MLSSes.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::SyntenyStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name' => $self->o('division') . '_synteny_stats_' . $self->o('rel_with_suffix'),

        'compara_db'    => 'compara_curr',
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    'compara_db' => $self->o('compara_db'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name      => 'FlowMLSS',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count => 0,
      -input_ids  => [
          {
              'inputlist' => destringify($self->o('mlss_id_list')),
              'column_names' => [ 'mlss_id' ],
          }
      ],
      -flow_into       => { 2 => 'SyntenyStats'},
    },
    
    {
      -logic_name      => 'SyntenyStats',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::SyntenyStats',
      -max_retry_count => 0,
      -flow_into       => {
          -1 => 'synteny_stats_himem',
          -2 => 'synteny_stats_himem',
      },
      -rc_name         => '1Gb_job',
    },

    {
      -logic_name      => 'synteny_stats_himem',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::SyntenyStats',
      -max_retry_count => 0,
      -rc_name         => '4Gb_24_hour_job',
    },
    
  ];
}

1;
