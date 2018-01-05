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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa

=head1 DESCRIPTION

Simple Runnable that flows all the components of a polyploid genome

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'fan_branch_code'   => 2,
    }
}

sub fetch_input {
    my $self = shift @_;

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param_required('genome_db_id')) or die "Could not fetch genome_db with dbID=".$self->param('genome_db_id');
    die $genome_db->name." is not a polyploid !\n" unless $genome_db->is_polyploid;
    $self->param('genome_db', $genome_db);
}


sub write_output {
    my $self = shift;

    # Dataflow the GenomeDBs
    my $principal_genome_db = $self->param('genome_db');
    foreach my $gdb (@{$principal_genome_db->component_genome_dbs}) {
        $self->dataflow_output_id( { 'component_genome_db_id' => $gdb->dbID, 'principal_genome_db_id' => $principal_genome_db->dbID }, $self->param('fan_branch_code'));
    }
}

1;
