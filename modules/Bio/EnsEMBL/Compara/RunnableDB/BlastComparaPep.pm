#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::BlastComparaPep->new ( 
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

package Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
                           -DBCONN => $self->db);
  $self->{'comparaDBA'}->disconnect_when_inactive(1);

  
  my $member_id  = $self->input_id;
  my $member     = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($member_id);
  print("member(".$member->dbID.") = '".$member->stable_id."'\n");
  $self->throw("No member in compara for member_id=$member_id") unless defined($member);

  
  my $bioseq     = $member->bioseq();
  $self->throw("Unable to make bioseq for member_id=$member_id") unless defined($bioseq);
  $self->query($bioseq);

  my ($thr, $thr_type, $options);
  my %p = $self->parameter_hash;

  if (defined $p{-threshold} && defined $p{-threshold_type}) {
      $thr      = $p{-threshold};
      $thr_type = $p{-threshold_type};
  }
  else {
      $thr_type = 'PVALUE';
      $thr      = 1e-10;
  }
  if (defined $p{options}) {
    $options = $p{options};
    # print("!!!found my options : $options\n");
  }
  else {
    $options = '';
  }


=head3
  my $stable_id  = $member->stable_id();
  my $logic_name = $self->analysis->logic_name();
  print("BlastComparaPep query='$stable_id'  anal='$logic_name'\n");
  my $seq_string = $member->sequence();
  print("  seq : $seq_string\n");
  my $options = $self->analysis->parameters;
  print("  option = '$options'\n");

  my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blast(-query          => $bioseq,
                                                             -database       => $self->analysis->db_file,
                                                             -threshold      => 1e-10,
                                                             -options        => "-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1",
                                                             -threshold_type => "PVALUE",
                                                             -program        => '/scratch/local/ensembl/bin/wublastp');
  $self->runnable($runnable);
=cut

  print("running with analysis '".$self->analysis->logic_name."'\n");
  my $runnable = Bio::EnsEMBL::Pipeline::Runnable::Blast->new(
                     -query          => $self->query,
                     -database       => $self->analysis->db_file,
                     -program        => $self->analysis->program_file,
                     -options        => $options,
                     -threshold      => $thr,
                     -threshold_type => $thr_type
                    );
  $runnable->add_regex($self->analysis->db_file, '^(\S+)\s*');
  $self->runnable($runnable);
  return 1;
}


sub run
{
  my $self = shift;
  #call superclasses run method
  print("ABOUT TO RUN\n");
  return $self->SUPER::run();
}


sub write_output {
  my( $self) = @_;

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object

  foreach my $feature ($self->output) {
    if($feature->isa('Bio::EnsEMBL::FeaturePair')) {
      $feature->analysis($self->analysis);
    }
  }

  $self->{'comparaDBA'}->disconnect_when_inactive(0);
  $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store($self->output);
}

1;
