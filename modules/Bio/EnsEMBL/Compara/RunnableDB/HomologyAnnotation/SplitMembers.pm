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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SplitMembers

=head1 DESCRIPTION

Dataflow seq_member_ids in batches

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SplitMembers;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'step'   => 1000,
    }
}

sub fetch_input {
    my $self = shift;

    my $query_gdb_id   = $self->param_required('genome_db_id');
    my $hit_gdb_id     = $self->param_required('target_genome_db_id');

    my $seq_members    = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($query_gdb_id);
    my @seq_member_ids = map {$_->dbID} @$seq_members;

    $self->param('full_member_id_list', \@seq_member_ids);

}

sub write_output {
    my $self = shift;

    my $query_gdb_id   = $self->param_required('genome_db_id');
    my $hit_gdb_id     = $self->param_required('target_genome_db_id');
    my $seq_member_ids = $self->param('full_member_id_list');
    my $step           = $self->param('step');

    while ( my @member_id_list = splice @$seq_member_ids, 0, $step ) {
        # A job is output for every $step query members against each reference diamond db
        my $output_id = { 'member_id_list' => \@member_id_list, 'genome_db_id' => $query_gdb_id, 'target_genome_db_id' => $hit_gdb_id};
        $self->dataflow_output_id($output_id, 2);
    }
}

1;
