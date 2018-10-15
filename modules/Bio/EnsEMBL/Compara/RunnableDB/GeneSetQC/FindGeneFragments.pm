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
use List::Util qw( min max );
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
    %{ $self->SUPER::param_defaults() },
#  'genome_db_id' => 126,
  'coverage_threshold'    => 50,  # Genes with a coverage below this are reported
#  'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82',
  
    };
}

=head2 fetch_input

    Description: Use the mlss id to fetch the species set 

=cut

sub fetch_input {
  my $self = shift;
  print "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% find gene fragment stat Runnable\n\n" if $self->debug(); 
  # get the seq_member_id of the split_genes
  unless($self->param_required('gene_status') eq 'orphaned') { 
    my %split_genes = map{$_ => 1} @{$self->data_dbc->db_handle->selectcol_arrayref('SELECT seq_member_id from gene_member_qc where status = "split-gene" AND genome_db_id= ?', undef, $self->param_required('genome_db_id') )};
    print Dumper(%split_genes) if $self->debug(); 
    $self->param('split_genes_hash', \%split_genes);
    $self->compara_dba->dbc->disconnect_if_idle;
  }
}

sub run {
  my $self = shift;
  my $genome_db_id        = $self->param_required('genome_db_id');

  # Basically, we run this query and we filter on the Perl-side
    # Note: we could filter "avg_cov" and "n_species" in SQL
    my $sql;

    if ($self->param_required('gene_status') eq 'ambiguous_sequence') {
        my $missing_sequence_threshold = $self->param_required('missing_sequence_threshold');

        $sql = 'SELECT gene_member.stable_id as stable_id, seq_member_id, sequence FROM other_member_sequence JOIN seq_member USING (seq_member_id) JOIN gene_member USING (gene_member_id) WHERE seq_member.genome_db_id = ? AND seq_type = "cds" AND sequence LIKE "%N%";';
        my $sth = $self->compara_dba->dbc->prepare($sql);
        $sth->execute($genome_db_id);

        my $regex = 'N{1,}';
        my $seq_length;
        while (my $row = $sth->fetchrow_hashref()) {
            my $stable_id = $row->{stable_id};
            my $sequence = $row->{sequence};
            my $seq_member_id = $row->{seq_member_id};
            my @gaps = _match_all_positions( $regex, \$sequence);
            $seq_length = length($sequence);
            if (_is_very_ambiguous( \@gaps, $seq_length, $missing_sequence_threshold)){
                $self->dataflow_output_id( { 'gene_member_stable_id' => $row->{stable_id}, 'genome_db_id' => $genome_db_id, 'seq_member_id' => $seq_member_id, 'status' => "ambiguous-sequence" }, 2);
            }
        }
    }
    elsif ($self->param_required('gene_status') eq 'orphaned') {
      $sql = 'SELECT mg.stable_id FROM gene_member mg LEFT JOIN gene_tree_node gtn ON (mg.canonical_member_id = gtn.seq_member_id) WHERE gtn.seq_member_id IS NULL AND mg.genome_db_id = ?';
      my $sth = $self->compara_dba->dbc->prepare($sql);
      $sth->execute($genome_db_id);

      while (my $row = $sth->fetchrow_hashref()) {
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'gene_member_stable_id' => $row->{stable_id}, 'status' => "orphaned-gene" }, 2);
      }

    } else {
      my $coverage_threshold  = $self->param_required('coverage_threshold');
      my $species_threshold   = $self->param_required('species_threshold');
      my $split_genes         = $self->param_required('split_genes_hash');
      my $status;
      if ($self->param_required('gene_status') eq 'longer') {
        $status = "long-gene";
        $sql = 'SELECT gm1.stable_id, hm1.gene_member_id, hm1.seq_member_id, COUNT(*) AS n_orth, COUNT(DISTINCT sm2.genome_db_id) AS n_species, AVG(hm1.perc_cov) AS avg_cov 
                    FROM homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) 
                    JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id) 
                    WHERE gm1.genome_db_id = ? AND hm1.gene_member_id != hm2.gene_member_id AND sm2.genome_db_id != gm1.genome_db_id GROUP BY hm1.gene_member_id';
      } elsif ($self->param_required('gene_status') eq 'shorter') {
        $status = "short-gene";
        $sql = 'SELECT gm1.stable_id, hm1.gene_member_id, hm1.seq_member_id, COUNT(*) AS n_orth, COUNT(DISTINCT sm2.genome_db_id) AS n_species, AVG(hm2.perc_cov) AS avg_cov 
                  FROM homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) 
                  JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id) 
                  WHERE gm1.genome_db_id = ? AND hm1.gene_member_id != hm2.gene_member_id AND sm2.genome_db_id != gm1.genome_db_id GROUP BY hm1.gene_member_id';
      } 
    
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


        warn join("\t", $row->{stable_id}, $row->{n_species}, $row->{n_orth}, $row->{avg_cov}), "\n" if $self->debug(); 
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'gene_member_stable_id' => $row->{stable_id}, 'seq_member_id' => $row->{seq_member_id}, 'n_species' => $row->{n_species}, 'n_orth' => $row->{n_orth}, 'avg_cov' => $row->{avg_cov}, 'status' => $status }, 2);

      }
    }
    #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;
}

sub num { $a <=> $b }

sub _match_all_positions {
    my ($regex, $string) = @_;
    my @ret;
    while ($$string =~ /$regex/g) {
        push @ret, [ $-[0], $+[0]-1 ];
    }
    return @ret
}

sub _is_very_ambiguous {
    my $gaps                = $_[0];
    my $seq_length          = $_[1];
    my $ambiguity_threshold = $_[2];

    my $gap_count = 0;
    my %intervals;
    my %control;

    foreach my $gap ( @{ $gaps } ) {
        my ( $from, $to ) = ( $gap->[0], $gap->[1] );
        my ( $new_from, $new_to ) = ( 3*int( $from/3 ), 3*int( $to/3 ) + 2 );
        for ( my $i = $new_from; $i < $new_to; $i++ ) {
            $intervals{$i} = 1;
        }
        $gap_count++;
    }

    my @postitions_to_remove = sort num keys(%intervals);
    my $ratio;

    if (scalar(@postitions_to_remove) > 0){
        my $gap_counter = 0;
        for ( my $i = 0; $i < scalar(@postitions_to_remove); $i++ ) {
            if ( ( $postitions_to_remove[$i] + 1 ) == $postitions_to_remove[ $i + 1 ] ) {
                $control{$gap_counter}{ $postitions_to_remove[$i] } = 1;
            }
            else {
                $control{$gap_counter}{ $postitions_to_remove[$i] } = 1;
                $gap_counter++;
            }
        }

        my $removed_columns_count = 0;
        foreach my $gap (sort keys %control){
            my @positions = sort num keys %{$control{$gap}};
            my $min = min(@positions);
            my $max = max(@positions)+1; #we need to be max + 1 here because of how remove_columns works.
            $removed_columns_count += ($max-$min)+1;
        }

        $ratio = $removed_columns_count/$seq_length;
    }
    else{
        $ratio = 0;
    }

    if ( $ratio > $ambiguity_threshold ) {
        warn("More than 50% of the pairwise alignment is composed of ambiguous sequences (N's)");
        return 1;
    }
    else{
        return 0;
    }

} ## end sub _is_very_ambiguous


1;
