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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::TranslationHealthcheck

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::TranslationHealthcheck;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $compara_dba = $self->compara_dba;
    my $genome_dba = $compara_dba->get_GenomeDBAdaptor();
    my $dnafrag_dba = $compara_dba->get_DnaFragAdaptor();
    my $gene_member_dba = $compara_dba->get_GeneMemberAdaptor();

    my $genome_db = $genome_dba->fetch_by_dbID($genome_db_id);
    my $core_dba = $genome_db->db_adaptor;
    my $translation_adaptor = $core_dba->get_TranslationAdaptor();

    my $num_mismatches = 0;
    foreach my $dnafrag (@{$dnafrag_dba->fetch_all_by_GenomeDB($genome_db)}) {

        foreach my $gene_member (@{$gene_member_dba->fetch_all_by_DnaFrag($dnafrag)}) {
            next unless $gene_member->biotype_group eq 'coding';

            my $seq_member = $gene_member->get_canonical_SeqMember();
            next unless defined $seq_member;

            my $translation = $translation_adaptor->fetch_by_stable_id($seq_member->stable_id);

            if (defined $translation) {

                if ($seq_member->sequence ne $translation->seq) {
                    $num_mismatches += 1;
                    if ($self->debug) {
                        $self->warning(
                            sprintf(
                                "Canonical sequence of %s gene member '%s' does not match its corresponding translation in the core database.",
                                $genome_db->name,
                                $gene_member->stable_id,
                            )
                        );
                    }
                }

            } else {
                $num_mismatches += 1;
                if ($self->debug) {
                    $self->warning(
                        sprintf(
                            "Canonical sequence of %s gene member '%s' has no corresponding translation in the core database.",
                            $genome_db->name,
                            $gene_member->stable_id,
                        )
                    );
                }
            }
        }
    }

    if ($num_mismatches > 0) {
        $self->die_no_retry(
            sprintf(
                "GenomeDB %s has %d gene members with a canonical protein sequence mismatch.",
                $genome_db->name,
                $num_mismatches,
            )
        );
    }
}


1;
