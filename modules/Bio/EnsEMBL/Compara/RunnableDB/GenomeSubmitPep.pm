#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::GenomeSubmitPep->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

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
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);
  my $input_hash = eval($self->input_id);
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);

  my $genome_db_id = $input_hash->{'gdb'};
  my $subset_id    = $input_hash->{'ss'};

  print("gdb = $genome_db_id\n");
  $self->throw("No genome_db_id in input_id") unless defined($genome_db_id);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

  unless($subset_id) {
    # get the subset of 'longest transcripts' for this genome_db_id
    $subset_id = $self->getSubsetIdForGenomeDBId($genome_db_id);
  }
  $self->{'pepSubset'} = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($subset_id); 
  
  return 1;
}


sub run
{
  my $self = shift;
  return 1;
}


sub write_output
{
  my $self = shift;

  # working from the longest peptide subset, create an analysis of
  # with logic_name 'SubmitPep_<taxon_id>_<assembly>'
  # with type MemberPep and fill the input_id_analysis table where
  # input_id is the member_id of a peptide and the analysis_id
  # is the above mentioned analysis
  #
  # This creates the starting point for the blasts (members against database)
  $self->createSubmitPepAnalysis($self->{'pepSubset'});
  
  return 1;
}



##################################
#
# subroutines
#
##################################

sub getSubsetIdForGenomeDBId {
  my $self         = shift;
  my $genome_db_id = shift;

  my @subsetIds = ();
  my $subset_id;

  my $sql = "SELECT distinct subset.subset_id " .
            "FROM member, subset, subset_member " .
            "WHERE subset.subset_id=subset_member.subset_id ".
            "AND subset.description like '%longest%' ".
            "AND member.member_id=subset_member.member_id ".
            "AND member.genome_db_id=$genome_db_id;";
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$subset_id );
  while( $sth->fetch() ) {
    print("found subset_id = $subset_id for genome_db_id = $genome_db_id\n");
    push @subsetIds, $subset_id;
  }
  $sth->finish();

  if($#subsetIds > 0) {
    warn ("Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#subsetIds < 0) {
    warn ("Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }

  return $subsetIds[0];
}


# working from the longest peptide subset, create an analysis of
# with logic_name 'SubmitPep_<taxon_id>_<assembly>'
# with type MemberPep and fill the input_id_analysis table where
# input_id is the member_id of a peptide and the analysis_id
# is the above mentioned analysis
#
# This creates the starting point for the blasts (members against database)
sub createSubmitPepAnalysis {
  my $self    = shift;
  my $subset  = shift;

  print("\createSubmitPepAnalysis\n");

  #my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA
  my $jobDBA = $self->db->get_AnalysisJobAdaptor;

  my $logic_name = "SubmitPep_" .
                   $self->{'genome_db'}->dbID() .
                   "_".$self->{'genome_db'}->assembly();

  print("  see if analysis '$logic_name' is in database\n");
  my $analysis =  $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
  if($analysis) { print("  YES in database with analysis_id=".$analysis->dbID()); }

  unless($analysis) {
    $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
        #-db              => $blastdb->dbname(),
        -db_file         => $subset->dump_loc(),
        -db_version      => '1',
        -parameters      => "subset_id=>" . $subset->dbID().",genome_db_id=>".$self->{'genome_db'}->dbID(),
        -logic_name      => $logic_name,
        -input_id_type   => 'MemberPep',
        -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Dummy',
      );
    $self->db->get_AnalysisAdaptor()->store($analysis);
  }

  #my $host = hostname();
  print("store member_id into analysis_job table\n");
  my $errorCount=0;
  my $tryCount=0;
  my @member_id_list = @{$subset->member_id_list()};
  print($#member_id_list+1 . " members in subset\n");

  foreach my $member_id (@member_id_list) {
    $jobDBA->create_new_job (
        -input_id       => $member_id,
        -analysis_id    => $analysis->dbID,
        -input_job_id   => 0,
        -block          => 1
        );
  }

  print("CREATED all analysis_jobs\n");


=head3
      eval {
        $tryCount++;
        $sicDBA->store_input_id_analysis($member_id, #input_id
                                         $analysis,
                                         'gaia', #execution_host
                                         0 #save runtime NO (ie do insert)
                                        );
      };
      if($@) {
        $errorCount++;
        if($errorCount>42 && ($errorCount/$tryCount > 0.95)) {
          die("too many repeated failed insert attempts, assume will continue for durration. ACK!!\n");
        }
      } # should handle the error, but ignore for now
    }
  };
=cut


  return $logic_name;
}

1;
