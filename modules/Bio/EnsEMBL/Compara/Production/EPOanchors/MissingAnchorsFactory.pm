=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Production::EPOanchors::MissingAnchorsFactory

=head1 DESCRIPTION

Runnable to list all the anchor_ids that don't have any alignment (mapping)
onto the given genome_db_id, and flow them in batches on the branch #2.

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::MissingAnchorsFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Iterator;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    $self->param_required('anchor_batch_size');

    my $genome_db_id = $self->param_required('genome_db_id');
    my $sql2 = 'SELECT DISTINCT anchor_id FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id = ?';
    my $aligned_anchor_ids = $self->compara_dba->dbc->sql_helper->execute_simple(
        -SQL    => $sql2,
        -PARAMS => [$genome_db_id],
    );
    my %aligned_anchor_ids = map {$_ => 1} @$aligned_anchor_ids;
    $self->compara_dba->dbc->disconnect_if_idle();

    my $anchor_dba = $self->get_cached_compara_dba('compara_anchor_db');
    my $sql1 = 'SELECT anchor_id, COUNT(*) AS num_seq FROM anchor_sequence GROUP BY anchor_id';
    my $sth1 = $anchor_dba->dbc->prepare($sql1, { 'mysql_use_result' => 1});
    $sth1->execute();

    $self->_init_missing_anchor_ids;
    while (my $row = $sth1->fetch) {
        unless ($aligned_anchor_ids{$row->[0]}) {
            $self->_register_missing_anchor_id(@$row);
        }
    }
    $self->_finalize_missing_anchor_ids;

    $sth1->finish;
    $anchor_dba->dbc->disconnect_if_idle();
}

sub write_output {
    my ($self) = @_;

    foreach my $anchor_ids (@{$self->param('anchor_id_batches')}) {
        $self->dataflow_output_id( {'anchor_ids' => $anchor_ids}, 2 );
    }
}

sub _init_missing_anchor_ids {
    my $self = shift;
    $self->param('anchor_id_batches', []);
    $self->param('anchor_id_buffer',  []);
    $self->param('anchor_seq_count',  0);
}

sub _register_missing_anchor_id {
    my ($self, $anchor_id, $num_sequences) = @_;
    if ($self->param('anchor_seq_count')) {
        if (($self->param('anchor_seq_count') + $num_sequences) > $self->param('anchor_batch_size')) {
            push @{$self->param('anchor_id_batches')}, $self->param('anchor_id_buffer');
            $self->param('anchor_id_buffer', []);
            $self->param('anchor_seq_count', 0);
        }
    }
    push @{$self->param('anchor_id_buffer')}, $anchor_id;
    $self->param('anchor_seq_count', $self->param('anchor_seq_count') + $num_sequences);
}

sub _finalize_missing_anchor_ids {
    my $self = shift;
    push @{$self->param('anchor_id_batches')}, $self->param('anchor_id_buffer') if $self->param('anchor_seq_count');
}


1;

