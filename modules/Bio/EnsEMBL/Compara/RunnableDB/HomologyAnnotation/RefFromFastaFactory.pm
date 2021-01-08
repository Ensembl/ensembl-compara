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

...

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::RefFromFastaFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $ref_dba       = $self->param_required('rr_ref_db');
    my $ref_dump_dir  = $self->param_required('ref_dumps_dir');
    my $genome_db_id  = $self->param_required('genome_db_id'); #query genome_db_id
    my $ref_taxa      = $self->param('ref_taxa') ? $self->param('ref_taxa') : 'default';
    my $ref_dir_paths = collect_species_set_dirs($ref_dba, $ref_taxa);
    my $query_dmnd_db = $gdb->get_dmnd_helper();
    my @all_paths;

    foreach my $ref_gdb_dir ( @$dir_paths ) {

        my $ref_gdb_id   = $ref_gdb_dir->{'ref_gdb'}->dbID;
        my $ref_splitfa  = $ref_dump_dir . '/' . $ref_gdb_dir->{'ref_splitfa'};
        my @ref_splitfas = glob($ref_splitfa . "/*.fasta");

        push @all_paths, { 'ref_gdb_id' => $ref_gdb_id, 'ref_splitfa' => \@ref_splitfas };
    }

    $self->param('ref_fasta_files', \@all_paths);
}

sub write_output {
    my $self = shift;

    my $ref_members = $self->param('ref_fasta_files');

    foreach my $ref ( @$ref_fasta_files ) {
        my $ref_gdb_id     = $ref_fasta->{'ref_gdb_id'};
        my $ref_fasta_file = $ref_fasta->{'ref_splitfa'};
        foreach my $ref_fasta ( @$ref_fasta_file ) {
            $self->dataflow_output_id( { 'ref_fasta' => $ref_fasta, 'genome_db_id' => $ref_gdb_id }, 2 );
        }
    }
}

1;
