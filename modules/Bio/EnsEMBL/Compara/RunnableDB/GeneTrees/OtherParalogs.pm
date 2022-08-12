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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs

=head1 DESCRIPTION

This analysis will load a super gene tree and insert the
extra paralogs into the homology tables.

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otherparalogs = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$otherparalogs->fetch_input(); #reads from DB
$otherparalogs->run();
$otherparalogs->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Utils::Preloader;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_column_integrity);

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'genome_db_id'  => undef,   # Only store the paralogs of this genome_db_id, if set
    };
}


sub fetch_input {
    my $self = shift;
    $self->SUPER::fetch_input;

    my $alignment_id = $self->param('gene_tree')->tree->gene_align_id;
    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $aln);

    my %super_align;
    foreach my $member (@{$aln->get_all_Members}) {
        bless $member, 'Bio::EnsEMBL::Compara::GeneTreeMember';
        $super_align{$member->seq_member_id} = $member;
    }

    if (!$self->param('genome_db_id') && (scalar(keys %super_align) >= 5000) && $self->input_job->analysis->dataflow_rules_by_branch->{3}) {
        my %genome_db_ids;
        foreach my $member (values %super_align) {
            my $gdb = $member->genome_db;
            $gdb = $gdb->principal_genome_db if $gdb->genome_component;
            $genome_db_ids{ $gdb->dbID} = 1;
        }
        foreach my $gdb_id (keys %genome_db_ids) {
            # alignment_id and aln_length are not propagated because they are not needed
            my $params = {'genome_db_id' => $gdb_id, 'gene_tree_id' => $self->param('gene_tree_id')};
            if ($self->param('output_flatfile')) {
                # Prefix the output flatfile name with the genome_db_id to ensure uniqueness
                my $gdb_outfile = $self->param('output_flatfile');
                $gdb_outfile =~ s/\/([^\/]+)$/\/$gdb_id.$1/;
                $params->{output_flatfile} = $gdb_outfile;
            }
            $self->dataflow_output_id($params, 3);
        }
        $self->complete_early('Too many genes, breaking up the task to 1 job per genome_db_id');
    }

    $self->param('super_align', \%super_align);
    $self->param('homology_consistency', {});
    $self->param('homology_links', []);

    unless ($self->param('_readonly')) {
        if ($self->param('genome_db_id')) {
            $self->delete_old_paralogies;
        } else {
            $self->delete_old_homologies;
        }
    }

    my %gdb_id2stn = ();
    foreach my $taxon (@{$self->param('gene_tree')->tree->species_tree->root->get_all_leaves}) {
        $gdb_id2stn{$taxon->genome_db_id} = $taxon;
    }
    $self->param('gdb_id2stn', \%gdb_id2stn);
}

sub write_output {
    my $self = shift @_;

    $self->_create_flatfile if $self->param('output_flatfile');

    $self->run_analysis;
    $self->print_summary;

    check_column_integrity($self->param('output_flatfile')) if $self->param('output_flatfile');
}


sub delete_old_paralogies {
    my $self = shift;

    my $outfile = $self->param('output_flatfile');
    if ( defined $outfile && -e $outfile ) {
        unlink $outfile;
        return;
    }

    my $tree_node_id = $self->param('gene_tree_id');
    my $genome_db_id = $self->param('genome_db_id');

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_PARALOGUES', [$genome_db_id]);
    die "Cannot find ENSEMBL_PARALOGUES mlss for genome_db_id=$genome_db_id\n" unless $mlss;

    # New method all in one go -- requires key on method_link_species_set_id
    print "deleting old paralogies for genome_db_id=$genome_db_id\n" if ($self->debug);

    # Delete first the members
    my $sql1 = 'DELETE homology_member FROM homology JOIN homology_member USING (homology_id) WHERE gene_tree_root_id = ? AND method_link_species_set_id = ?';
    $self->compara_dba->dbc->do($sql1, undef, $tree_node_id, $mlss->dbID);

    # And then the homologies
    my $sql2 = 'DELETE FROM homology WHERE gene_tree_root_id = ? AND method_link_species_set_id = ?';
    $self->compara_dba->dbc->do($sql2, undef, $tree_node_id, $mlss->dbID);

#    my $homology_ids = $self->compara_dba->dbc->sql_helper->execute_simple(
#        -SQL => 'SELECT homology_id FROM homology WHERE gene_tree_root_id = ? AND method_link_species_set_id = ?',
#        -PARAMS => [$tree_node_id, $mlss->dbID],
#    );
#    my $sql1 = 'DELETE FROM homology_member WHERE homology_id = ?';
#    my $sth1 = $self->compara_dba->dbc->prepare($sql1);
#    my $sql2 = 'DELETE FROM homology WHERE homology_id = ?';
#    my $sth2 = $self->compara_dba->dbc->prepare($sql2);
#    foreach my $h (@$homology_ids) {
#        # Delete first the members
#        $sth1->execute($h);
#        # And then the homologies
#        $sth2->execute($h);
#    }
#    $sth1->finish;
#    $sth2->finish;
}


=head2 run_analysis

    This function will create all the links between two genes from two different sub-trees, and from the same species

=cut

sub run_analysis {
    my $self = shift;

    my $starttime = time()*1000;
    my $gene_tree = $self->param('gene_tree');

    my $tmp_time = time();
    print "build paralogs graph\n" if ($self->debug);
    $gene_tree->adaptor->dbc->disconnect_if_idle;
    my $ngenepairlinks = $self->rec_add_paralogs($gene_tree);
    print "$ngenepairlinks pairings\n" if ($self->debug);

    printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);
    #display summary stats of analysis 
    my $runtime = time()*1000-$starttime;  
    $gene_tree->tree->store_tag('OtherParalogs_runtime_msec', $runtime) unless ($self->param('_readonly'));
}

sub rec_add_paralogs {
    my $self = shift;
    my $ancestor = shift;

    # Skip the terminal nodes
    return 0 unless $ancestor->get_child_count;

    my ($child1, $child2) = @{$ancestor->children};
    $child1->adaptor->dbc->disconnect_if_idle;
    $child2->adaptor->dbc->disconnect_if_idle;

    # All the homologies will share this information
    my $this_taxon = $ancestor->get_value_for_tag('species_tree_node_id');

    # Set node_type
    unless ($self->param('_readonly')) {
        if ($ancestor->get_value_for_tag('is_dup', 0)) {
            $ancestor->store_tag('node_type', 'duplication');
            my $duplication_confidence_score = $self->duplication_confidence_score($ancestor);
            $ancestor->store_tag("duplication_confidence_score", $duplication_confidence_score);
        } elsif (($child1->get_value_for_tag('species_tree_node_id') == $this_taxon) or ($child2->get_value_for_tag('species_tree_node_id') == $this_taxon)) {
            $ancestor->store_tag('node_type', 'dubious');
            $ancestor->store_tag('duplication_confidence_score', 0);
        } else {
            # Very unlikely to be the same species, no need to consider "sub-speciation"
            $ancestor->store_tag('node_type', 'speciation');
            $ancestor->delete_tag('duplication_confidence_score');
        }
        print "setting node_type to ", $ancestor->get_value_for_tag('node_type'), "\n" if ($self->debug);
    }
    my $ngenepairlinks = $self->add_other_paralogs_for_pair($ancestor, $child1, $child2);
    $ngenepairlinks += $self->rec_add_paralogs($child1);
    $ngenepairlinks += $self->rec_add_paralogs($child2);
    return $ngenepairlinks;
}


sub add_other_paralogs_for_pair {
    my $self = shift;
    my $ancestor = shift;
    my $child1   = shift;
    my $child2   = shift;

    $ancestor->print_node if ($self->debug);
    $child1->print_node if ($self->debug);
    $child2->print_node if ($self->debug);

    # Each species
    my $ngenepairlinks = 0;
    my @genome_db_ids;
    if (my $genome_db_id = $self->param('genome_db_id')) {
        my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
        if ($genome_db->is_polyploid) {
            @genome_db_ids = map {$_->dbID} @{$genome_db->component_genome_dbs};
        } else {
            @genome_db_ids = ($genome_db_id);
        }
        @genome_db_ids = grep {$ancestor->get_value_for_tag('gene_hash')->{$_}} @genome_db_ids;
    } else {
        @genome_db_ids = keys %{$ancestor->get_value_for_tag('gene_hash')};
    }
    foreach my $genome_db_id (@genome_db_ids) {
        # Each gene from the sub-tree 1
        foreach my $gene1 (@{$child1->get_value_for_tag('gene_hash')->{$genome_db_id}}) {
            # Each gene from the sub-tree 2
            foreach my $gene2 (@{$child2->get_value_for_tag('gene_hash')->{$genome_db_id}}) {
                my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2, 0);
                $genepairlink->add_tag("ancestor", $ancestor);
                $genepairlink->add_tag("orthotree_type", 'other_paralog');
                $genepairlink->add_tag("is_tree_compliant", 1);
                $ngenepairlinks++;
                $self->store_gene_link_as_homology($genepairlink) if $self->param('store_homologies');
                $genepairlink->dealloc;
            }
        }
    }
    $self->param('orthotree_homology_counts')->{'other_paralog'} += $ngenepairlinks;
    print "$ngenepairlinks links on node_id=", $ancestor->node_id, " between node_id=", $child1->node_id, " and node_id=", $child2->node_id, "\n";
    return $ngenepairlinks;
}


=head2 duplication_confidence_score

    Super-trees lack the duplication confidence scores, and we have to compute them here

=cut

sub duplication_confidence_score {
  my $self = shift;
  my $ancestor = shift;

  # This assumes bifurcation!!! No multifurcations allowed
  my ($child_a, $child_b, $dummy) = @{$ancestor->children};
  $self->throw("tree is multifurcated in duplication_confidence_score\n") if (defined($dummy));
  my @child_a_gdbs = keys %{$self->get_ancestor_species_hash($child_a)};
  my @child_b_gdbs = keys %{$self->get_ancestor_species_hash($child_b)};
  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @child_a_gdbs;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @child_b_gdbs;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) {
    push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
  }

  my $duplication_confidence_score = 0;
  my $scalar_isect = scalar(@isect);
  my $scalar_union = scalar(@union);
  $duplication_confidence_score = (($scalar_isect)/$scalar_union) unless (0 == $scalar_isect);

  return $duplication_confidence_score;
}



=head2 get_ancestor_species_hash

    This function is optimized for super-trees:
     - It fetches all the gene tree leaves
     - It is able to jump from a super-tree to the sub-trees
     - It stores the list of all the leaves to save DB queries

=cut

sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_value_for_tag('species_hash');
    return $species_hash if($species_hash);

    print $node->node_id, " is a ", $node->tree->tree_type, "\n" if ($self->debug);
    my $gene_hash = {};
    my @sub_taxa = ();

    if ($node->is_leaf) {
  
        # Super-tree leaf
        $node->adaptor->fetch_all_children_for_node($node);
        print "super-tree leaf=", $node->node_id, " children=", $node->get_child_count, "\n";
        my $child = $node->children->[0];
        my $leaves = $self->compara_dba->get_GeneTreeNodeAdaptor->fetch_all_AlignedMember_by_root_id($child->node_id);
        unless (@$leaves) {
            # $child is actually a supertree. Need to fetch its own sub-trees
            $leaves = [];
            print "going deeper\n";
            my $subsupertree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($child->node_id);
            my $subsubtrees = $self->compara_dba->get_GeneTreeAdaptor->fetch_subtrees($subsupertree);
            foreach my $subsubtree (@$subsubtrees) {
                push @$leaves, @{ $self->compara_dba->get_GeneTreeNodeAdaptor->fetch_all_AlignedMember_by_root_id($subsubtree->root_id) };
            }
            print "super-tree leaf=", $node->node_id, " subtrees=", scalar(@$subsubtrees), " children=", scalar(@$leaves), "\n";
        }
        $child->disavow_parent;

        foreach my $leaf (@$leaves) {
            print $leaf->toString, "\n" if ($self->debug);
            $species_hash->{$leaf->genome_db_id} = 1 + ($species_hash->{$leaf->genome_db_id} || 0);
            push @sub_taxa, $self->param('gdb_id2stn')->{$leaf->genome_db_id};
            push @{$gene_hash->{$leaf->genome_db_id}}, $self->param('super_align')->{$leaf->seq_member_id};
        }
   
    } else {

        # Super-tree root
        print "super-tree root=", $node->node_id, " children=", $node->get_child_count, "\n";
        my $is_dup = 0;
        foreach my $child (@{$node->children}) {
            print "child: ", $child->node_id, "\n" if ($self->debug);
            my $t_species_hash = $self->get_ancestor_species_hash($child);
            push @sub_taxa, $child->get_value_for_tag('lca_taxon');
            foreach my $genome_db_id (keys(%$t_species_hash)) {
                $is_dup ||= (exists $species_hash->{$genome_db_id});
                $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id} + ($species_hash->{$genome_db_id} || 0);
                push @{$gene_hash->{$genome_db_id}}, @{$child->get_value_for_tag('gene_hash')->{$genome_db_id}};
            }
        }

        $node->add_tag("is_dup", $is_dup);
 
    }

    my $lca_taxon = shift @sub_taxa;
    foreach my $this_taxon (@sub_taxa) {
        $lca_taxon = $lca_taxon->find_first_shared_ancestor($this_taxon);
    }

    printf("%s is a '%s' and contains %d species\n", $node->node_id, $lca_taxon->node_name, scalar(keys %$species_hash)) if ($self->debug);
    $node->add_tag("species_hash", $species_hash);
    $node->add_tag("gene_hash", $gene_hash);
    $node->add_tag('lca_taxon', $lca_taxon);

    if (!$node->is_leaf) {
    $node->store_tag('species_tree_node_id', $lca_taxon->node_id) unless $self->param('_readonly');
    }

    return $species_hash;
}

1;
