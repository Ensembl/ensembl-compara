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
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a new Compara::DBAdaptor which points to the same database
  #as the Pipeline::DBAdaptor passed in ($self->db)
  #the -DBCONN options uses the dbname,user,pass,port,host,driver from the
  #variable DBConnection to create the new connection (in essence a copy)

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);
 
  return 1;
}


sub run
{
  my $self = shift;
 
  my($conditionLogicName, $goalLogicName) = split(/,/, $self->input_id());
  if($conditionLogicName and $goalLogicName) {
    print("create rule $conditionLogicName => $goalLogicName\n");
    my $conditionAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($conditionLogicName);
    my $goalAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($goalLogicName);
    $self->addRule($conditionAnalysis, $goalAnalysis);
  }
  else {
    $self->createBlastRules();
  } 
  $self->createBuildHomologyInput();
  return 1;
}

sub write_output
{
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success
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
      my $blastPhylum = $self->phylumForGenomeDBID($genomeDB1->dbID);
      #rint("\nANALYSIS ".$blastAnalysis->logic_name()." is a ".$blastPhylum."\n");

      foreach my $analysis (@{$analysisList}) {
        if($analysis->logic_name =~ /SubmitPep_/) {
          my $genome_db_id = parse_as_hash($analysis->parameters)->{'genome_db_id'};
          if($genome_db_id and ($genome_db_id ne $genomeDB1->dbID)) {
            my $phylum = $self->phylumForGenomeDBID($genome_db_id);
            #print("  check ".$analysis->logic_name().
            #      " genome_db_id=".$parameters{'genome_db_id'}.
            #      " phylum=".$phylum."\n");
  
            if(($self->input_id() eq 'all') or ($blastPhylum eq $phylum) ) {
              #$analysis is a SubmitPep so it's the condition
              #$blastAnalysis is the goal
              # $self->addSimpleRule($analysis, $blastAnalysis);

              $self->addRule($analysis, $blastAnalysis);
            }
          }
        }
      }
    }
  }

  my @rules = @{$self->{'comparaDBA'}->get_adaptor('SimpleRule')->fetch_all};
  foreach my $rule (@rules){
    print("simple_rule dbID=".$rule->dbID.
          "  condition_id=".$rule->conditionAnalysis->dbID .
          "  goal_id=".$rule->goalAnalysis->dbID .
          "  goal_type=".$rule->goalAnalysis->input_id_type . "\n");

    if($rule->goalAnalysis->input_id_type eq 'ACCUMULATOR') {
      print("  IS ACCUMULATOR\n");
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
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();
  $sth->bind_columns( undef, \$phylum );
  $sth->fetch();
  $sth->finish();

  return $phylum;
}


sub addSimpleRule
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;
  
  print("SIMPLERULE ".$conditionAnalysis->logic_name." -> ".$goalAnalysis->logic_name."\n");
  
  my $rule = Bio::EnsEMBL::Compara::SimpleRule->new(
      '-goal_analysis'      => $goalAnalysis,
      '-condition_analysis' => $conditionAnalysis);
      
  $self->{'comparaDBA'}->get_adaptor('SimpleRule')->store($rule);

  my $temp_rule = $self->{'comparaDBA'}->get_adaptor('SimpleRule')->fetch_by_dbID($rule->dbID);
}


sub addRule
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;
  my $rule;

  print("RULE ".$conditionAnalysis->logic_name." -> ".$goalAnalysis->logic_name."\n");

  $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalanalysis' => $goalAnalysis);
  $rule->add_condition($conditionAnalysis->logic_name());

  if($self->checkRuleExists($rule)) {
    print("  EXISTS!\n");
  } else {
    $self->db->get_RuleAdaptor->store($rule);
  }
}


sub createBuildHomologyInput
{
  my $self = shift;
  my ($analysis1, $analysis2, $input_id);

  my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA
  my @analysisList = @{$self->db->get_AnalysisAdaptor->fetch_all()};

  my $submitHomology = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitHomologyPair',
      -input_id_type   => 'homology'
    );
  $self->db->get_AnalysisAdaptor()->store($submitHomology);

  while(@analysisList) {
    $analysis1 = shift @analysisList;
    foreach my $analysis2 (@analysisList) {
      my $genome_db_id1 = parse_as_hash($analysis1->parameters)->{'genome_db_id'};
      my $genome_db_id2 = parse_as_hash($analysis2->parameters)->{'genome_db_id'};
      if(($analysis1->logic_name =~ /blast_/) and
         ($analysis2->logic_name =~ /blast_/) and
         $genome_db_id1 and $genome_db_id2)
      { 
        if($genome_db_id1 < $genome_db_id2) {
          $input_id = $analysis1->logic_name . ",". $analysis2->logic_name;
        } else {
          $input_id = $analysis2->logic_name . ",". $analysis1->logic_name;
        }
        print("HOMOLOGY '$input_id'\n");

        $sicDBA->store_input_id_analysis($input_id,
                                         $submitHomology,
                                         'gaia', #execution_host
                                         0 #save runtime NO (ie do insert)
                                        );
      }
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

sub parse_as_hash{
  my $hash_string = shift;

  my %hash;

  return \%hash unless($hash_string);

  my @pairs = split (/,/, $hash_string);
  foreach my $pair (@pairs) {
    my ($key, $value) = split (/=>/, $pair);
    if ($key && $value) {
      $key   =~ s/^\s+//g;
      $key   =~ s/\s+$//g;
      $value =~ s/^\s+//g;
      $value =~ s/\s+$//g;

      $hash{$key} = $value;
    } else {
      $hash{$key} = "__NONE__";
    }
  }
  return \%hash;
}

1;
