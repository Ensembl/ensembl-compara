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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindOrphans

=head1 DESCRIPTION

Here we expect that a gene should be in a tree and a family, mixed with
other genes from other species. This Runnable reports the genes that don't
follow this rule.

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindOrphans \
 -compara_db mysql://server/mm14_protein_trees_82 -genome_db_id 150

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindOrphans;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my $self = shift @_;

    my $sql_no_trees = q{SELECT stable_id FROM gene_member LEFT JOIN gene_tree_node ON canonical_member_id = seq_member_id WHERE genome_db_id = ? AND node_id IS NULL AND};
    my $sql_species_only_trees = q{SELECT stable_id FROM gene_member JOIN gene_tree_node gtn ON canonical_member_id = gtn.seq_member_id JOIN (SELECT root_id FROM gene_tree_node JOIN seq_member USING (seq_member_id) JOIN gene_tree_root USING (root_id) WHERE clusterset_id = "default" GROUP BY root_id HAVING COUNT(genome_db_id) = SUM(genome_db_id = ?)) t USING (root_id) WHERE};
    my $sql_normal_trees = q{SELECT stable_id FROM gene_member JOIN gene_tree_node gtn ON canonical_member_id = gtn.seq_member_id JOIN (SELECT root_id FROM gene_tree_node JOIN seq_member USING (seq_member_id) JOIN gene_tree_root USING (root_id) WHERE clusterset_id = "default" GROUP BY root_id HAVING COUNT(DISTINCT genome_db_id) > 1) t USING (root_id) WHERE genome_db_id = ? AND};

    # Add this to the above queries to restrict the search to prot / rna
    my $sql_prot_member = q{ biotype_group = "coding"};
    my $sql_rna_member = q{ biotype_group LIKE "%noncoding"};

    # Even though the family pipeline takes all the proteins into account,
    # we only use the canonical ones here 1) to allow the comparison with
    # the gene-trees and 2) because the other proteins have different
    # structures which causes them to be clustered differently
    my $sql_fam_wrapper = q{SELECT stable_id FROM family_member JOIN (%s) t USING (family_id) JOIN gene_member ON canonical_member_id = seq_member_id WHERE genome_db_id = ?};
    my $sql_fam_count_template = q{SELECT family_id FROM family_member JOIN seq_member USING (seq_member_id) GROUP BY family_id HAVING COUNT(*) %s 1 AND COUNT(*) %s SUM(genome_db_id IS NOT NULL AND genome_db_id = ?)};
    my $sql_fam_singlespec = sprintf($sql_fam_count_template, '>', '=');
    my $sql_fam_singleton = sprintf($sql_fam_count_template, '=', '=');
    my $sql_fam_normal = sprintf($sql_fam_count_template, '>', '>');
    my $sql_no_fam = q{SELECT stable_id FROM gene_member LEFT JOIN family_member ON canonical_member_id = seq_member_id WHERE genome_db_id = ? AND family_id IS NULL};

    # Let's do the RNAs first
    $self->_group_analyze([
        #[ 'no_trees', $sql_no_trees.$sql_rna_member],     # We only build trees on ncRNAs that are in RFAM and some others that are in mirBase, but we know we're missing a lot
        [ 'single_species_trees', $sql_species_only_trees.$sql_rna_member ],
    ]);

    # And now the proteins
    $self->_group_analyze([
        [ 'no_trees', $sql_no_trees.$sql_prot_member ],
        [ 'single_species_trees', $sql_species_only_trees.$sql_prot_member ],
        [ 'normal_trees', $sql_normal_trees.$sql_prot_member ],
        [ 'no_families', $sql_no_fam ],
        [ 'normal_families', sprintf($sql_fam_wrapper, $sql_fam_normal) ],
        [ 'singleton_families', sprintf($sql_fam_wrapper, $sql_fam_singleton) ],
        [ 'single_species_families', sprintf($sql_fam_wrapper, $sql_fam_singlespec) ],
    ]);

}

sub _group_analyze {
    my ($self, $named_queries) = @_;

    my %no_support = ();
    foreach my $nq (@$named_queries) {
        my ($name, $query) = @$nq;
        map {$self->_add_info(\%no_support, $_->[0], $name)} @{$self->compara_dba->dbc->db_handle->selectall_arrayref($query, undef, ($self->param('genome_db_id')) x ($query =~ tr/?/?/))};
    }

    # Categories that should not be reported
    # e.g. normal cases and ncRNAs that have no families
    my %skip = map {$_ => 1} qw(no_families normal_trees/normal_families);
    while (my ($gene,$reasons) = each(%no_support)) {
        next if $skip{$reasons};
        $self->dataflow_output_id( { gene_stable_id => $gene, status => $reasons }, 2);
    }
}

sub _add_info {
    my ($self, $no_support, $gene, $reason) = @_;
    if (exists $no_support->{$gene}) {
        $no_support->{$gene} .= '/'.$reason unless $no_support->{$gene} =~ /$reason/;
    } else {
        $no_support->{$gene} = $reason;
    }
}

1;
