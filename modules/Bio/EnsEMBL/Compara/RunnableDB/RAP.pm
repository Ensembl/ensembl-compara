#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RAP

=cut

=head1 SYNOPSIS

my $db  = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $rap = Bio::EnsEMBL::Compara::RunnableDB::RAP->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$rap->fetch_input(); #reads from DB
$rap->run();
$rap->output();
$rap->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a tree built on it. It dumps that tree for import
into the RAP program which will do species tree to gene tree reconciliation.

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

package Bio::EnsEMBL::Compara::RunnableDB::RAP;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);
use Switch;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Graph::Algorithms;

use Bio::SimpleAlign;
use Bio::AlignIO;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

#######################################
#
# subclass methods 
#
#######################################

sub fetch_input {
  my( $self) = @_;

  $self->{'tree_scale'} = 20;
  
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }

  return 1;
}


sub run
{
  my $self = shift;
  $self->run_rap;
}


sub write_output {
  my $self = shift;
  $self->store_proteintree;
}
 
 
sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("RAP::DESTROY  releasing tree\n") if($self->debug);
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
    $self->{'protein_tree'} =  
         $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_node_by_node_id($params->{'protein_tree_id'});
  }
  if(defined($params->{'species_tree_file'})) {
    $self->{'species_tree_file'} = $params->{'species_tree_file'};
  }
  
  return;
}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id           : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
  print("  species_tree_file : ", $self->{'species_tree_file'},"\n") if($self->{'species_tree_file'});
}


sub check_job_fail_options
{
  my $self = shift;
  
  printf("RAP failed : ");
  $self->input_job->print_job;
  
  $self->dataflow_output_id($self->input_id, 2);
  $self->input_job->update_status('FAILED');
  
  if($self->{'protein_tree'}) {
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
  }
}


#####################################
#
# main code
#
#####################################

sub run_rap
{
  my $self = shift;

  my $starttime = time()*1000;
  
  #input tree is un-rooted
  #it appears as though RAP is looking for a rooted tree as input
  #so pre-root the tree with my 'tree balancing' algorithm
  $self->pre_root_tree($self->{'protein_tree'});
  

  $self->{'rap_infile'} = $self->dumpTreeToWorkdir($self->{'protein_tree'});
  return unless($self->{'rap_infile'});
  
  $self->{'newick_file'} = $self->{'rap_infile'} . "_rap_tree.txt ";

  my $rap_executable = $self->analysis->program_file;
  #unless (-e $rap_executable) {
  #  $rap_executable = "/usr/local/ensembl/bin/rap.jar";
  #}
  #throw("can't find a RAP executable to run\n") unless(-e $rap_executable);

  my $cmd = "java -jar /usr/local/ensembl/bin/rap.jar";
  if ($rap_executable) {
    $cmd = $rap_executable;
  }
  $cmd .= " 80";    #Max bootstrap for reduction
  $cmd .= " 50.0";  #Max relative rate ratio before duplication
  $cmd .= " 30";    #Gene Tree Max depth for best root research 
  $cmd .= " 0.15";  #Maximum length for polymorphism
  $cmd .= " 0.03";  #Maximum length for reduction - Species Tree (was 10.0)
  $cmd .= " 0.15";  #Maximum length for reduction - Gene tree  
  $cmd .= " ". $self->{'species_tree_file'};  
  $cmd .= " ". $self->{'rap_infile'};  
  $cmd .= " ". $self->{'rap_outfile'};  
  $cmd .= " 2>&1 > /dev/null" unless($self->debug);
  
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    print("$cmd\n");
    throw("error running rap, $!\n");
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  
  #parse the tree into the datastucture
  $self->parse_RAP_output;
  
  my $runtime = time()*1000-$starttime;
  
  $self->{'protein_tree'}->store_tag('RAP_runtime_msec', $runtime);
  
}


###############################
#
# creation of input gene tree
#
###############################

sub pre_root_tree
{
  my $self = shift;
  my $tree = shift;
  
  $tree->print_tree($self->{'tree_scale'}) if($self->debug);

  #the node '$tree' is used as a reference to the cluster so it can't be lost
  #move tree off of the '$tree' node and replace it with a temp $node
  #this also disconnects into stand-alone graphs to allow it to be manipulated
  my $node = new Bio::EnsEMBL::Compara::NestedSet;
  $node->merge_children($tree); #moves childen from $tree onto $node
  #$node->node_id($tree->node_id); #give old node_id for debugging
  #$tree now has no children
  
  #get a link and search the tree for the balancing link (link length sum)
  my ($link) = @{$node->links};  
  $link = Bio::EnsEMBL::Compara::Graph::Algorithms::find_balanced_link($link, $self->debug);
  if($self->debug) { print("balanced link is\n    "); $link->print_link; }
  
  #create new root node at the midpoint on this 'balanced' link
  my $root = Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);

  #remove temp root if it has become a redundant internal node (only 1 child)
  $node->minimize_node;
  
  #move newly rooted tree back to original '$tree' node  
  $tree->merge_children($root);
  $tree->print_tree($self->{'tree_scale'}) if($self->debug);
  return $tree;
}


sub dumpTreeToWorkdir
{
  my $self = shift;
  my $tree = shift;
  
  my @leaves = @{$tree->get_all_leaves};
  my $leafcount = scalar(@leaves);  
  if($leafcount<3) {
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", $tree->node_id);
    return undef;
  }
  printf("dumpTreeToWorkdir : %d members\n", $leafcount) if($self->debug);
  
  my $treeName = "proteintree_". $tree->node_id;
  $self->{'file_root'} = $self->worker_temp_directory. $treeName;
  #$self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $rap_infile =  $self->{'file_root'} . ".rap_in";
  $self->{'rap_infile'} = $rap_infile;
  $self->{'rap_outfile'} = $self->{'file_root'} . ".rap_out";
  
  return $rap_infile if(-e $rap_infile);

  print("rap_infile = '$rap_infile'\n") if($self->debug);

  open(OUTFILE, ">$rap_infile")
    or $self->throw("Error opening $rap_infile for write");

  printf(OUTFILE "$treeName\n[\n");
  
  foreach my $member (@leaves) {
    printf(OUTFILE "%s\"%s\"\n", $member->member_id, $member->genome_db->name);
  }
  print OUTFILE "]\n";
  
  print OUTFILE $self->rap_newick_format($tree);
  print OUTFILE ";\n";
  
  close OUTFILE;
  
  return $rap_infile;
}


sub rap_newick_format {
  my $self = shift;
  my $tree_node = shift;
  my $newick = "";
  
  if($tree_node->get_child_count() > 0) {
    $newick .= "(";
    my $first_child=1;
    foreach my $child (@{$tree_node->sorted_children}) {  
      $newick .= "," unless($first_child);
      $newick .= $self->rap_newick_format($child);
      $first_child = 0;
    }
    $newick .= ")";
  }
  
  if(!($tree_node->equals($self->{'protein_tree'}))) {
    if($tree_node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
      $newick .= sprintf("%s", $tree_node->member_id,);
    }
    $newick .= sprintf(":%1.4f", $tree_node->distance_to_parent);
  }

  return $newick;
}


##########################
#
# parsing
#
##########################


sub parse_RAP_output
{
  my $self = shift;
  my $rap_outfile =  $self->{'rap_outfile'};
  my $tree = $self->{'protein_tree'};
  
  #cleanup old tree structure- 
  #  flatten and reduce to only AlignedMember leaves
  #  unset duplication tags
  $tree->flatten_tree;
  $tree->print_tree($self->{'tree_scale'}) if($self->debug>2);
  foreach my $node (@{$tree->get_all_leaves}) {
    $node->add_tag("Duplication", 0);
    unless($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
      $node->disavow_parent;
    }
  }
  $tree->add_tag("Duplication", 0);

  #parse newick into a new tree object structure
  print("load from file $rap_outfile\n") if($self->debug);
  open (FH, $rap_outfile) or throw("Could not open newick file [$rap_outfile]");
  my $chew_rap = 1;
  while($chew_rap>0) { 
    my $line = <FH>;
    chomp($line);
    printf("rap line %d : %s\n", $chew_rap, $line) if($self->debug>2);
    if($line =~ "^]") { $chew_rap=0;}
    else { $chew_rap++; };
  }
  my $newick = <FH>;
  chomp($newick);
  close(FH);
  printf("rap_newick_like_string: '%s'\n", $newick) if($self->debug>1);
    
  my $newtree = $self->parse_rap_newick_into_tree($newick);
  $newtree->print_tree($self->{'tree_scale'}) if($self->debug > 1);
  
  #leaves of newick tree are named with member_id of members from input tree
  #move members (leaves) of input tree into newick tree to mirror the 'member_id' nodes
  foreach my $member (@{$tree->get_all_leaves}) {
    my $tmpnode = $newtree->find_node_by_name($member->member_id);
    if($tmpnode) {
      $tmpnode->add_child($member, 0.0);
      $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
    } else {
      print("unable to find node in newick for member"); 
      $member->print_member;
    }
  }
  
  # merge the trees so that the children of the newick tree are now attached to the 
  # input tree's root node
  $tree->merge_children($newtree);
  $tree->add_tag("Duplication", $newtree->get_tagvalue('Duplication'));

  #newick tree is now empty so release it
  $newtree->release_tree;

  $tree->print_tree($self->{'tree_scale'}) if($self->debug);
  return undef;
}



sub parse_rap_newick_into_tree
{
  my $self = shift;
  my $newick = shift;

  my $count=1;
  my $debug = 1 if($self->debug > 2);
  print("$newick\n") if($debug);
  my $token = next_token(\$newick, "(;");
  my $lastset = undef;
  my $node = undef;
  my $root = undef;
  my $state=1;
  my $bracket_level = 0;

  while($token) {
    if($debug) { printf("state %d : '%s'\n", $state, $token); };
    
    switch ($state) {
      
      case 1 { #new node
        $node = new Bio::EnsEMBL::Compara::NestedSet;
        $node->node_id($count++);
        $lastset->add_child($node) if($lastset);
        $root=$node unless($root);
        if($token eq '#') {
          if($debug) { printf("   Duplication node\n"); };
          $node->add_tag("Duplication", 1);
          $token = next_token(\$newick, "(");  
          if($debug) { printf("state %d : '%s'\n", $state, $token); };
          if($token ne "(") { throw("parse error: expected ( after #\n"); }
        }
        $node->print_node if($debug);

        if($token eq '(') { #create new set
          printf("    create set\n")  if($debug);
          $token = next_token(\$newick, "\"/(:,)");
          $state = 1;
          $bracket_level++;
          $lastset = $node;
        } else {
          $state = 2;
        }
      }
      case 2 { #naming a node
        if($token eq '/') {
          printf("eat the /\n") if($debug);
          $token = next_token(\$newick, "\"/(:,)"); #eat it
        }
        elsif($token eq '"') { #quoted name
          $token = next_token(\$newick, '"');
          printf("got quoted name : %s\n", $token) if($debug);
          $node->name($token);
          $node->add_tag($token, "");
          if($debug) { print("    naming leaf"); $node->print_node; }
          $token = next_token(\$newick, "\""); #eat end "
          unless($token eq '"') {
            throw("parse error: expected matching \"");
          }
          $token = next_token(\$newick, "/(:,)"); #eat it
        }
        elsif(!($token =~ /[:,);]/)) { #unquoted name
          $node->name($token);
          if($debug) { print("    naming leaf"); $node->print_node; }
          $token = next_token(\$newick, "/:,);");
        }
        else { $state = 3; }
      }
      case 3 { # optional : and distance
        if($token eq ':') {
          $token = next_token(\$newick, ",);");
          $node->distance_to_parent($token);
          if($debug) { print("set distance: $token\n   "); $node->print_node; }
          $token = next_token(\$newick, ",);"); #move to , or )
        }
        $state = 4;
      }
      case 4 { # end node
        if($token eq ')') {
          if($debug) { print("end set : "); $lastset->print_node; }
          $node = $lastset;        
          $lastset = $lastset->parent;
          $token = next_token(\$newick, "\"/:,);");
          $state=2;
          $bracket_level--;
        } elsif($token eq ',') {
          $token = next_token(\$newick, "\"/(:,)");
          $state=1;
        } elsif($token eq ';') {
          #done with tree
          throw("parse error: unbalanced ()\n") if($bracket_level ne 0);
          $state=13;
          $token = next_token(\$newick, "(");
        } else {
          throw("parse error: expected ; or ) or ,\n");
        }
      }
      
      case 13 {
        throw("parse error: nothing expected after ;");
      }
    }
  }
  return $root;
}


sub next_token {
  my $string = shift;
  my $delim = shift;
  
  $$string =~ s/^(\s)+//;

  return undef unless(length($$string));
  
  #print("input =>$$string\n");
  #print("delim =>$delim\n");
  my $index=undef;

  my @delims = split(/ */, $delim);
  foreach my $dl (@delims) {
    my $pos = index($$string, $dl);
    if($pos>=0) {
      $index = $pos unless(defined($index));
      $index = $pos if($pos<$index);
    }
  }
  unless(defined($index)) {
    throw("couldn't find delimiter $delim\n");
  }

  my $token ='';

  if($index==0) {
    $token = substr($$string,0,1);
    $$string = substr($$string, 1);
  } else {
    $token = substr($$string, 0, $index);
    $$string = substr($$string, $index);
  }

  #print("  token     =>$token\n");
  #print("  outstring =>$$string\n\n");
  
  return $token;
}


###############################
#
# storing
#
###############################

sub store_proteintree
{
  my $self = shift;

  return unless($self->{'protein_tree'});

  printf("RAP::store_proteintree\n") if($self->debug);
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  
  $treeDBA->sync_tree_leftright_index($self->{'protein_tree'});
  $treeDBA->store($self->{'protein_tree'});
  $treeDBA->delete_nodes_not_in_tree($self->{'protein_tree'});
  
  if($self->debug >1) {
    print("done storing - now print\n");
    $self->{'protein_tree'}->print_tree($self->{'tree_scale'});
  }
  
  $self->{'protein_tree'}->store_tag('reconciliation_method', 'RAP');
  
  $self->store_duplication_tags($self->{'protein_tree'});

  return undef;
}

sub store_duplication_tags
{
  my $self = shift;
  my $node = shift;

  if($node->get_tagvalue("Duplication") eq '1') {
    if($self->debug) { printf("store duplication : "); $node->print_node; }
    $node->store_tag('Duplication', 1);
  } else {
    $node->store_tag('Duplication', 0);
  }
    
  foreach my $child (@{$node->children}) {
    $self->store_duplication_tags($child);
  }
  return undef;
}

1;
