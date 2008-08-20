#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ClustalW

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::ClustalW->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a Family or ProteinTree as input
Run a CLUSTALW multiple alignment on it, and store the resulting alignment
back into the family_member table.

input_id/parameters format eg: "{'family_id'=>1234}"
    family_id       : use family_id to run multiple alignment on its members
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

package Bio::EnsEMBL::Compara::RunnableDB::ClustalW;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

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

  $self->{'calc_alignment'} = 1;
  $self->{'calc_tree'} = 0;
  $self->{'parse_output'} = 1;
  $self->{'mpi'} = undef;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  
  if($self->{'mpi'}) {
    $self->{'calc_alignment'} = 1;
    $self->{'calc_tree'} = 0;
    $self->{'parse_output'} = 0;
  } 

  #load the family or protein_tree object from the database
  if(defined($self->{'family_id'})) {
    $self->{'family'} =  $self->{'comparaDBA'}->get_FamilyAdaptor->fetch_by_dbID($self->{'family_id'});
  }
  if(defined($self->{'protein_tree_id'})) {
    $self->{'protein_tree'} =  
         $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_node_by_node_id($self->{'protein_tree_id'});
  }
  
  unless($self->{'family'} or $self->{'protein_tree'}) {
    throw("no defined family to gene_tree to process");
  }


  #write out fasta or multiple alignment input files
  if($self->{'calc_alignment'}) {
    if($self->{'family'}) {
      $self->{'input_fasta'} = $self->dumpFamilyPeptidesToWorkdir($self->{'family'});
    } elsif($self->{'protein_tree'}) {
      $self->dumpTreePeptidesToWorkdir($self->{'protein_tree'});
    }
  }
  
  if($self->{'calc_tree'} and $self->{'protein_tree'}) {
    $self->dumpTreeMultipleAlignmentToWorkdir($self->{'protein_tree'});
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs ClustalW
    Returns :   none
    Args    :   none
    
=cut

sub run
{
  my $self = shift;

  if($self->{'calc_tree'} or $self->{'calc_alignment'}) {
    $self->run_clustalw;
  }
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

  if($self->{'parse_output'}) {
    if($self->{'family'}) { $self->parse_and_store_family; }
    if($self->{'protein_tree'}) { $self->parse_and_store_proteintree; }
  }
  
  $self->{'protein_tree'}->release_tree if($self->{'protein_tree'});
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

  $self->{'family_id'} = $params->{'family_id'} if(defined($params->{'family_id'}));
  $self->{'protein_tree_id'} = $params->{'protein_tree_id'} if(defined($params->{'protein_tree_id'}));

  if(defined($params->{'outfile_prefix'})) {
    $self->{'file_root'} = $params->{'outfile_prefix'};
    $self->{'newick_file'} = $self->{'file_root'} . ".dnd";
  }

  $self->{'calc_alignment'} = $params->{'align'} if(defined($params->{'align'}));
  $self->{'calc_tree'} = $params->{'tree'} if(defined($params->{'tree'}));
  $self->{'mpi'} = $params->{'mpi'} if(defined($params->{'mpi'}));
  $self->{'parse_output'} = $params->{'parse'} if(defined($params->{'parse'}));

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   family_id     : ", $self->{'family'}->dbID,"\n") if($self->{'family'});
}


sub run_clustalw
{
  my $self = shift;

  my $clustalw_executable = $self->analysis->program_file;
  throw("can't find a clustalw executable to run\n") 
     unless($clustalw_executable and (-e $clustalw_executable));

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  my $clustalw_output =  $self->{'file_root'} . ".aln";
  my $clustalw_log =  $self->{'file_root'} . ".log";
  
  if($self->{'calc_alignment'}) {
    if($self->{'mpi'} and not(-e $clustalw_output)) {
      #create parsing job
      my $outputHash = eval($self->input_id);
      $outputHash->{'outfile_prefix'} = $self->{'file_root'};
      my $output_id = $self->encode_hash($outputHash);  
      my ($job_url) = @{$self->dataflow_output_id($output_id, 1, 'BLOCKED')};
      printf("created parse jobs: $job_url\n");

      my $align_cmd = "bsub -o $clustalw_log -n32 -R\"type=LINUX86 span[ptile=2]\" -P ensembl-compara ";
      $align_cmd .= $clustalw_executable . " " . $self->{'input_fasta'} . " ". $job_url;
      print("$align_cmd\n") if($self->debug);
      unless(system($align_cmd) == 0) {
        throw("error running clustalw, $!\n");
      }
    } else {
      my $align_cmd = $clustalw_executable;
      $align_cmd .= " -align -infile=" . $self->{'input_fasta'} . " -outfile=" . $clustalw_output;
      print("$align_cmd\n") if($self->debug);
      $align_cmd .= " 2>&1 > /dev/null" unless($self->debug);
      unless(system($align_cmd) == 0) {
        throw("error running clustalw, $!\n");
      }
    }
  }

  if($self->{'calc_tree'}) {
    my $tree_cmd = $clustalw_executable;
    $tree_cmd .= " -tree -infile=" . $self->{'file_root'} . ".aln";
    print("$tree_cmd\n") if($self->debug);
    $tree_cmd .= " 2>&1 > /dev/null" unless($self->debug);
    unless(system($tree_cmd) == 0) {
      throw("error running clustalw, $!\n");
    }
    $self->{'newick_file'} = $self->{'file_root'} . ".ph";
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
}

##############################################################
#
# Family input/output section
#
##############################################################

sub dumpFamilyPeptidesToWorkdir
{
  my $self = shift;
  my $family = shift;

  $self->{'file_root'} = $self->worker_temp_directory. "family_". $family->dbID;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $fastafile = $self->{'file_root'} . ".fasta";
  return $fastafile if(-e $fastafile);
  print("fastafile = '$fastafile'\n") if($self->debug);

  #
  # get only peptide members 
  #

  my $seq_id_hash = {};
  
  my @members_attributes;

  push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

  if(scalar @members_attributes <= 1) {
    $self->update_single_peptide_family($family);
    return undef; #so clustalw isn't run
  }
  
  
  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");

  foreach my $member_attribute (@members_attributes) {
    my ($member,$attribute) = @{$member_attribute};
    my $member_stable_id = $member->stable_id;

    next if($seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;
    
    my $seq = $member->sequence;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;

    print OUTSEQ ">$member_stable_id\n$seq\n";
  }

  close OUTSEQ;
  
  return $fastafile;
}


sub update_single_peptide_family
{
  my $self   = shift;
  my $family = shift;
  
  my $familyMemberList = $family->get_all_Member_Attribute();

  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next unless($member->sequence);
    next if($member->source_name eq 'ENSEMBLGENE');

    $attribute->cigar_line(length($member->sequence)."M");
  }
}


sub parse_and_store_family 
{
  my $self = shift;
  my $clustalw_output =  $self->{'file_root'} . ".aln";
  my $family = $self->{'family'};
    
  if($clustalw_output and -e $clustalw_output) {
    $family->read_clustalw($clustalw_output);
  }

  my $familyDBA = $self->{'comparaDBA'}->get_FamilyAdaptor;

  # 
  # post process and copy cigar_line between duplicate sequences
  #  
  my $cigar_hash = {};
  my $familyMemberList = $family->get_all_Member_Attribute();
  #first build up a hash of cigar_lines that are defined
  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next unless($member->sequence_id);
    next unless(defined($attribute->cigar_line));
    next if($attribute->cigar_line eq '');
    next if($attribute->cigar_line eq 'NULL');

    $cigar_hash->{$member->sequence_id} = $attribute->cigar_line;
  }

  #next loop again to copy (via sequence_id) into members 
  #missing cigar_lines and then store them
  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next if($member->source_name eq 'ENSEMBLGENE');
    next unless($member->sequence_id);

    my $cigar_line = $cigar_hash->{$member->sequence_id};
    next unless($cigar_line);
    $attribute->cigar_line($cigar_line);

    printf("update family_member %s : %s\n",$member->stable_id, $attribute->cigar_line) if($self->debug);
    $familyDBA->update_relation([$member, $attribute]);
  }

}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreePeptidesToWorkdir
{
  my $self = shift;
  my $tree = shift;
  
  if($self->{'mpi'}) {
    $self->{'file_root'} = $self->analysis->db_file;
    $self->{'file_root'} .= "/job_" . $self->input_job->dbID . "_hive_" . $self->worker->hive_id . "/";
    mkdir($self->{'file_root'}, 0777);
  } else {
    $self->{'file_root'} = $self->worker_temp_directory;
  }
  $self->{'file_root'} .= "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $fastafile = $self->{'file_root'} . ".fasta";
  print("fastafile = '$fastafile'\n") if($self->debug);
  $self->{'input_fasta'} = $fastafile;

  return $fastafile if(-e $fastafile);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");

  my $seq_id_hash = {};
  my $member_list = $tree->get_all_leaves;  
  foreach my $member (@{$member_list}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next if($seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;
    
    my $seq = $member->sequence;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;

    print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
  }
  close OUTSEQ;
  return $fastafile;
}


sub dumpTreeMultipleAlignmentToWorkdir
{
  my $self = shift;
  my $tree = shift;
  
  $self->{'file_root'} = $self->worker_temp_directory. "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $clw_file = $self->{'file_root'} . ".aln";
  return $clw_file if(-e $clw_file);
  print("clw_file = '$clw_file'\n") if($self->debug);

  open(OUTSEQ, ">$clw_file")
    or $self->throw("Error opening $clw_file for write");


  my $seq_id_hash = {};
  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next if($seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;

    my $seq = $member->alignment_string;
    next if(!$seq);
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;
    print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
  }

  close OUTSEQ;
  
  return $clw_file;
}


sub parse_and_store_proteintree
{
  my $self = shift;

  return unless($self->{'protein_tree'});
  
  $self->parse_alignment_into_proteintree;
  $self->parse_newick_into_proteintree;
  
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $treeDBA->store($self->{'protein_tree'});
  $treeDBA->delete_nodes_not_in_tree($self->{'protein_tree'});
  $self->{'protein_tree'}->print_tree if($self->debug and $self->{'calc_tree'});
}


sub parse_alignment_into_proteintree
{
  my $self = shift;
  my $clustalw_output =  $self->{'file_root'} . ".aln";
  my $tree = $self->{'protein_tree'};
  
  print("parse_alignment_into_proteintree from $clustalw_output\n") if($self->debug);

  unless($tree and defined($clustalw_output) and (-e $clustalw_output)) {
    printf("Error! : file missing\n");
    return;
  }
 
  
  #
  # parse alignment file into hash: combine alignment lines
  #
  my %align_hash;
  my $FH = IO::File->new();
  $FH->open($clustalw_output) || throw("Could not open alignment file [$clustalw_output]");

  <$FH>; #skip header
  while(<$FH>) {
    next if($_ =~ /^\s+/);  #skip lines that start with space
    
    my ($id, $align) = split;
    $align_hash{$id} ||= '';
    $align_hash{$id} .= $align;
  }
  $FH->close;

  #
  # convert clustalw alignment string into a cigar_line
  #
  foreach my $id (keys %align_hash) {
    my $alignment_string = $align_hash{$id};
    $alignment_string =~ s/\-([A-Z])/\- $1/g;
    $alignment_string =~ s/([A-Z])\-/$1 \-/g;

    my @cigar_segments = split " ",$alignment_string;

    my $cigar_line = "";
    foreach my $segment (@cigar_segments) {
      my $seglength = length($segment);
      $seglength = "" if ($seglength == 1);
      if ($segment =~ /^\-+$/) {
        $cigar_line .= $seglength . "D";
      } else {
        $cigar_line .= $seglength . "M";
      }
    }
    $align_hash{$id} = $cigar_line;
  }

  #
  # align cigar_line to member and store
  #
  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    $member->cigar_line($align_hash{$member->sequence_id});
  }
}


sub parse_newick_into_proteintree
{
  my $self = shift;
  my $newick_file =  $self->{'newick_file'};
  my $tree = $self->{'protein_tree'};
  
  print("parse tree from newick_file $newick_file\n") if($self->debug);

  unless($tree and $newick_file and (-e $newick_file)) {
    printf("Error! : file missing\n");
    return;
  }
  
  #cleanup old tree structure- 
  #  flatten and reduce to only AlignedMember leaves
  $tree->flatten_tree;
  foreach my $node (@{$tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  open (FH, $newick_file) or throw("Could not open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);
  my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  
  #leaves of newick tree are named with sequence_id of members from input tree
  #move members (leaves) of input tree into newick tree to mirror the 'sequence_id' nodes
  foreach my $member (@{$tree->get_all_leaves}) {
    my $tmpnode = $newtree->find_node_by_name($member->sequence_id);
    if($tmpnode) {
      $tmpnode->parent->add_child($member);
      $member->distance_to_parent($tmpnode->distance_to_parent);
    } else {
      print("unable to find node in newick for member"); 
      $member->print_member;
    }
  }
  
  # merge the trees so that the children of the newick tree are now attached to the 
  # input tree's root node
  $tree->merge_children($newtree);

  #newick tree is now empty so release it
  $newtree->release_tree;

  #go through merged tree and remove 'sequence_id' place-holder leaves
  foreach my $node (@{$tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    $node->disavow_parent;
  }
  $tree->print_tree if($self->debug);
  
  #apply mimized least-square-distance-to-root tree balancing algorithm
  #balance_tree($tree);

  #$tree->build_leftright_indexing;

  #if($self->debug) {
  #  print("\nBALANCED TREE\n");
  #  $tree->print_tree;
  #}
}



###################################################
#
# tree balancing algorithm
#   find new root which minimizes least sum of squares 
#   distance to root
#
###################################################

sub balance_tree
{
  my $tree = shift;
  
  my $starttime = time();
  
  my $last_root = Bio::EnsEMBL::Compara::NestedSet->new;
  $last_root->merge_children($tree);
  
  my $best_root = $last_root;
  my $best_weight = calc_tree_weight($last_root);
  
  my @all_nodes = $last_root->get_all_subnodes;
  
  foreach my $node (@all_nodes) {
    $node->re_root;
    $last_root = $node;
    
    my $new_weight = calc_tree_weight($node);
    if($new_weight < $best_weight) {
      $best_weight = $new_weight;
      $best_root = $node;
    }
  }
  #printf("%1.3f secs to run balance_tree\n", (time()-$starttime));

  $best_root->re_root;
  $tree->merge_children($best_root);
}

sub calc_tree_weight
{
  my $tree = shift;

  my $weight=0.0;
  foreach my $node (@{$tree->get_all_leaves}) {
    my $dist = $node->distance_to_root;
    $weight += $dist * $dist;
  }
  return $weight;  
}


1;
