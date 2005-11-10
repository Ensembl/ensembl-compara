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
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::OrthoTree->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

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
use Bio::EnsEMBL::Compara::Graph::NewickParser;

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

  $self->{'tree_scale'} = 20;

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
         
  $self->{'protein_tree'}->print_tree($self->{'tree_scale'});
  printf("time to fetch tree : %1.3f secs\n" , time()-$starttime);  

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }

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

  #$self->store_proteintree;
}
 
 
sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("OrthoTree::DESTROY  releasing tree\n") if($self->debug);
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
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
  my $tree = $self->{'protein_tree'};
    
  my @all_protein_leaves = @{$tree->get_all_leaves};
  printf("%d proteins in tree\n", scalar(@all_protein_leaves));
  
  $self->calc_ancestor_species_hash($tree);
  
  #compare every gene in the tree with every other
  #each gene/gene pairing is a potential orthologue/paralogue
  #and thus we need to analyze every possibility
  #accomplish by creating a fully connected graph between all the genes
  #under the tree (hybrid graph structure) and then analyze each gene/gene link
  my @pair_links;
  while (my $protein1 = shift @all_protein_leaves) {
    foreach my $protein2 (@all_protein_leaves) {
      my $ancestor = $protein1->find_first_shared_ancestor($protein2);
      my $distance = $protein1->distance_to_ancestor($ancestor) +
                     $protein2->distance_to_ancestor($ancestor);
      my $link = new Bio::EnsEMBL::Compara::Graph::Link($protein1, $protein2, $distance);
      $link->add_tag("hops", 0);
      $link->add_tag("ancestor", $ancestor);
      push @pair_links, $link;
    }
  }
  
  #sort the gene/gene links by distance and then analyze
  my @links = sort {$a->distance_between <=> $b->distance_between} @pair_links;
  foreach my $link (@links) {
    $self->analyze_genelink($link);
  }

  my $runtime = time()*1000-$starttime;  
  $self->{'protein_tree'}->store_tag('OrthoTree_runtime_msec', $runtime);
  printf("%d proteins in tree\n", scalar(@{$tree->get_all_leaves}));
  printf("%d pairings\n", scalar(@pair_links));
    
  $tree->disavow_parent;
  $tree->cascade_unlink;
  $self->{'protein_tree'} = undef;
  return undef;
}


sub analyze_genelink
{
  my $self = shift;
  my $link = shift;

  $self->genelink_check_dups($link);
  $self->genelink_fetch_homology($link);

  #display analysis
  my ($protein1, $protein2) = $link->get_nodes;
  my $ancestor = $link->get_tagvalue('ancestor');
  printf("%21s(%7d) - %21s(%7d) : %10.3f dist : %3d hops : ", 
    $protein1->stable_id, $protein1->member_id,
    $protein2->stable_id, $protein2->member_id,
    $link->distance_between, $link->get_tagvalue('hops'));
  
  if($link->get_tagvalue('has_dups')) { printf("%5s ", 'DUP');
  } else { printf("%5s ", ""); }

  my $homology = $link->get_tagvalue('old_homology');
  if($homology) { printf("%5s ", $homology->description);
  } else { printf("%5s ", ""); }

  print("ancestor: "); $ancestor->print_node;
    
  return undef;
}

#############################################
#
# individual feature detectors
#
#############################################

sub calc_ancestor_species_hash
{
  my $self = shift;
  my $node = shift;

  my $species_hash = $node->get_tagvalue('species_hash');
  return $species_hash if($species_hash);
  
  $species_hash = {};

  if($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    $species_hash->{$node->genome_db_id} = 1;
    $node->add_tag('species_hash', $species_hash);
    return $species_hash;
  }
 
  foreach my $child (@{$node->children}) {
    my $t_species_hash = $self->calc_ancestor_species_hash($child);
    next unless(defined($t_species_hash)); #shouldn't happen
    foreach my $genome_db_id (keys(%$t_species_hash)) {
      unless(defined($species_hash->{$genome_db_id})) {
        $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id};
      } else {
        $species_hash->{$genome_db_id} += $t_species_hash->{$genome_db_id};
      }    
    }
  }
  
  #printf("\ncalc_ancestor_species_hash : %s\n", $self->encode_hash($species_hash));
  #$node->print_tree(20);
  
  $node->add_tag("species_hash", $species_hash);
  return $species_hash;
}


sub genelink_fetch_homology
{
  my $self = shift;
  my $link = shift;
  
  my ($member1, $member2) = $link->get_nodes;
  
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
  $link->add_tag("old_homology", $homology);

  return $homology;
}


sub genelink_check_dups
{
  my $self = shift;
  my $link = shift;
  
  my ($pep1, $pep2) = $link->get_nodes;
  
  my $ancestor = $link->get_tagvalue('ancestor');
  #printf("ancestor : "); $ancestor->print_node;
  my $has_dup=0;
  my %nodes_between;
  my $tnode = $pep1;
  #printf("pep: "); $pep1->print_node;
  do {
    $tnode = $tnode->parent;
    #$tnode->print_node;
    $has_dup=1 if($tnode->get_tagvalue("Duplication") eq '1');
    $nodes_between{$tnode->node_id} = $tnode;
  } while(!($tnode->equals($ancestor)));

  #printf("pep: "); $pep2->print_node;
  $tnode = $pep2;
  do {
    $tnode = $tnode->parent;
    #$tnode->print_node;
    $has_dup=1 if($tnode->get_tagvalue("Duplication") eq '1');
    $nodes_between{$tnode->node_id} = $tnode;
  } while(!($tnode->equals($ancestor)));

  $link->add_tag("hops", scalar(keys(%nodes_between)));
  $link->add_tag("has_dups", $has_dup);
  return undef;
}


sub simple_orthologue_test
{
  my $self = shift;
  my $link = shift;
  
  my ($pep1, $pep2) = $link->get_nodes;
  
  #simplest orthologue test: no duplication events in the
  #ancestory between these two genes
  
  return undef;
}

########################################################
#
# ProteinTree input/output section
#
########################################################

sub store_proteintree
{
  my $self = shift;

  return unless($self->{'protein_tree'});

  printf("OrthoTree::store_proteintree\n") if($self->debug);
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  
  $treeDBA->sync_tree_leftright_index($self->{'protein_tree'});
  $treeDBA->store($self->{'protein_tree'});
  $treeDBA->delete_nodes_not_in_tree($self->{'protein_tree'});
  
  if($self->debug >1) {
    print("done storing - now print\n");
    $self->{'protein_tree'}->print_tree;
  }
  
  if($self->{'cdna'}) {
    $self->{'protein_tree'}->store_tag('OrthoTree_alignment', 'cdna');
  } else {
    $self->{'protein_tree'}->store_tag('OrthoTree_alignment', 'aa');
  }
  $self->{'protein_tree'}->store_tag('tree_method', 'OrthoTree');
  return undef;
}


1;
