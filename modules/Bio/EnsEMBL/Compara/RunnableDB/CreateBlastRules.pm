#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::CreateBlastRules->new (
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

package Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor;

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


sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  if($self->analysis->parameters =~ /{/) {
    $self->{'create_all'} = eval($self->analysis->parameters)->{'allToAll'};
    print("create rules allToAll\n") if($self->{'create_all'});
  }
  
  #create a new Compara::DBAdaptor which points to the same database
  #as the Pipeline::DBAdaptor passed in ($self->db)
  #the -DBCONN options uses the dbname,user,pass,port,host,driver from the
  #variable DBConnection to create the new connection (in essence a copy)

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);

  return 1;
}


sub run
{
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success
  return 1;
}


sub write_output
{
  my $self = shift;

  $self->configureHomologyAnalysis();
  
  my $input_hash = eval($self->input_id);
  if($input_hash and $input_hash->{'peps'} and $input_hash->{'blast'}) {
    my $conditionLogicName = $input_hash->{'peps'};
    my $goalLogicName = $input_hash->{'blast'};
    print("create rule $conditionLogicName => $goalLogicName\n");
    my $conditionAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($conditionLogicName);
    my $goalAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($goalLogicName);
    $self->addHomologyPair($conditionAnalysis, $goalAnalysis);
  }
  else {
    $self->createBlastRules();
  } 
  $self->createBuildHomologyInput();
  return 1;
}




##################################
#
# subroutines
#
##################################


# scan the analysis table for valid SubmitPep_<> analyses that
# can get made conditions of any blast_<> analyses
sub createBlastRules
{
  my $self = shift;

  my $genomeList   = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all();
  my $analysisList = $self->db->get_AnalysisAdaptor->fetch_all();

  foreach my $genomeDB1 (@{$genomeList}) {
    my $blastLogicName = "blast_" . $genomeDB1->dbID. "_". $genomeDB1->assembly;
    my $blastAnalysis =  $self->db->get_AnalysisAdaptor->fetch_by_logic_name($blastLogicName);
    if($blastAnalysis) {
      $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($blastAnalysis, $self->{'submitHomology'});

      my $blastPhylum = $self->phylumForGenomeDBID($genomeDB1->dbID);
      #rint("\nANALYSIS ".$blastAnalysis->logic_name()." is a ".$blastPhylum."\n");
      foreach my $analysis (@{$analysisList}) {
        if($analysis->logic_name =~ /SubmitPep_/) {
          my $genome_db_id = eval($analysis->parameters)->{'genome_db_id'};
          if($genome_db_id and ($genome_db_id ne $genomeDB1->dbID)) {
            my $phylum = $self->phylumForGenomeDBID($genome_db_id);
            #print("  check ".$analysis->logic_name().
            #      " genome_db_id=".$parameters{'genome_db_id'}.
            #      " phylum=".$phylum."\n");
  
            if($self->{'create_all'} or ($blastPhylum eq $phylum) ) {
              #$analysis is a SubmitPep so it's the condition
              #$blastAnalysis is the goal
              $self->addHomologyPair($analysis, $blastAnalysis);
            }
          }
        }
      }
    }
  }
}


sub phylumForGenomeDBID
{
  my $self = shift;
  my $genome_db_id = shift;
  my $phylum;

  unless($genome_db_id) { return undef; }

  my $sql = "SELECT phylum FROM genome_db_extn " .
            "WHERE genome_db_id=$genome_db_id;";
  my $sth = $self->db->prepare( $sql );
  $sth->execute();
  $sth->bind_columns( undef, \$phylum );
  $sth->fetch();
  $sth->finish();

  return $phylum;
}


sub addHomologyPair
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;

  if($self->db->isa('Bio::EnsEMBL::Hive::DBSQL::DBAdaptor')) {
    $self->db->get_DataflowRuleAdaptor->create_rule($conditionAnalysis, $goalAnalysis);
  } else {
    $self->addRule($conditionAnalysis, $goalAnalysis);
  }

  #$self->addBuildHomologyInput($conditionAnalysis, $goalAnalysis);

}


sub addRule
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;
  my $rule;

  print("PIPELINE RULE ".$conditionAnalysis->logic_name." -> ".$goalAnalysis->logic_name."\n");

  $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalanalysis' => $goalAnalysis);
  $rule->add_condition($conditionAnalysis->logic_name());

  if($self->checkRuleExists($rule)) {
    print("  EXISTS!\n");
  } else {
    $self->db->get_RuleAdaptor->store($rule);
  }
}


sub configureHomologyAnalysis
{
  my $self = shift;

  return if($self->{'submitHomology'});
  
  my $isHive = $self->db->isa('Bio::EnsEMBL::Hive::DBSQL::DBAdaptor');

  #my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA
  $self->{'submitHomology'} = $self->db->get_AnalysisAdaptor()->
                              fetch_by_logic_name('SubmitHomologyPair');
  return if($self->{'submitHomology'});
  

  my $submitHomology = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitHomologyPair',
      -input_id_type   => 'homology',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Dummy',
    );
  $self->db->get_AnalysisAdaptor()->store($submitHomology);
  $self->{'submitHomology'} = $submitHomology;
  if($isHive) {
    my $stats = $self->db->get_AnalysisStatsAdaptor->fetch_by_analysis_id($submitHomology->dbID);
    $stats->batch_size(7000);
    $stats->hive_capacity(1);
    $stats->status('BLOCKED');
    $stats->update();
  }


  my $buildHomology = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'BuildHomology',
      -input_id_type   => 'homology',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHomology',
    );
  $self->db->get_AnalysisAdaptor->store($buildHomology);
  $self->{'buildHomology'} = $buildHomology;
  if($isHive) {
    my $stats = $self->db->get_AnalysisStatsAdaptor->fetch_by_analysis_id($buildHomology->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(3);
    $stats->update();
  }

  if($isHive) {
    $self->db->get_DataflowRuleAdaptor->create_rule($submitHomology,$buildHomology);
  } else {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$buildHomology);
    $rule->add_condition($submitHomology->logic_name());
    $self->db->get_RuleAdaptor->store($rule);
  }
}


sub addBuildHomologyInput
{
  my $self = shift;
  my $analysis1 = shift;
  my $analysis2 = shift;
  my $noRHS = shift;

  return unless($analysis1 and $analysis2);
  return unless($analysis1->parameters and $analysis2->parameters);
  return unless($analysis1->logic_name =~ /blast_/);
  return unless($analysis2->logic_name =~ /blast_/);

  my $genome_db_id1 = eval($analysis1->parameters)->{'genome_db_id'};
  my $genome_db_id2 = eval($analysis2->parameters)->{'genome_db_id'};
  return unless ($genome_db_id1 and $genome_db_id2);

  return unless($self->{'submitHomology'});
  
  my $input_id;

  my $isHive = $self->db->isa('Bio::EnsEMBL::Hive::DBSQL::DBAdaptor');
  #my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA


  if($genome_db_id1 < $genome_db_id2) {
    $input_id = "{blasts=>['".$analysis1->logic_name . "','". $analysis2->logic_name . "']";
  } else {
    $input_id = "{blasts=>['".$analysis2->logic_name . "','". $analysis1->logic_name . "']";
  }
  if($noRHS and ($noRHS eq 'noRHS')) { $input_id .= ",noRHS=>1"; }
  $input_id .= "}";
  print("HOMOLOGY '$input_id'\n");

  if($isHive) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'submitHomology'},
        -input_job_id   => 0,
        );
  } else {
    $self->db->get_StateInfoContainer->store_input_id_analysis(
        $input_id,
        $self->{'submitHomology'},
        'gaia', #execution_host
        0 #save runtime NO (ie do insert)
        );
  }
}

sub createBuildHomologyInput
{
  my $self = shift;
  my ($analysis1, $analysis2);

  my @analysisList = @{$self->db->get_AnalysisAdaptor->fetch_all()};

  while(@analysisList) {
    $analysis1 = shift @analysisList;
    foreach $analysis2 (@analysisList) {
      $self->addBuildHomologyInput($analysis1, $analysis2);
    }
  }
}



sub checkRuleExists
{
  my $self = shift;
  my $queryRule = shift;

  my @allRules = $self->db->get_RuleAdaptor->fetch_all();
  foreach my $rule (@allRules) {
    #print("  check goal ".$rule->goalAnalysis->logic_name."\n");
    if($rule->goalAnalysis()->dbID eq $queryRule->goalAnalysis->dbID) {
      #print("  found goal match\n");
      my $allMatched=1;
      for my $literal (@{$rule->list_conditions}) {
        #print("    condition $literal ");
        my $matched = undef;
        for my $qliteral ( @{$queryRule->list_conditions} ) {
          if($qliteral eq $literal) {
            $matched=1;
            #print("matched!");
          } 
        }
        #print("\n");
        $allMatched=undef unless($matched);
      }
      if($allMatched) {
        # made it through all condtions and goal matched so this rule matches
        # print("  rule matched\n");
        return $rule;
      }
    }
  }

  return undef;
}

1;
