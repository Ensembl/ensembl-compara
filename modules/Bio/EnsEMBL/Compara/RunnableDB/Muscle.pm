#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Muscle

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::Muscle->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a Family as input
Run a MUSCLE multiple alignment on it, and store the resulting alignment
back into the family_member table.

=cut

=head1 CONTACT

Describe contact details here

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
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);
my $g_Worker_workdir;

sub workdir {
  unless(defined($g_Worker_workdir) and (-e $g_Worker_workdir)) {
    #create temp directory to hold fasta databases
    $g_Worker_workdir = "/tmp/worker.$$/";
    mkdir($g_Worker_workdir, 0777);
  }
  return $g_Worker_workdir;
}

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
  $self->{'options'} = "-maxiters 2";

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);

  throw("undefined family as input\n") unless($self->{'family'});

  $self->{'input_fasta'} = $self->dumpFamilyPeptidesToWorkdir($self->{'family'});

  if(!defined($self->{'input_fasta'})) {
    $self->update_single_peptide_family($self->{'family'});
  } 

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs MUSCLE and parses output into family
    Returns :   none
    Args    :   none
    
=cut

sub run
{
  my $self = shift;
  return unless($self->{'input_fasta'});  
  $self->run_muscle;
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

  my $familyDBA = $self->{'comparaDBA'}->get_FamilyAdaptor;
  my $familyMemberList = $self->{'family'}->get_all_Member_Attribute();
  
  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next if($member->source_name eq 'ENSEMBLGENE');
    next unless($member->sequence_id);
    
    printf("update family_member %s : %s\n",$member->stable_id, $attribute->cigar_line) if($self->debug);
    $familyDBA->update_relation([$member, $attribute]);
  }
  
}


sub global_cleanup {
  my $self = shift;
  if($g_Worker_workdir) {
    unlink(<$g_Worker_workdir/*>);
    rmdir($g_Worker_workdir);
  }
  return 1;
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
  $self->{'options'} = $params->{'options'} if(defined($params->{'options'}));
  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   family_id     : ", $self->{'family'}->dbID,"\n") if($self->{'family'});
  print("   options       : ", $self->{'options'},"\n") if($self->{'options'});
}


sub dumpFamilyPeptidesToWorkdir
{
  my $self = shift;
  my $family = shift;

  my $fastafile = workdir(). "family_". $family->dbID. ".fasta";
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

  return undef unless(scalar @members_attributes > 1);
  
  
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


sub run_muscle
{
  my $self = shift;

  my $muscle_output = workdir(). "family_". $self->{'family'}->dbID. ".msc";
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

  my $cmd = $muscle_executable . " -clw -nocore -verbose -quiet ";
  $cmd .= " ". $self->{'options'};
  $cmd .= " -in " . $self->{'input_fasta'};
  $cmd .= " -out $muscle_output -log $muscle_output.log";
  
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    throw("error running muscle, $!\n");
  }
  
  $self->{'family'}->read_clustalw($muscle_output);

  # 
  # post process and copy cigar_line between duplicate sequences
  #  
  my $cigar_hash = {};
  my $familyMemberList = $self->{'family'}->get_all_Member_Attribute();
  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next unless($member->sequence_id);
    next unless(defined($attribute->cigar_line) and $attribute->cigar_line ne '');
    $cigar_hash->{$member->sequence_id} = $attribute->cigar_line;
  }
  foreach my $familyMember (@{$familyMemberList}) {
    my ($member,$attribute) = @{$familyMember};
    next unless($member->sequence_id);
    next if(defined($attribute->cigar_line) and $attribute->cigar_line ne '');
    my $cigar_line = $cigar_hash->{$member->sequence_id};
    next unless($cigar_line);
    $attribute->cigar_line($cigar_line);
  }
  
}


1;
