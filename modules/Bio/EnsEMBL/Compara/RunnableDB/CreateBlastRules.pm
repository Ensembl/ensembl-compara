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

sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  $self->{'selfBlast'} = 1;
  $self->{'phylumBlast'} = 0;
  if($self->analysis->parameters =~ /{/) {
    my $paramHash = eval($self->analysis->parameters);
    if($paramHash) {
      $self->{'phylumBlast'}=1 if($paramHash->{'phylumBlast'}==1);
      $self->{'selfBlast'}=0 if($paramHash->{'selfBlast'}==0);
      $self->{'no_homology_genome_db_ids'} = $paramHash->{'no_homology_genome_db_ids'}
        if($paramHash->{'no_homology_genome_db_ids'});
    }
  }
  
  #create a new Compara::DBAdaptor which points to the same database
  #as the Pipeline::DBAdaptor passed in ($self->db)
  #the -DBCONN options uses the dbname,user,pass,port,host,driver from the
  #variable DBConnection to create the new connection (in essence a copy)

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

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
    push @submitList, $submitAnalysis;
    $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($submitAnalysis, $self->{'buildHomology'});
  
    my $blastAnalysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($blast_name);
    if($blastAnalysis) {
      push @blastList, $blastAnalysis;
      $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($blastAnalysis, $self->{'buildHomology'});
    }
  }
  
  foreach my $submitAnalysis (@submitList) {
    foreach my $blastAnalysis (@blastList) {
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
