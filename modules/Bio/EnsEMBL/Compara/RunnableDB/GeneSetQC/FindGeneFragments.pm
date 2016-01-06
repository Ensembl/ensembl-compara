=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments

=head1 DESCRIPTION

This Runnable will search for genes that are significantly shorter than
their orthologues. Genes that have been flagged as "split-genes" by are
ignored by this analysis.
It works by computing for each gene the average coverage of their
orthologues. Genes with an average that fall below a given threshold (and
when the average has been computed against enough species) are reported.

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments \
 -compara_db mysql://server/mm14_protein_trees_82 -genome_db_id 150

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'coverage_threshold'    => 50,  # Genes with a coverage below this are reported
        'n_species_perc'        => 50,  # The coverage must be computed against at least this proportion of species
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');

    # Compute the minimum number of species to validate the average
    my ($n_genomes) = $self->compara_dba->dbc->db_handle->selectrow_array('SELECT COUNT(*) FROM genome_db WHERE name != "ancestral_sequences"');
    $self->param('species_threshold', $n_genomes*$self->param('n_species_perc')/100.);

    # Fetch the split genes
    my %split_genes = map {$_ => 1} @{ $self->compara_dba->dbc->db_handle->selectcol_arrayref('SELECT seq_member_id FROM split_genes JOIN seq_member USING (seq_member_id) WHERE genome_db_id = ?', undef, $genome_db_id) };
    $self->param('split_genes_hash', \%split_genes);
}

sub run {
    my $self = shift @_;
    
    my $genome_db_id        = $self->param('genome_db_id');
    my $coverage_threshold  = $self->param('coverage_threshold');
    my $species_threshold   = $self->param('species_threshold');
    my $split_genes         = $self->param('split_genes');

    # Basically, we run this query and we filter on the Perl-side
    # Note: we could filter "avg_cov" and "n_species" in SQL
    my $sql = 'SELECT gm1.stable_id, hm1.gene_member_id, hm1.seq_member_id, COUNT(*) AS n_orth, COUNT(DISTINCT sm2.genome_db_id) AS n_species, AVG(hm2.perc_cov) AS avg_cov FROM homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id) WHERE gm1.genome_db_id = ? AND hm1.gene_member_id != hm2.gene_member_id AND sm2.genome_db_id != gm1.genome_db_id GROUP BY hm1.gene_member_id';
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db_id);
    while (my $row = $sth->fetchrow_hashref()) {

        # Split genes are known to be fragments, but they have been merged with their counterpart
        next if $split_genes->{$row->{seq_member_id}};

        # We'll only consider the genes that have a low average coverage over a minimum number of species
        next if $row->{avg_cov} >= $coverage_threshold;
        next if $row->{n_species} < $species_threshold;

        warn join("\t", $row->{stable_id}, $row->{n_species}, $row->{n_orth}, $row->{avg_cov}), "\n";
    }

}

1;
