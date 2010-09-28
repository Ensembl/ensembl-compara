#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. 

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

package Bio::EnsEMBL::Compara::RunnableDB::GenomeCalcStats;

use strict;
use Statistics::Descriptive;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

=head2 batch_size
  Title   :   batch_size
  Usage   :   $value = $self->batch_size;
  Description: Defines the number of jobs the RunnableDB subclasses should run in batch
               before querying the database for the next job batch.  Used by the
               Hive system to manage the number of workers needed to complete a
               particular job type.
  Returntype : integer scalar
=cut
sub batch_size { return 1; }

=head2 carrying_capacity
  Title   :   carrying_capacity
  Usage   :   $value = $self->carrying_capacity;
  Description: Defines the total number of Workers of this RunnableDB for a particular
               analysis_id that can be created in the hive.  Used by Queen to manage
               creation of Workers.
  Returntype : integer scalar
=cut
sub carrying_capacity { return 20; }


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  my $input_hash = eval($self->input_id);
  my $genome_db_id = $input_hash->{'gdb'};
  $self->throw("No genome_db_id in input_id") unless defined($genome_db_id);
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
  
  
  return 1;
}


sub run
{
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  
  $self->calc_intergenic_stats();
  
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
                                          
  return 1;
}

sub write_output 
{  
  my $self = shift;
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success

  return 1;
}


######################################
#
# subroutines
#
#####################################


sub calc_intergenic_stats
{
  my $self = shift;

  return unless(defined($self->{'genome_db'}));
  
  print("calc_inter_genic_distance for '", $self->{'genome_db'}->name(), "'\n");

  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();
  $memberDBA->_final_clause("ORDER BY m.chr_name, m.chr_start");
  my $sortedMembers = $memberDBA->fetch_by_source_taxon('ENSEMBLGENE', $self->{'genome_db'}->taxon_id);
  print(scalar(@{$sortedMembers}) . " members to process\n");

  my $intergenic_stats = Statistics::Descriptive::Full->new();
  my $genesize_stats = Statistics::Descriptive::Full->new();
  my $overlapCount=0;
  
  my $lastMember = shift @{$sortedMembers};
  #$lastMember->print_member;
  foreach my $member (@{$sortedMembers}) {
    #$member->print_member;
    $genesize_stats->add_data($member->chr_end - $member->chr_start);

    if($lastMember->chr_name ne $member->chr_name) {
      print("broken syntenty from \n");
      $lastMember->print_member;
      $member->print_member;
    }
    else {
      my $dist = ($member->chr_start - $lastMember->chr_end);
      if($dist < 0) { $dist=0; $overlapCount++; }
      $intergenic_stats->add_data($dist);
    }
    $lastMember = $member;
  }

  $intergenic_stats->{'overlapCount'} = $overlapCount;
  
  print("intergenic overlap = ",$overlapCount,"\n");
  print("intergenic overlap = ",$intergenic_stats->{'overlapCount'},"\n");

  $self->insert_statistics($intergenic_stats, 'intergenic');
  $self->insert_statistics($genesize_stats, 'gene_size');  
}


sub insert_statistics
{
  my $self = shift;
  my $stats = shift;
  my $dataType = shift; 
  
  my $sql = "INSERT ignore INTO genome_db_stats SET data_type='$dataType'"
            ." ,genome_db_id=".$self->{'genome_db'}->dbID
            ." ,count='".$stats->count()."'"
            ." ,mean='".$stats->mean()."'"
            ." ,median='".$stats->median()."'"
            ." ,mode='".$stats->mode()."'"
            ." ,stddev='".$stats->standard_deviation()."'"
            ." ,variance='".$stats->variance()."'"
            ." ,min='".$stats->min()."'"
            ." ,max='".$stats->max()."'";

  $sql .=  " ,overlap_count='".$stats->{'overlapCount'}."'" if($stats->{'overlapCount'});

  print("$sql\n");            
  my $sth = $self->db->dbc->prepare($sql);
  $sth->execute;
  $sth->finish;
}


1;
