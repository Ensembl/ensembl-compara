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

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpAllTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpAllTrees_conf -host compara1

    By default the pipeline dumps the database named "compara_curr" in the registry, but a different database can be given:
    -production_registry /path/to/reg_conf.pl -rel_db compara_db_name

=head1 DESCRIPTION

    A variant of DumpTrees_conf that finds all clustersets and member_types

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpAllTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'pipeline_name'       =>    'dump_all_trees_'.$self->o('rel_with_suffix'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;
    my $pa = $self->_pipeline_analyses();
    $pa->[1]->{'-parameters'} = {
        'inputquery'    => 'SELECT clusterset_id, member_type FROM gene_tree_root WHERE tree_type = "tree" AND ref_root_id IS NULL GROUP BY clusterset_id, member_type',
        'db_conn'       => '#rel_db#',
    };
    return $pa;
}


1;

