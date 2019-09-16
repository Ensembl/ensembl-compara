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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckCanonMembersReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of ProteinTrees pipeline.
Since members are already loaded in a Compara database at this stage, we can simply read the member table.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckCanonMembersReusability;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::CheckGenomeReusability');


sub run_comparison {
    my $self = shift @_;

    return $self->do_one_comparison('members',
        $self->hash_all_canonical_members( $self->param('reuse_dba') ),
        $self->hash_all_canonical_members( $self->compara_dba ),
    );
}


sub hash_all_canonical_members {
    my ($self, $dba) = @_;

    my $sql = q{
        SELECT CONCAT_WS(':',
                   gm.gene_member_id, gm.stable_id, gd.name, gm.dnafrag_start, gm.dnafrag_end, gm.dnafrag_strand,
                   sm.seq_member_id, sm.stable_id, sd.name, sm.dnafrag_start, sm.dnafrag_end, sm.dnafrag_strand,
                   s.md5sum
               )
          FROM (gene_member gm JOIN dnafrag gd USING (dnafrag_id))
          JOIN (seq_member sm JOIN dnafrag sd USING (dnafrag_id) JOIN sequence s USING (sequence_id)) ON seq_member_id=canonical_member_id
         WHERE gm.genome_db_id = ? AND biotype_group = "coding";
    };

    return $self->hash_rows_from_dba($dba, $sql, $self->param('genome_db_id'));
}

1;
