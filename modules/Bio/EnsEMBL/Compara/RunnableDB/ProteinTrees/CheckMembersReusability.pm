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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckMembersReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of ProteinTrees pipeline

Depending on whether it deals with core databases or not, either the exon-set or the sequences will be compared.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckMembersReusability;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use base ('Bio::EnsEMBL::Compara::RunnableDB::CheckGenomeReusability');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},

        # If set to true, the runnable will try to find the genomes
        # (current and previous) in the Registry
        'needs_core_db' => 1,
    }
}


sub run_comparison {
    my $self = shift @_;

    if ($self->comes_from_core_database($self->param('genome_db'))) {
        return $self->do_one_comparison('exons',
            $self->hash_all_exons_from_dba( $self->param('prev_core_dba') ),
            $self->hash_all_exons_from_dba( $self->param('curr_core_dba') ),
        );
    } else {
        return $self->do_one_comparison('sequences',
            hash_all_sequences_from_db( $self->param('reuse_genome_db') ),
            hash_all_sequences_from_file( $self->param('genome_db') ),
        );
    }
}


sub hash_all_exons_from_dba {
    my $self = shift;

    my $dba = shift @_;

    my $sql = qq{
        SELECT CONCAT_WS(":", cs.name, sr.name,
                         g.stable_id, g.seq_region_start, g.seq_region_end, g.seq_region_strand, b.biotype_group,
                         t.stable_id, t.seq_region_start, t.seq_region_end, t.seq_region_strand,
                         p.stable_id, IFNULL(p.seq_start, 'NA'), IFNULL(p.seq_end, 'NA'),
                         e.stable_id, e.seq_region_start, e.seq_region_end
                         )
          FROM gene g
          JOIN biotype b ON g.biotype = b.name
          JOIN seq_region sr USING (seq_region_id)
          JOIN coord_system cs USING (coord_system_id)
          JOIN transcript t USING (gene_id)
          JOIN exon_transcript et USING (transcript_id)
          JOIN exon e USING (exon_id)
          LEFT JOIN translation p ON canonical_translation_id = translation_id
         WHERE cs.species_id =?
    };

    return $self->hash_rows_from_dba($dba, $sql, $dba->species_id());
}

sub hash_all_sequences_from_db {
    my $genome_db = shift;

    my $sql = 'SELECT stable_id, MD5(sequence) FROM seq_member JOIN sequence USING (sequence_id) WHERE genome_db_id = ?';
    my $sth = $genome_db->adaptor->dbc->prepare($sql);
    $sth->execute($genome_db->dbID);

    my %sequence_set = ();

    while(my ($stable_id, $seq_md5) = $sth->fetchrow()) {
        $sequence_set{$stable_id} = lc $seq_md5;
    }

    return \%sequence_set;
}

sub hash_all_sequences_from_file {
    my $genome_db = shift;

    my $prot_seq = $genome_db->db_adaptor->get_protein_sequences;

    my %sequence_set = ();

    foreach my $stable_id (keys %$prot_seq) {
        $sequence_set{$stable_id} = lc md5_hex($prot_seq->{$stable_id}->seq);
    }
    return \%sequence_set;
}

1;
