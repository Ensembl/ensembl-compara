#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthoTree

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otree = Bio::EnsEMBL::Compara::RunnableDB::OrthoTree->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$otree->fetch_input(); #reads from DB
$otree->run();
$otree->output();
$otree->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a rooted tree with duplication/sepeciation tags on the nodes.  
It analyzes that tree structure to pick Orthologues and Paralogs.

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthoTree;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Graph::Node;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Homology;

use Bio::SimpleAlign;
use Bio::AlignIO;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none
    
=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'tree_scale'} = 30;
  $self->{'store_homologies'} = 1;
 
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  
  my $starttime = time();
  $self->{'protein_tree'} =  $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_tree_at_node_id($self->{'protein_tree_id'});
         
  if($self->debug) {
    $self->{'protein_tree'}->print_tree($self->{'tree_scale'});
    printf("time to fetch tree : %1.3f secs\n" , time()-$starttime);
  }

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }
  
  $self->load_species_tree();
  
  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs OrthoTree
    Returns :   none
    Args    :   none
    
=cut

sub run
{
  my $self = shift;
  $self->run_analysis;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse clustalw output and update family and family_member tables
    Returns :   none
    Args    :   none
    
=cut

sub write_output {
  my $self = shift;

  $self->store_homologies;
}
 
 
sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("OrthoTree::DESTROY  releasing protein_tree\n") if($self->debug);
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
  }
  if($self->{'taxon_tree'}) {
    printf("OrthoTree::DESTROY  releasing taxon_tree\n") if($self->debug);
    $self->{'taxon_tree'}->release_tree;
    $self->{'taxon_tree'} = undef;
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);
  
  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }
    
  if(defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree_id'} = $params->{'protein_tree_id'};
  }
  $self->{'cdna'} = $params->{'cdna'} if(defined($params->{'cdna'}));
  
  return;
}


sub print_params {
  my $self = shift;

  print("params:\n");
  printf("  tree_id   : %d\n", $self->{'protein_tree_id'});
}


sub run_analysis
{
  my $self = shift;

  my $starttime = time()*1000;
  my $tmp_time = time();
  my $tree = $self->{'protein_tree'};
    
  my @all_protein_leaves = @{$tree->get_all_leaves};
  
  #precalculate the ancestor species_hash (caches into the metadata of nodes)
  #also augments the Duplication tagging
  $self->get_ancestor_species_hash($tree);
  
  if($self->debug) {
    $self->{'protein_tree'}->print_tree($self->{'tree_scale'});
    printf("%d proteins in tree\n", scalar(@all_protein_leaves));
  }
  
  #compare every gene in the tree with every other
  #each gene/gene pairing is a potential ortholog/paralog
  #and thus we need to analyze every possibility
  #accomplish by creating a fully connected graph between all the genes
  #under the tree (hybrid graph structure) and then analyze each gene/gene link
  $tmp_time = time();
  printf("build fully linked graph\n") if($self->debug);
  my @genepairlinks;
  while (my $protein1 = shift @all_protein_leaves) {
    foreach my $protein2 (@all_protein_leaves) {
      my $ancestor = $protein1->find_first_shared_ancestor($protein2);
      my $taxon_level = $self->get_ancestor_taxon_level($ancestor);
      my $distance = $protein1->distance_to_ancestor($ancestor) +
                     $protein2->distance_to_ancestor($ancestor);
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($protein1, $protein2, $distance);
      $genepairlink->add_tag("hops", 0);
      $genepairlink->add_tag("ancestor", $ancestor);
      $genepairlink->add_tag("taxon_name", $taxon_level->name);
      push @genepairlinks, $genepairlink;
    }
  }
  printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);
  
  $self->{'protein_tree'}->print_tree($self->{'tree_scale'}) if($self->debug);

  #sort the gene/gene links by distance
  #   makes debug display easier to read, not required by algorithm
  $tmp_time = time();
  printf("sort links\n") if($self->debug);
  my @sorted_genepairlinks = sort {$a->distance_between <=> $b->distance_between} @genepairlinks;
  printf("%1.3f secs to sort links\n", time()-$tmp_time) if($self->debug > 1);

  #analyze every gene pair (genepairlink) to get its classification
  printf("analyze links\n") if($self->debug);
  $tmp_time = time();
  $self->{'old_homology_count'} = 0;
  $self->{'orthotree_homology_counts'} = {};
  foreach my $genepairlink (@sorted_genepairlinks) {
    $self->analyze_genepairlink($genepairlink);
  }
  printf("%1.3f secs to analyze genepair links\n", time()-$tmp_time) if($self->debug > 1);
  
  #display summary stats of analysis 
  my $runtime = time()*1000-$starttime;  
  $self->{'protein_tree'}->store_tag('OrthoTree_runtime_msec', $runtime);
  if($self->debug) {
    printf("%d proteins in tree\n", scalar(@{$tree->get_all_leaves}));
    printf("%d pairings\n", scalar(@genepairlinks));
    printf("%d old homologies\n", $self->{'old_homology_count'});
    printf("orthotree homologies\n");
    foreach my $type (keys(%{$self->{'orthotree_homology_counts'}})) {
      printf("  %13s : %d\n", $type, $self->{'orthotree_homology_counts'}->{$type});
    }
  }

  $self->{'homology_links'} = \@sorted_genepairlinks;
  return undef;
}


sub analyze_genepairlink
{
  my $self = shift;
  my $genepairlink = shift;

  my ($protein1, $protein2) = $genepairlink->get_nodes;

  #run feature detectors: precalcs and caches into metadata
  $self->genepairlink_check_dups($genepairlink);
  $self->genepairlink_fetch_homology($genepairlink) if($self->debug);

  #do classification analysis : as filter stack
  if($self->inspecies_paralog_test($genepairlink)) { }
  elsif($self->direct_ortholog_test($genepairlink)) { } 
  elsif($self->ancient_residual_test($genepairlink)) { } 
  elsif($self->one2many_ortholog_test($genepairlink)) { } 
  elsif($self->outspecies_test($genepairlink)) { }
  else {
    printf("OOPS!!!! %s - %s\n", $protein1->gene_member->stable_id, $protein2->gene_member->stable_id);
  }
  
  $self->{'old_homology_count'}++ if($genepairlink->get_tagvalue('old_homology'));

  my $type = $genepairlink->get_tagvalue('orthotree_type');
  if($type) {
    if(!defined($self->{'orthotree_homology_counts'}->{$type})) {
      $self->{'orthotree_homology_counts'}->{$type} = 1;
    } else {
      $self->{'orthotree_homology_counts'}->{$type}++;
    }
  }
  
  #display results
  $self->display_link_analysis($genepairlink) if($self->debug >1);

  return undef;
}


sub display_link_analysis
{
  my $self = shift;
  my $genepairlink = shift;
  
  #display raw feature analysis
  my ($protein1, $protein2) = $genepairlink->get_nodes;
  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  printf("%21s(%7d) - %21s(%7d) : %10.3f dist : %3d hops : ", 
    $protein1->gene_member->stable_id, $protein1->gene_member->member_id,
    $protein2->gene_member->stable_id, $protein2->gene_member->member_id,
    $genepairlink->distance_between, $genepairlink->get_tagvalue('hops'));
  
  if($genepairlink->get_tagvalue('has_dups')) { printf("%5s ", 'DUP');
  } else { printf("%5s ", ""); }

  my $homology = $genepairlink->get_tagvalue('old_homology');
  if($homology) { printf("%5s ", $homology->description);
  } else { printf("%5s ", ""); }
  
  print("ancestor:(");
  if($ancestor->get_tagvalue("Duplication") eq '1'){print("DUP ");} else{print"    ";}
  printf("%9s)", $ancestor->node_id);

  my $taxon_level = $ancestor->get_tagvalue('taxon_level');
  printf(" %s %s %s\n", 
         $genepairlink->get_tagvalue('orthotree_type'), 
         $genepairlink->get_tagvalue('orthotree_subtype'),
         $taxon_level->name
        );
         
  return undef;
}


sub load_species_tree
{
  my $self = shift;
  
  printf("load_species_tree\n") if($self->debug);
  my $starttime = time();
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;

  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  my $root=undef;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($gdb->taxon_id);
    $taxon->no_autoload_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }
  $root = $root->minimize_tree;  
  
  $self->{'taxon_tree'} = $root;
  if($self->debug) {
    $root->print_tree(10);
    printf("%1.3f secs for load species tree\n", time()-$starttime);
  }
  return undef;
}



sub get_ancestor_species_hash
{
  my $self = shift;
  my $node = shift;

  my $species_hash = $node->get_tagvalue('species_hash');
  return $species_hash if($species_hash);
  
  $species_hash = {};
  my $duplication_hash = {};
  my $is_dup=0;

  if($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    $species_hash->{$node->genome_db_id} = 1;
    $node->add_tag('species_hash', $species_hash);
    return $species_hash;
  }
 
  foreach my $child (@{$node->children}) {
    my $t_species_hash = $self->get_ancestor_species_hash($child);
    next unless(defined($t_species_hash)); #shouldn't happen
    foreach my $genome_db_id (keys(%$t_species_hash)) {
      unless(defined($species_hash->{$genome_db_id})) {
        $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id};
      } else {
        #this species already existed in one of the other children 
        #this means this species was duplciated at this point between the species
        $is_dup=1;
        $duplication_hash->{$genome_db_id} = 1;
        $species_hash->{$genome_db_id} += $t_species_hash->{$genome_db_id};
      }    
    }
  }
  
  #printf("\ncalc_ancestor_species_hash : %s\n", $self->encode_hash($species_hash));
  #$node->print_tree(20);
  
  $node->add_tag("species_hash", $species_hash);
  if($is_dup) {
    my $original_duplication_value = $node->get_tagvalue('Duplication');
    $original_duplication_value = 0 unless (defined $original_duplication_value);

    if ($original_duplication_value == 0) {
      # RAP did not predict a duplication here
      $node->add_tag("duplication_hash", $duplication_hash);
      $node->store_tag("Duplication", 1);
      $node->store_tag("Duplication_alg", 'species_count');

    } elsif ($original_duplication_value == 1) {
      my $dup_alg = $node->get_tagvalue("Duplication_alg");
      if (defined $dup_alg and $dup_alg ne 'species_count') {
        # RAP did predict a duplication here but not species_count
        $node->add_tag("duplication_hash", $duplication_hash);
        $node->store_tag("Duplication", 2);
        $node->store_tag("Duplication_alg", 'species_count');
      }

    }
  }
  return $species_hash;
}


sub get_ancestor_taxon_level
{
  my $self = shift;
  my $ancestor = shift;
  
  my $taxon_level = $ancestor->get_tagvalue('taxon_level');
  return $taxon_level if($taxon_level);

  #printf("\ncalculate ancestor taxon level\n");
  my $taxon_tree = $self->{'taxon_tree'};
  my $species_hash = $self->get_ancestor_species_hash($ancestor);    
  
  foreach my $gdbID (keys(%$species_hash)) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdbID);
    my $taxon = $taxon_tree->find_node_by_node_id($gdb->taxon_id);
    throw("oops missing taxon " . $gdb->taxon_id ."\n") unless($taxon);

    if($taxon_level) { 
      $taxon_level = $taxon_level->find_first_shared_ancestor($taxon);
    } else {
      $taxon_level = $taxon; 
    }
  }
  $ancestor->add_tag("taxon_level", $taxon_level);
  $ancestor->store_tag("taxon_id", $taxon_level->taxon_id);
  $ancestor->store_tag("name", $taxon_level->name);

  #$ancestor->print_tree($self->{'tree_scale'});
  #$taxon_level->print_tree(10);
       
  return $taxon_level;
}


sub genepairlink_fetch_homology
{
  my $self = shift;
  my $genepairlink = shift;
  
  my ($member1, $member2) = $genepairlink->get_nodes;
  
  my $sql = "select homology.homology_id from homology ".
            "join homology_member hm1 using(homology_id) ".
            "join homology_member hm2 using (homology_id ) " . 
            "where hm1.peptide_member_id=? and hm2.peptide_member_id=?";

  my $sth = $self->dbc->prepare($sql);
  $sth->execute($member1->member_id, $member2->member_id);
  my $ref = $sth->fetchrow_arrayref();
  return undef unless($ref);
  $sth->finish;
  my ($homology_id) = @$ref;
  return undef unless($homology_id);
  
  my $homology = $self->{'comparaDBA'}->get_HomologyAdaptor->fetch_by_dbID($homology_id);
  $genepairlink->add_tag("old_homology", $homology);

  return $homology;
}


sub genepairlink_check_dups
{
  my $self = shift;
  my $genepairlink = shift;
  
  my ($pep1, $pep2) = $genepairlink->get_nodes;
  
  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  #printf("ancestor : "); $ancestor->print_node;
  my $has_dup=0;
  my %nodes_between;
  my $tnode = $pep1;
  #printf("pep: "); $pep1->print_node;
  do {
    $tnode = $tnode->parent;
    #$tnode->print_node;
    $has_dup=1 if($tnode->get_tagvalue("Duplication") > 0);
    $nodes_between{$tnode->node_id} = $tnode;
  } while(!($tnode->equals($ancestor)));

  #printf("pep: "); $pep2->print_node;
  $tnode = $pep2;
  do {
    $tnode = $tnode->parent;
    #$tnode->print_node;
    $has_dup=1 if($tnode->get_tagvalue("Duplication") > 0);
    $nodes_between{$tnode->node_id} = $tnode;
  } while(!($tnode->equals($ancestor)));

  $genepairlink->add_tag("hops", scalar(keys(%nodes_between)));
  $genepairlink->add_tag("has_dups", $has_dup);
  return undef;
}


########################################################
#
# Classification analysis
#
########################################################


sub direct_ortholog_test
{
  my $self = shift;
  my $genepairlink = shift;
    
  #strictest ortholog test: 
  #  - genes are from different species
  #  - no ancestral duplication events
  #  - these genes are only copies of the ancestor for their species

  return undef if($genepairlink->get_tagvalue('has_dups'));
  
  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);
  
  #RAP seems to miss some duplication events so check the species 
  #counts for these two species to make sure they are the only
  #representatives of these species under the ancestor
  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};
  
  return undef if($count1>1);
  return undef if($count2>1);
  
  #passed all the tests -> it's a simple ortholog
  $genepairlink->add_tag("orthotree_type", 'ortholog_one2one');
  return 1;
}


sub inspecies_paralog_test
{
  my $self = shift;
  my $genepairlink = shift;
    
  #simplest paralog test: 
  #  - both genes are from the same species
  #  - and just label with taxonomic level

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef unless($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);

  #my $species_hash = $self->get_ancestor_species_hash($ancestor);
  #foreach my $gdbID (keys(%$species_hash)) {
  #  return undef unless($gdbID == $pep1->genome_db_id);
  #}
  
  #passed all the tests -> it's an inspecies_paralog
  $genepairlink->add_tag("orthotree_type", 'inspecies_paralog');
  $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  return 1;
}


sub ancient_residual_test
{
  my $self = shift;
  my $genepairlink = shift;
    
  #test 3: getting a bit more complex:
  #  - genes are from different species
  #  - there is evidence for duplication events elsewhere in the history
  #  - but these two genes are the only remaining representative of the ancestor

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);
  
  #check these are the only representatives of the ancestor
  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};
  
  return undef if($count1>1);
  return undef if($count2>1);

  #passed all the tests -> it's a simple ortholog
  if($ancestor->get_tagvalue("Duplication") > 0) {
    $genepairlink->add_tag("orthotree_type", 'outspecies_paralog_one2one_geneloss');
  } else {
    $genepairlink->add_tag("orthotree_type", 'ortholog_one2one_geneloss');
  }
  return 1;
}


sub one2many_ortholog_test
{
  my $self = shift;
  my $genepairlink = shift;
    
  #test 4: getting a bit more complex yet again:
  #  - genes are from different species
  #  - but there is evidence for duplication events in the history
  #  - one of the genes is the only remaining representative of the ancestor in its species
  #  - but the other gene has multiple copies in it's species 
  #  (first level of orthogroup analysis)

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);
  
  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};
  
  #one of the genes must be the only copy of the gene
  #and the other must appear more than once in the ancestry
  return undef unless(($count1==1 and $count2>1) or ($count1>1 and $count2==1));
  
  #passed all the tests -> it's a one2many ortholog
  $genepairlink->add_tag("orthotree_type", 'ortholog_one2many');
  return 1;
}


sub outspecies_test
{
  my $self = shift;
  my $genepairlink = shift;
    
  #last test: left over pairs:  
  #  - genes are from different species
  #  - if ancestor is 'DUP' -> paralog else 'ortholog'

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);
  
  #ultra simple ortho/paralog classification
  if($ancestor->get_tagvalue("Duplication") > 0) {
    $genepairlink->add_tag("orthotree_type", 'outspecies_paralog');
  } else {
    $genepairlink->add_tag("orthotree_type", 'ortholog_many2many');
  }
  return 1;
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub store_homologies
{
  my $self = shift;

  foreach my $genepairlink (@{$self->{'homology_links'}}) {
    $self->display_link_analysis($genepairlink) if($self->debug>2);
    $self->store_gene_link_as_homology($genepairlink);
  }

  my $counts_str = $self->encode_hash($self->{'orthotree_homology_counts'});
  printf("$counts_str\n");

  $self->{'protein_tree'}->store_tag(
      'OrthoTree_types_hashstr', 
      $self->encode_hash($self->{'orthotree_homology_counts'}));

  return undef;
}


sub store_gene_link_as_homology
{
  my $self = shift;
  my $genepairlink  = shift;

  my $type = $genepairlink->get_tagvalue('orthotree_type');
  return unless($type);
  my $subtype = $genepairlink->get_tagvalue('taxon_name');
  
  my ($protein1, $protein2) = $genepairlink->get_nodes;

  #
  # create method_link_species_set
  #
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type("TREE_HOMOLOGIES");
  if ($protein1->genome_db->dbID == $protein2->genome_db->dbID) {
    $mlss->species_set([$protein1->genome_db]);
  } else {
    $mlss->species_set([$protein1->genome_db, $protein2->genome_db]);
  }
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  $homology->description($type);
  $homology->subtype($subtype);
  $homology->method_link_type("TREE_HOMOLOGIES");
  $homology->method_link_species_set($mlss);
  #$homology->dbID(-1);

  # NEED TO BUILD THE Attributes (ie homology_members)
  #
  # QUERY member
  #
  my $attribute;
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($protein1->dbID);
  #$attribute->cigar_start($self->qstart);
  #$attribute->cigar_end($self->qend);
  #my $qlen = ($self->qend - $self->qstart + 1);
  #$attribute->perc_cov(int($qlen*100/$protein1->seq_length));
  #$attribute->perc_id(int($self->identical_matches*100.0/$qlen));
  #$attribute->perc_pos(int($self->positive_matches*100/$qlen));
  #$attribute->peptide_align_feature_id($self->dbID);

  #my $cigar_line = $self->cigar_line;
  #print("original cigar_line '$cigar_line'\n");
  #$cigar_line =~ s/I/M/g;
  #$cigar_line = compact_cigar_line($cigar_line);
  #$attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");

  #print("add query member gene : ", $protein1->gene_member->stable_id, "\n");
  $homology->add_Member_Attribute([$protein1->gene_member, $attribute]);

  #
  # HIT member
  #
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($protein2->dbID);
  #$attribute->cigar_start($self->hstart);
  #$attribute->cigar_end($self->hend);
  #my $hlen = ($self->hend - $self->hstart + 1);
  #$attribute->perc_cov(int($hlen*100/$protein2->seq_length));
  #$attribute->perc_id(int($self->identical_matches*100.0/$hlen));
  #$attribute->perc_pos(int($self->positive_matches*100/$hlen));
  #$attribute->peptide_align_feature_id($self->rhit_dbID);

  #$cigar_line = $self->cigar_line;
  #print("original cigar_line\n    '$cigar_line'\n");
  #$cigar_line =~ s/D/M/g;
  #$cigar_line =~ s/I/D/g;
  #$cigar_line = compact_cigar_line($cigar_line);
  #$attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");
  
  #print("add hit member gene : ", $protein2->gene_member->stable_id, "\n");
  $homology->add_Member_Attribute([$protein2->gene_member, $attribute]);
  
  
  $self->{'comparaDBA'}->get_HomologyAdaptor()->store($homology) if($self->{'store_homologies'});
  
  my $stable_id;  
  if($protein1->taxon_id < $protein2->taxon_id) {
    $stable_id = $protein1->taxon_id() . "_" . $protein2->taxon_id . "_";
  } else {
    $stable_id = $protein2->taxon_id . "_" . $protein1->taxon_id . "_";
  }
  $stable_id .= sprintf ("%011.0d",$homology->dbID) if($homology->dbID);
  $homology->stable_id($stable_id);
  #TODO: update the stable_id of the homology
  
  if($self->debug) { 
    print("store: ");
    $homology->print_homology;
  }

  return undef;  
}


1;
