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
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules->new (
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

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my $self = shift;

  throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  throw("Improper formated input_id") unless ($self->input_id =~ /\s*\{/);

  $self->{'selfBlast'} = 1;
  $self->{'phylumBlast'} = 0;
  if($self->analysis->parameters =~ /\s*\{/) {
    my $paramHash = eval($self->analysis->parameters);
    if($paramHash) {
      $self->{'phylumBlast'}=1 if($paramHash->{'phylumBlast'}==1);
      $self->{'selfBlast'}=0 if($paramHash->{'selfBlast'}==0);
      $self->{'cr_analysis_logic_name'} = $paramHash->{'cr_analysis_logic_name'} if(defined $paramHash->{'cr_analysis_logic_name'});
    }
  }
  
  #create a new Compara::DBAdaptor which points to the same database
  #as the pipeline DBAdaptor passed in ($self->db)
  #the -DBCONN options uses the dbname,user,pass,port,host,driver from the
  #variable DBConnection to create the new connection (in essence a copy)

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  if (defined $self->{'cr_analysis_logic_name'}) {
    $self->{'cr_analysis'} = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->{'cr_analysis_logic_name'});
    throw($self->{'cr_analysis_logic_name'} . " analysis is missing, can't proceed\n")
      unless(defined($self->{'cr_analysis'}));

  }
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

  my $input_hash = eval($self->input_id);
  if($input_hash and $input_hash->{'peps'} and $input_hash->{'blast'}) {
    my $conditionLogicName = $input_hash->{'peps'};
    my $goalLogicName = $input_hash->{'blast'};
    print("create rule $conditionLogicName => $goalLogicName\n");
    my $conditionAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($conditionLogicName);
    my $goalAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($goalLogicName);
    $self->linkSubmitBlastPair($conditionAnalysis, $goalAnalysis);
  }
  else {
    $self->createAllBlastRules();
  } 
  return 1;
}




##################################
#
# subroutines
#
##################################


sub createAllBlastRules
{
  my $self = shift;

  my $analysisList = $self->db->get_AnalysisAdaptor->fetch_all();

  my @submitList;
  my @blastList;
  foreach my $submitAnalysis (@{$analysisList}) {
    next unless($submitAnalysis->logic_name =~ /SubmitPep_(.*)/);
    my $blast_name = "blast_".$1;
    printf("found submit %s\n", $submitAnalysis->logic_name);
    push @submitList, $submitAnalysis;
    $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($submitAnalysis, $self->{'cr_analysis'});

    my $blastAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($blast_name);
    if($blastAnalysis) {
      push @blastList, $blastAnalysis;
      $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($blastAnalysis, $self->{'cr_analysis'});
    }
  }

  foreach my $submitAnalysis (@submitList) {
    foreach my $blastAnalysis (@blastList) {
      if (!$self->{'selfBlast'}) {
        my ($submit_id) = $submitAnalysis->logic_name =~ /SubmitPep_(.*)/;
        my ($blast_id) = $blastAnalysis->logic_name =~ /blast_(.*)/;
        next if ($submit_id eq $blast_id);
      }
      # If it uses BlastcomparaPepAcross, we only create one Blast job 1
      # job only across all the sps in 'species_set' in PAFCluster
      # instead of a job per sp. This is to avoid creating an
      # exponentially large ((n*n-1)/2) number of jobs that collapses
      # the analysis_job table.
      if ($blastAnalysis->module eq 'Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcross'
       || $blastAnalysis->module eq 'Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcrossReuse') {
        my ($submit_id) = $submitAnalysis->logic_name =~ /SubmitPep_(.*)/;
        my ($blast_id) = $blastAnalysis->logic_name =~ /blast_(.*)/;
        next unless ($submit_id eq $blast_id);
      }
      $self->linkSubmitBlastPair($submitAnalysis, $blastAnalysis);
    }
  }
}


sub linkSubmitBlastPair
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;

  printf("link %s => %s\n", $conditionAnalysis->logic_name, $goalAnalysis->logic_name);

  if($self->db->get_DataflowRuleAdaptor->create_rule($conditionAnalysis, $goalAnalysis)) {
    printf("reset_all_jobs_for_analysis %s\n", $conditionAnalysis->logic_name);
    $self->db->get_AnalysisJobAdaptor->reset_all_jobs_for_analysis_id($conditionAnalysis->dbID);
  }

}


1;
