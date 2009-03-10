#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Muscle

=cut

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $muscle = Bio::EnsEMBL::Compara::RunnableDB::Muscle->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$muscle->fetch_input(); #reads from DB
$muscle->run();
$muscle->output();
$muscle->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a Family (or Homology) as input
Run a MUSCLE multiple alignment on it, and store the resulting alignment
back into the family_member table.

input_id/parameters format eg: "{'family_id'=>1234,'options'=>'-maxiters 2'}"
    family_id       : use family_id to run multiple alignment on its members
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree
    options         : commandline options to pass to the 'muscle' program

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

package Bio::EnsEMBL::Compara::RunnableDB::Muscle;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Time::HiRes qw(time gettimeofday tv_interval);
use POSIX qw(ceil floor);

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

  #$self->{'options'} = "-maxiters 1 -diags1 -sv"; #fast options
  $self->{'options'} = "";
  $self->{'muscle_starttime'} = time()*1000;
  $self->{'max_gene_count'} = 1500;

  $self->check_job_fail_options;
  
#  if($self->input_job->retry_count >= 3) {
#    $self->dataflow_output_id($self->input_id, 2);
#    $self->input_job->update_status('FAILED');
#    throw("Muscle job failed >3 times: try something else and FAIL it");
#  }
  
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  $self->check_if_exit_cleanly;

  if($self->{'family'}) {
    $self->{'input_fasta'} = $self->dumpFamilyPeptidesToWorkdir($self->{'family'});
  } elsif($self->{'protein_tree'}) {
    if ($self->{'protein_tree'}->get_tagvalue('gene_count') > $self->{'max_gene_count'}) {
      $self->dataflow_output_id($self->input_id, 2);
      $self->input_job->update_status('FAILED');
      $self->{'protein_tree'}->release_tree;
      $self->{'protein_tree'} = undef;
      throw("Muscle : cluster size over threshold and FAIL it");
    }
    $self->{'input_fasta'} = $self->dumpProteinTreeToWorkdir($self->{'protein_tree'});
  } else {
    throw("undefined family as input\n");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs MUSCLE
    Returns :   none
    Args    :   none
    
=cut

sub run
{
  my $self = shift;

  $self->check_if_exit_cleanly;
  return unless($self->{'input_fasta'});  
  $self->{'muscle_output'} = $self->run_muscle;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse muscle output and update family and family_member tables
    Returns :   none
    Args    :   none
    
=cut

sub write_output {
  my $self = shift;

  $self->check_if_exit_cleanly;
  if($self->{'family'}) {
    $self->parse_and_store_alignment_into_family;
  } elsif($self->{'protein_tree'}) {
    $self->parse_and_store_alignment_into_proteintree;
    #done so release the tree
    $self->{'protein_tree'}->release_tree;
  } else {
    throw("undefined family as input\n");
  }
  
  $self->cleanup_job_tmp_files unless($self->debug);
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
    
  if(defined($params->{'family_id'})) {
    $self->{'family'} =  $self->{'comparaDBA'}->get_FamilyAdaptor->fetch_by_dbID($params->{'family_id'});
  }
  if(defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree'} =  
         $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_node_by_node_id($params->{'protein_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
  }
  $self->{'options'} = $params->{'options'} if(defined($params->{'options'}));
  $self->{'max_gene_count'} = $params->{'max_gene_count'} if(defined($params->{'max_gene_count'}));
  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   family_id     : ", $self->{'family'}->dbID,"\n") if($self->{'family'});
  print("   options       : ", $self->{'options'},"\n") if($self->{'options'});
}


sub run_muscle
{
  my $self = shift;
  my $input_fasta = $self->{'input_fasta'};

  my $muscle_output = $input_fasta .".msc";
  $muscle_output =~ s/\/\//\//g;  # converts any // in path to /

  my $muscle_executable = $self->analysis->program_file;
  unless (-e $muscle_executable) {
    $muscle_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/muscle";
    if (-e "/proc/version") {
      # it is a linux machine
      $muscle_executable = "/nfs/acari/abel/bin/i386/muscle";
    }
  }
  throw("can't find a muscle executable to run\n") unless(-e $muscle_executable);

  my $cmd = $muscle_executable;
  $cmd .= " ". "-maxiters 3 " if($self->input_job->retry_count >= 2);
  $cmd .= " ". $self->{'options'};
  $cmd .= " -clw -nocore -verbose -quiet ";
  $cmd .= " -in " . $input_fasta;
  $cmd .= " -out $muscle_output -log $muscle_output.log";
  
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    $self->check_job_fail_options;
    throw("error running muscle, $!\n");
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  $self->{'muscle_output'} = $muscle_output;
  return $muscle_output;
}

sub cleanup_job_tmp_files
{
  my $self = shift;
  
  unlink ($self->{'input_fasta'}) if($self->{'input_fasta'});
  if($self->{'muscle_output'}) {
    unlink ($self->{'muscle_output'});
    unlink ($self->{'muscle_output'} . ".log");
  }
}


sub check_job_fail_options
{
  my $self = shift;

  if($self->input_job->retry_count >= 2) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');

    if($self->{'protein_tree'}) {
      $self->{'protein_tree'}->release_tree;
      $self->{'protein_tree'} = undef;
    }
    throw("Muscle job failed >=3 times: try something else and FAIL it");
  }
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

  my $fastafile = $self->worker_temp_directory. "family_". $family->dbID. ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
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
    return undef; #so muscle isn't run
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
    printf("single_pepide_family %s : %s\n", $member->stable_id, $attribute->cigar_line) if($self->debug);
  }
}


sub parse_and_store_alignment_into_family 
{
  my $self = shift;
  my $muscle_output =  $self->{'muscle_output'};
  my $family = $self->{'family'};
    
  if($muscle_output and -e $muscle_output) {
    $family->read_clustalw($muscle_output);
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

sub update_single_peptide_tree
{
  my $self   = shift;
  my $tree   = shift;
  
  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->{'comparaDBA'}->get_ProteinTreeAdaptor->store($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}

sub dumpProteinTreeToWorkdir
{
  my $self = shift;
  my $tree = shift;

  my $fastafile = $self->worker_temp_directory. "proteintree_". $tree->node_id. ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);
  print("fastafile = '$fastafile'\n") if($self->debug);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");

  my $seq_id_hash = {};
  my $residues = 0;
  my $member_list = $tree->get_all_leaves;
  $tree->store_tag('gene_count', scalar(@$member_list));
  foreach my $member (@{$member_list}) {
    next if($seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;
    
    my $seq = $member->sequence;
    $residues += $member->seq_length;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;

    print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
  }
  close OUTSEQ;
  
  if(scalar keys (%{$seq_id_hash}) <= 1) {
    $self->update_single_peptide_tree($tree);
    return undef; #so muscle isn't run
  }

  $tree->store_tag('cluster_residue_count', $residues);

  return $fastafile;
}


sub parse_and_store_alignment_into_proteintree
{
  my $self = shift;
  my $muscle_output =  $self->{'muscle_output'};
  my $tree = $self->{'protein_tree'};
  
  return unless($muscle_output);
  
  #
  # parse alignment file into hash: combine alignment lines
  #
  my %align_hash;
  my $FH = IO::File->new();
  $FH->open($muscle_output) || throw("Could not open alignment file [$muscle_output]");

  <$FH>; #skip header
  while(<$FH>) {
    next if($_ =~ /^\s+/);  #skip lines that start with space
    chomp;
    my ($id, $align) = split;
    $align_hash{$id} ||= '';
    $align_hash{$id} .= $align;
  }
  $FH->close;

  #
  # convert clustalw alignment string into a cigar_line
  #
  my $alignment_length;
  foreach my $id (keys %align_hash) {
    my $alignment_string = $align_hash{$id};
    unless (defined $alignment_length) {
      $alignment_length = length($alignment_string);
    } else {
      if ($alignment_length != length($alignment_string)) {
        throw("While parsing the alignment, some id did not return the expected alignment length\n");
      }
    }
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
    if ($align_hash{$member->sequence_id} eq "") {
      throw("muscle did produce an empty cigar_line for ".$member->stable_id."\n");
    }
    $member->cigar_line($align_hash{$member->sequence_id});
    ## Check that the cigar length (Ms) matches the sequence length
    my @cigar_match_lengths = map { if ($_ eq '') {$_ = 1} else {$_ = $_;} } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
    my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
    my $member_sequence = $member->sequence; $member_sequence =~ s/\*//g;
    if ($seq_cigar_length != length($member_sequence)) {
        throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
    }
    #
    printf("update protein_tree_member %s : %s\n",$member->stable_id, $member->cigar_line) if($self->debug);
    $self->{'comparaDBA'}->get_ProteinTreeAdaptor->store($member);
  }

  $tree->store_tag('alignment_method', 'Muscle');
  my $runtime = floor(time()*1000-$self->{'muscle_starttime'});
  $tree->store_tag('MUSCLE_runtime_msec', $runtime);

  # Fetch the alignment and calculate the percent identity
  my $sa = $tree->get_SimpleAlign;
  my $avg_pi = $sa->average_percentage_identity;
  $tree->store_tag('MUSCLE_avg_percent_identity', sprintf("%.3f",$avg_pi));
  # Also store alignment length
  $tree->store_tag('MUSCLE_alignment_length', $sa->length);

  return undef;
}

1;
