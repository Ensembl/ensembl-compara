#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateRules

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::CreateRules->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateRules;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  return 1;
}


sub run
{
  return 1;
}


sub write_output
{
  my $self = shift;

  my $input_hash = eval($self->input_id);
  $self->{'from_prefix'} = $input_hash->{'from'};
  $self->{'to_prefix'} = $input_hash->{'to'};

  $self->createBlastRules();
  return 1;
}




##################################
#
# subroutines
#
##################################

sub createBlastRules
{
  my $self = shift;

  my $dataflowRuleDBA = $self->db->get_DataflowRuleAdaptor;
  my $analysisList = $self->db->get_AnalysisAdaptor->fetch_all();

  my @fromList = ();

  foreach my $analysis (@{$analysisList}) {
    next unless($analysis->logic_name =~ /^$self->{'from_prefix'}/);
    push @fromList, $analysis;
    print("FROM: ", $analysis->logic_name,"\n");
  }

  foreach my $to_analysis (@{$analysisList}) {
    next unless($to_analysis->logic_name =~ /^$self->{'to_prefix'}/);
    next if($to_analysis->logic_name eq $self->{'to_prefix'});
    foreach my $from_analysis (@fromList) {
      print("  ",$from_analysis->logic_name," -> ", $to_analysis->logic_name, "\n");
      $dataflowRuleDBA->create_rule($from_analysis, $to_analysis);
    }
  }

  foreach my $from_analysis (@fromList) {
    my $stats = $from_analysis->stats;
    $stats->status('LOADING');
    $stats->update;
  }
}


1;
