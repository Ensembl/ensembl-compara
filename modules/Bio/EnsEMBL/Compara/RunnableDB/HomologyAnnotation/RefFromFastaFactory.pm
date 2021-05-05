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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::RefFromFastaFactory

=head1 DESCRIPTION

Fetch correct reference genome fasta files to produce jobs for each pre-split-
fasta file per query diamond database. This runnable is specific to reciprocally
BLASTing the reference genome against an initial query.

Supported parameters:
    'rr_ref_db'     : rapid release reference genome database (mysql) (Mandatory)
    'ref_dumps_dir' : the genome dumps directory for the reference genomes (Mandatory)
    'query_db_name' : the name of the non-reference genome diamond database file (Mandatory)
    'genome_db_id'  : the genome_db_id of the query genome (single genome in ref_fasta) (Mandatory)
    'ref_taxa'      : selected reference species_set name. Default: 'default' (Optional)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::RefFromFastaFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector qw/ collect_species_set_dirs /;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $ref_dba       = $self->param_required('rr_ref_db');
    my $ref_dump_dir  = $self->param_required('ref_dump_dir');
    my $ref_taxa      = $self->param('ref_taxa') ? $self->param('ref_taxa') : 'default';
    my $ref_dir_paths = collect_species_set_dirs($ref_dba, $ref_taxa, $ref_dump_dir);
    my $gdb_adaptor   = $self->compara_dba->get_GenomeDBAdaptor;

    my @all_paths;

    foreach my $ref_gdb_dir ( @$ref_dir_paths ) {
        # Skip the reference genome if it is the same as the target genome
        next if $ref_gdb_dir->{'ref_gdb'}->name eq $gdb_adaptor->fetch_by_dbID($self->param_required('genome_db_id'))->name;
        my $ref_gdb_id   = $ref_gdb_dir->{'ref_gdb'}->dbID;
        my $ref_splitfa  = $ref_gdb_dir->{'ref_splitfa'};
        my @ref_splitfas = glob($ref_splitfa . "/*.fasta");

        push @all_paths, { 'ref_gdb_id' => $ref_gdb_id, 'ref_splitfa' => \@ref_splitfas, 'target_genome_db_id' => $self->param_required('genome_db_id') };
    }

    $self->param('ref_fasta_files', \@all_paths);
}

sub write_output {
    my $self = shift;

    my $ref_members   = $self->param('ref_fasta_files');
    my $query_db_name = $self->param_required('query_db_name');

    foreach my $ref ( @$ref_members ) {
        my $ref_gdb_id     = $ref->{'ref_gdb_id'};
        my $ref_fasta_file = $ref->{'ref_splitfa'};

        foreach my $ref_fasta ( @$ref_fasta_file ) {
            $self->dataflow_output_id( { 'ref_fasta' => $ref_fasta, 'genome_db_id' => $ref_gdb_id, 'blast_db' => $query_db_name, 'target_genome_db_id' => $ref->{'target_genome_db_id'} }, 2 );
        }
    }
}

1;
