#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::StoreSeqExonBounded

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $store_seq_exon_bounded = Bio::EnsEMBL::Compara::RunnableDB::StoreSeqExonBounded->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$store_seq_exon_bounded->fetch_input(); #reads from DB
$store_seq_exon_bounded->run();
$store_seq_exon_bounded->output();
$store_seq_exon_bounded->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::StoreSeqExonBounded;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Hive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  $self->{memberDBA} = $self->compara_dba->get_MemberAdaptor;

  # Get the needed adaptors here
  # $self->{silly_adaptor} = $self->compara_dba->get_SillyAdaptor;

  $self->get_params($self->parameters);
  my $input_id = $self->input_id;
  $DB::single=1;1;
  if ($input_id =~ /ids/) { # it's the job_array-based input_id
    my $ids = eval($input_id);
    my @members;
    foreach my $id (@{$ids->{ids}}) {
      my $member = $self->{memberDBA}->fetch_by_dbID($id);
      push @members, $member;
    }
    $self->{members} = \@members;
  } else {
    throw("Incorrect input_id. Should be array-based like 'ids'=>[1,2,3,4,5]\n");
  }

  # For long parameters, look at analysis_data
  if($self->{blast_template_analysis_data_id}) {
    my $analysis_data_id = $self->{blast_template_analysis_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }
  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[param1 param2 param3 analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_store_seq_exon_bounded;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

}


##########################################
#
# internal methods
#
##########################################

sub run_store_seq_exon_bounded {
  my $self = shift;

  foreach my $member (@{$self->{members}}) {
    my $sequence_exon_bounded = $member->sequence_exon_bounded;
    my $member_id = $member->dbID;
    print STDERR "sequence_exon_bounded $member_id\n" if ($self->debug);
    $self->store_seq_exon_bounded($member_id,$sequence_exon_bounded);
  }

  return 1;
}

sub store_seq_exon_bounded {
  my ($self, $member_id, $sequence_exon_bounded) = @_;
  my $seqID;

  return 0 unless($sequence_exon_bounded && $member_id);

  my $sth = $self->dbc->prepare("SELECT sequence_exon_bounded_id FROM sequence_exon_bounded WHERE member_id = ?");
  $sth->execute($member_id);
  ($seqID) = $sth->fetchrow_array();
  $sth->finish;

  if(!$seqID) {
    my $length = length($sequence_exon_bounded);

    my $sth2 = $self->dbc->prepare("INSERT INTO sequence_exon_bounded (member_id, sequence_exon_bounded, length) VALUES (?,?,?)");
    $sth2->execute($member_id, $sequence_exon_bounded, $length);
    $seqID = $sth2->{'mysql_insertid'};
    $sth2->finish;
  }

  return $seqID;
}

1;
