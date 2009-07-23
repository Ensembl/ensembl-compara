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
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Process module which takes the member peptides defined in a subset and genome_db
passed in the input_id and creates an new analysis and fills it with these peptides
as jobs to be flowed into the Blast analyses.

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
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisStatsAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

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
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /\{/);
  my $input_hash = eval($self->input_id);
  
  #create a Compara::DBAdaptor which shares the same DBConnection as $self->db
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  $self->{'analysisStatsDBA'} = $self->db->get_AnalysisStatsAdaptor;

  $self->db->dbc->disconnect_when_inactive(0);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
    
  my $genome_db_id = $input_hash->{'gdb'};
  my $subset_id    = $input_hash->{'ss'};
  $self->{'reference_name'} = undef;

  if(defined($genome_db_id)) {
    print("gdb = $genome_db_id\n");

    #get the Compara::GenomeDB object for the genome_db_id
    $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

    $self->{'reference_name'} = $self->{'genome_db'}->dbID()."_".$self->{'genome_db'}->assembly();

    unless($subset_id) {
      # get the subset of 'longest transcripts' for this genome_db_id
      $subset_id = $self->getSubsetIdForGenomeDBId($genome_db_id);
    }
  }
  
  throw("no subset defined, can't figure out which peptides to use\n") 
    unless(defined($subset_id));
  
  $self->{'pepSubset'} = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($subset_id); 

  unless($self->{'reference_name'}) {
    $self->{'reference_name'} = $self->{'pepSubset'}->description;
    $self->{'reference_name'} =~ s/\s+/_/g;
  }

  
  return 1;
}


sub run
{
  my $self = shift;
  $self->create_peptide_align_feature_table($self->{'genome_db'});
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

  if (!UNIVERSAL::isa($subset, "Bio::EnsEMBL::Compara::Subset")) {
    throw("Calling createSubmitPepAnalysis without a proper subset [$subset]");
  }
  
  print("\ncreateSubmitPepAnalysis\n");
  
  my $logic_name = "SubmitPep_" . $self->{'reference_name'};

  print("  see if analysis '$logic_name' is in database\n");
  my $analysis =  $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
  if($analysis) { print("  YES in database with analysis_id=".$analysis->dbID()); }

  unless($analysis) {
    print("  NOPE: go ahead and insert\n");
    $analysis = Bio::EnsEMBL::Analysis->new(
        -db              => '',
        -db_file         => $subset->dump_loc(),
        -db_version      => '1',
        -parameters      => "{subset_id=>" . $subset->dbID()."}",
        -logic_name      => $logic_name,
        -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      );
    $self->db->get_AnalysisAdaptor()->store($analysis);

    my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($analysis->dbID);
    $stats->batch_size(500);
    $stats->hive_capacity(10);
    $stats->status('BLOCKED');
    $stats->update();   
  }

  # create unblocking rules from CreateBlastRules to this new analysis
  my $createRules = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('CreateBlastRules');
  $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($createRules, $analysis);

  
  #my $host = hostname();
  print("store member_id into analysis_job table\n");
  my $errorCount=0;
  my $tryCount=0;
  my @member_id_list = @{$subset->member_id_list()};
  print($#member_id_list+1 . " members in subset\n");

  foreach my $member_id (@member_id_list) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $member_id,
        -analysis       => $analysis,
        -input_job_id   => 0,
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

#####################################################################
##
## create_peptide_align_feature_table
##
#####################################################################

sub create_peptide_align_feature_table {
  my ($self, $genome_db) = @_;

  my $genome_db_id = $genome_db->dbID;
  my $species_name = lc($genome_db->name);
  $species_name =~ s/\ /\_/g;
  my $table_name = "peptide_align_feature_${species_name}_${genome_db_id}";
  my $sql = "CREATE TABLE IF NOT EXISTS $table_name like peptide_align_feature";

  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  $sth->execute();

  # Disable keys makes inserts faster
  $sql = "ALTER TABLE $table_name DISABLE KEYS";

  $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();
}

1;
