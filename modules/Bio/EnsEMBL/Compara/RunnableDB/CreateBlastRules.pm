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

  $self->createBlastRules();
  
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
        my %parameters = $self->parameter_hash($analysis->parameters());
        if($parameters{'genome_db_id'} and
           ($parameters{'genome_db_id'} ne $genomeDB1->dbID))
        {
          my $phylum = $self->phylumForGenomeDBID($parameters{'genome_db_id'});
          #print("  check ".$analysis->logic_name().
          #      " genome_db_id=".$parameters{'genome_db_id'}.
          #      " phylum=".$phylum."\n");
          if(($blastPhylum eq $phylum) and ($analysis->logic_name =~ /SubmitPep_/)) {
            #$analysis is a SubmitPep so it's the condition
            #$blastAnalysis is the goal
            $self->addSimpleRule($analysis, $blastAnalysis);
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
  
  print("RULE ".$conditionAnalysis->logic_name." -> ".$goalAnalysis->logic_name."\n");
  
  my $rule = Bio::EnsEMBL::Compara::SimpleRule->new(
      '-goal_analysis'      => $goalAnalysis,
      '-condition_analysis' => $conditionAnalysis);
      
  $self->{'comparaDBA'}->get_adaptor('SimpleRule')->store($rule);

  my $temp_rule = $self->{'comparaDBA'}->get_adaptor('SimpleRule')->fetch_by_dbID($rule->dbID);
}


sub parameter_hash{
  my $self = shift;
  my $parameter_string = shift;

  my %parameters;

  if ($parameter_string) {

    my @pairs = split (/,/, $parameter_string);
    foreach my $pair (@pairs) {
      my ($key, $value) = split (/=>/, $pair);
      if ($key && $value) {
        $key   =~ s/^\s+//g;
        $key   =~ s/\s+$//g;
        $value =~ s/^\s+//g;
        $value =~ s/\s+$//g;

        $parameters{$key} = $value;
      } else {
        $parameters{$key} = "__NONE__";
      }
    }
  }
  return %parameters;
}
1;
