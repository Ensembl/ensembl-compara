=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::MakeDiamondDBPerGenomeDB

=head1 DESCRIPTION

Runnable wrapper for DumpMembersIntoFasta per genome_db and generate DIAMOND database

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::MakeDiamondDBPerGenomeDB;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta');

sub run {
    my $self = shift;
    $self->SUPER::run;

    my $fasta_file    = $self->param_required('fasta_file');
    my $diamond_exe   = $self->param_required('diamond_exe');
    my $query_db_dir  = $self->param_required('query_db_dir');
    my $genome_db_id  = $self->param_required('genome_db_id');
    my $gdb_adaptor   = $self->compara_dba->get_GenomeDBAdaptor;
    my $genome_db     = $gdb_adaptor->fetch_by_dbID($genome_db_id) or $self->die_no_retry("cannot fetch GenomeDB with id" . $genome_db_id);
    my $query_db_name = $query_db_dir . '/' . $genome_db->name . '_' . $genome_db->assembly . '_' .  $genome_db->genebuild;
    my $cmd = "$diamond_exe makedb --in $fasta_file -d $query_db_name";

    if ( !$self->param('dry_run') ) {
        my $run_cmd = $self->run_command($cmd, { 'die_on_failure' => 1 });
    }
    else {
        $self->warning("$cmd has not been executed");
    }

    $self->param('query_db_name', $query_db_name);

}

sub write_output {
    my $self = shift;

    $self->input_job->autoflow(0);
    $self->dataflow_output_id( { 'query_db_name' => $self->param('query_db_name'), 'genome_db_id' => $self->param('genome_db_id') } , 1 );
}

1;
