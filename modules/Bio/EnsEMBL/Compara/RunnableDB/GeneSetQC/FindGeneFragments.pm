=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

This Runnable will search for genes that are significantly longer or shorter than
their orthologues based on the the coverage percentage. Genes that have been flagged as "split-genes" by are
ignored by this analysis.
It works by computing for each gene the average coverage of their
orthologues. Genes with an average that fall below a given threshold (and
when the average has been computed against enough species) are reported.

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::get_gene_fragment_stat -longer <1/0>  -genome_db_id <genome_db_id> -coverage_threshold <> -species_threshold <>

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Registry;

=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
    %{ $self->SUPER::param_defaults() },
#  'genome_db_id' => 126,
#  'coverage_threshold'    => 50,  # Genes with a coverage below this are reported
#  'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82',
  
    };
}

=head2 fetch_input

    Description: Use the mlss id to fetch the species set 

=cut

sub fetch_input {
  my $self = shift;
  print "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% find gene fragment stat Runnable\n\n";
  # get the seq_member_id of the split_genes
#  my $query = "SELECT seq_member_id from QC_split_genes where genome_db_id= $self->param_required('genome_db_id')";
  my %split_genes = map{$_ => 1} @{$self->data_dbc->db_handle->selectcol_arrayref('SELECT seq_member_id from QC_split_genes where genome_db_id= ?', undef, $self->param_required('genome_db_id') )};
  print Dumper(%split_genes);
  $self->param('split_genes_hash', \%split_genes);
    #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;
}

sub run {
  my $self = shift;
  my $genome_db_id        = $self->param_required('genome_db_id');
  my $coverage_threshold  = $self->param('coverage_threshold');
  my $species_threshold   = $self->param_required('species_threshold');
  my $split_genes         = $self->param_required('split_genes_hash');
  my $longer  = $self->param('longer');

  # Basically, we run this query and we filter on the Perl-side
    # Note: we could filter "avg_cov" and "n_species" in SQL

    my $sql = ($self->param_required('longer')) ? 'SELECT gm1.stable_id, hm1.gene_member_id, hm1.seq_member_id, COUNT(*) AS n_orth, COUNT(DISTINCT sm2.genome_db_id) AS n_species, AVG(hm1.perc_cov) AS avg_cov 
                    FROM homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) 
                    JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id) 
                    WHERE gm1.genome_db_id = ? AND hm1.gene_member_id != hm2.gene_member_id AND sm2.genome_db_id != gm1.genome_db_id GROUP BY hm1.gene_member_id'
              : 'SELECT gm1.stable_id, hm1.gene_member_id, hm1.seq_member_id, COUNT(*) AS n_orth, COUNT(DISTINCT sm2.genome_db_id) AS n_species, AVG(hm2.perc_cov) AS avg_cov 
                  FROM homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) 
                  JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id) 
                  WHERE gm1.genome_db_id = ? AND hm1.gene_member_id != hm2.gene_member_id AND sm2.genome_db_id != gm1.genome_db_id GROUP BY hm1.gene_member_id';
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db_id);
    while (my $row = $sth->fetchrow_hashref()) {

      # Split genes are known to be fragments, but they have been merged with their counterpart
      next if $split_genes->{$row->{seq_member_id}};

      # We'll only consider the genes that have a low average coverage over a minimum number of species
#      print Dumper($row->{n_species});
#     print "  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n";
#     die;
      next if $row->{avg_cov} >= $coverage_threshold;
      next if $row->{n_species} < $species_threshold;


      warn join("\t", $row->{stable_id}, $row->{n_species}, $row->{n_orth}, $row->{avg_cov}), "\n";
      $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'gene_member_stable_id' => $row->{stable_id}, 'n_species' => $row->{n_species}, 'n_orth' => $row->{n_orth}, 'avg_cov' => $row->{avg_cov} }, 2)

  }
    #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;
}

1;
