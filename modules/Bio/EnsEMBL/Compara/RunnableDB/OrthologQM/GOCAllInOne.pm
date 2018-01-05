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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GOCAllInOne

=head1 DESCRIPTION

Runnable that will compute all neighbouring scores (the
ortholog_goc_metric table) for a given pair of species
(mlss_id). This is done by running pieces of three other
runnables in the right order and with the right arguments.

This is more efficient for several reasons:

1. Objects (Homology, GeneMembers, etc) are fetched from
the database only once

2. We can use Set::IntervalTree to find all the members
in a given genomic interval. This drastically reduces the
number of queries (queries that were relatively complicated,
i.e. several joins etc)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GOCAllInOne;

use strict;
use warnings;

use Data::Dumper;
use DBI qw(:sql_types);
use Set::IntervalTree;

use Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable;

use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score;

# Needs to be the base because its functions assume $self can run many things
use base ('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs');


sub param_defaults {
    my $self = shift;
    return {
        %{ Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable::param_defaults($self) },

        'goc_reuse_db' => undef,
    }
}


sub fetch_input {
    my $self = shift;

    # IN: goc_mlss_id
    # OUT: ref_species_dbid
    # OUT: non_ref_species_dbid
    # OUT: ortholog_objects
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory::fetch_input($self);

    # IN: goc_mlss_id
    # OUT: homologyID_map (or undef)
    # OUT: prev_goc_hashref (or undef)
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs::fetch_reuse($self);
}


sub run {
    my $self = shift;

    $self->disconnect_from_databases;

    # Build a Set::IntervalTree for each dnafrag with its gene-members
    $self->build_intervaltrees;

    # IN: ref_species_dbid
    # IN: non_ref_species_dbid
    # IN: ortholog_objects
    # OUT: ref_ortholog_info_hashref
    # OUT: non_ref_ortholog_info_hashref
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory::run($self);

    #loop through the preloaded homologies to create a hash table homology id => homology object. this will serve as a look up table
    my %homology_id_2_homology;
    foreach my $ortholog (@{ $self->param('ortholog_objects') }) {
        $homology_id_2_homology{$ortholog->dbID()} = $ortholog;
    }
    $self->param('preloaded_homologs', \%homology_id_2_homology);

    my @goc_scores;
    # Both variable names are used for the same purpose: accumulating rows for the ortholog_goc_metric table
    # List of array-refs: method_link_species_set_id homology_id gene_member_id dnafrag_id goc_score left1 left2 right1 right2
    $self->param('all_goc_score_arrayref', \@goc_scores);
    $self->param('goc_score_arrayref', \@goc_scores);

    # One way ...
    $self->param('ortholog_info_hashref', $self->param('ref_ortholog_info_hashref'));
    $self->run_one_direction;

    # ... and the other
    $self->param('ortholog_info_hashref', $self->param('non_ref_ortholog_info_hashref'));
    my $tmp_species_dbid = $self->param('ref_species_dbid');
    $self->param('ref_species_dbid', $self->param('non_ref_species_dbid'));
    $self->param('non_ref_species_dbid', $tmp_species_dbid);
    $self->run_one_direction;

    # And prepare the array for Ortholog_max_score
    # Select: homology_id, goc_score, method_link_species_set_id
    my @quality_data = map {[$_->{'homology_id'}, $_->{'goc_score'}, $_->{'method_link_species_set_id'}]} @goc_scores;
    $self->param('quality_data', \@quality_data);
}

sub run_one_direction {
    my $self = shift;

    $self->say_with_header(sprintf('Doing %s vs %s', $self->param('ref_species_dbid'), $self->param('non_ref_species_dbid')));

    if ($self->param('prev_goc_hashref')) {

        # IN: ortholog_info_hashref
        # IN: ref_species_dbid
        # IN: preloaded_homologs
        # IN: homologyID_map
        # IN: prev_goc_hashref
        # OUT: goc_score_arrayref
        Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs::_reusable_species($self);

    } else {

        my $ortholog_hashref = $self->param('ortholog_info_hashref');
        my %chr_job;
        while (my ($ref_dnafragID, $chr_orth_hashref) = each(%$ortholog_hashref) ) {
            # will contain the orthologs ordered by the dnafrag start position
            $chr_job{$ref_dnafragID} = Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs::_order_chr_homologs($self, $chr_orth_hashref);
        }
        $self->param('chr_job', \%chr_job);

        # IN: chr_job
        # IN: preloaded_homologs
        # IN: ref_species_dbid
        # IN: non_ref_species_dbid
        # OUT: all_goc_score_arrayref
        Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs::run($self);
    }
}


sub write_output {
    my $self = shift;

    # IN: (none)
    # OUT: (write in ortholog_goc_metric table)
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs::_insert_goc_scores($self, $self->param('goc_score_arrayref'));

    # IN: quality_data
    # IN: goc_mlss_id
    # OUT: (write in homology table)
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score::run($self);
}


sub build_intervaltrees {
    my $self = shift;
    my %interval_trees;
    foreach my $ortholog (@{ $self->param('ortholog_objects') }) {
        foreach my $gene_member (@{$ortholog->get_all_GeneMembers}) {
            unless ($interval_trees{$gene_member->dnafrag_id}) {
                $interval_trees{$gene_member->dnafrag_id} = Set::IntervalTree->new;
            }
            my %data = (
                'gene_member_id'    => $gene_member->dbID,
                'dnafrag_start'     => $gene_member->dnafrag_start,
                'dnafrag_end'       => $gene_member->dnafrag_end,
                'gene_tree_node_id' => $ortholog->_gene_tree_node_id,
                'homology_id'       => $ortholog->dbID,
            );
            $interval_trees{$gene_member->dnafrag_id}->insert(\%data, $gene_member->dnafrag_start, $gene_member->dnafrag_end+1);
        }
    }
    $self->param('interval_trees', \%interval_trees);
}

sub _fetch_members_with_homology_by_range {   ## OVERRIDE
    my $self = shift;
    my ($dnafragID, $st, $ed) = @_;
    # fetch_window has issues with overlapping input intervals, so we need
    # to use fetch instead and do some filtering ourselves
    #return $self->param('interval_trees')->{$dnafragID}->fetch_window($st, $ed);
    my $members = $self->param('interval_trees')->{$dnafragID}->fetch($st, $ed+1);
    $members = [grep {($_->{dnafrag_start} >= $st) and ($_->{dnafrag_end} <= $ed)} @$members];
    return $members;
}


1;

