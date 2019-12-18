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

    my $anchor_dba = $self->get_cached_compara_dba('compara_anchor_db');
    my $sql1 = 'SELECT DISTINCT anchor_id FROM anchor_sequence ORDER BY anchor_id';
    my $sth1 = $anchor_dba->dbc->prepare($sql1, { 'mysql_use_result' => 1});
    $sth1->execute();
    my $fetch_sub1 = sub {
        return $sth1->fetchrow_arrayref;
    };
    my $iterator1 = Bio::EnsEMBL::Utils::Iterator->new($fetch_sub1);

    my $genome_db_id = $self->param_required('genome_db_id');
    my $sql2 = 'SELECT DISTINCT anchor_id FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id = ? ORDER BY anchor_id';
    my $sth2 = $self->compara_dba->dbc->prepare($sql2, { 'mysql_use_result' => 1});
    $sth2->execute($genome_db_id);
    my $fetch_sub2 = sub {
        return $sth2->fetchrow_arrayref;
    };
    my $iterator2 = Bio::EnsEMBL::Utils::Iterator->new($fetch_sub2);

    my @missing_anchor_ids;
    while ($iterator1->has_next()) {
        my ($anchor_id1) = @{$iterator1->next()};
        unless ($iterator2->has_next()) {
            while ($iterator1->has_next()) {
                push @missing_anchor_ids, $anchor_id1;
                my ($anchor_id1) = @{$iterator1->next()};
            }
            last;
        }
        my ($anchor_id2) = @{$iterator2->next()};
        while ($iterator1->has_next() and $anchor_id1 < $anchor_id2) {
            push @missing_anchor_ids, $anchor_id1;
            ($anchor_id1) = @{$iterator1->next()};
        }

        if ($anchor_id1 != $anchor_id2) {
            die "Found anchor_id $anchor_id2 in the anchor_align table but it doesn't exist in the anchor_sequence table !";
        }
    }
    $sth1->finish;
    $sth2->finish;

    # All these will have to be flown against every genome
    $self->param('missing_anchor_ids', \@missing_anchor_ids);
}

sub write_output {
    my ($self) = @_;

    my $anchor_batch_size  = $self->param_required('anchor_batch_size');
    my $missing_anchor_ids = $self->param('missing_anchor_ids');
    while (@$missing_anchor_ids){
        my @anchor_ids = splice(@$missing_anchor_ids, 0, $anchor_batch_size);
        $self->dataflow_output_id( {'anchor_ids' => \@anchor_ids}, 2 );
    }
}

1;

