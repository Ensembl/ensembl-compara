#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HealthCheck

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module is inteded to run automatic checks at the end of a pipeline (or at any other time)

=head1 OPTIONS

=head2 option

=head1 CONTACT

Javier Herrero <jherrero@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HealthCheck;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  ## Intialise test hash
  $self->{_test} = {};

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  return 1;
}

sub run
{
  my $self = shift;

  if ($self->test("conservation_jobs")) {
    $self->_run_conservation_jobs_test($self->test("conservation_jobs"));
  }

  return 1;
}

sub write_output {
  my ($self) = @_;

  return 1;
}


=head2 get_params

=cut

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if (defined($params->{'conservation_jobs'})) {
    $self->test("conservation_jobs", $params->{'conservation_jobs'});
  }

  return 1;
}


=head2 test

=cut

sub test {
  my ($self, $test_name, $test_parameters) = @_;

  if ($test_name and $test_parameters) {
    $self->{_test}->{$test_name} = $test_parameters;
  }

  return $self->{_test}->{$test_name};
}

=head2 _run_conservation_jobs_test

  Arg[1]      : string representign a true value or a hashref of options.
                Possible options are:
                  logic_name => Logic name for the Conservation Score
                      analysis. Default: Gerp
                  method_link_type => corresponds to the multiple
                      alignments. Default: PECAN
  Example     : $self->run_conservation_jobs_test(1);
  Example     : $self->run_conservation_jobs_test("{logic_name=>'GERP2',
                    method_link_type=>'MLAGAN'}");
  Description : Tests whether there is one conservation job per multiple
                alignment or not. This test only look at the number of jobs.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_conservation_jobs_test {
  my ($self, $parameters) = @_;

  $parameters = 1 if (!$parameters);

  my $params = eval($parameters);
  return unless($params);

  my $logic_name = "Gerp";
  my $method_link_type = "PECAN";

  if (UNIVERSAL::isa($params, "HASH")) {
    if (defined($params->{'logic_name'})) {
      $logic_name = $params->{'logic_name'};
    }
    if (defined($params->{'from_method_link_type'})) {
      $method_link_type = $params->{'from_method_link_type'};
    }
    if (defined($params->{'method_link_type'})) {
      $method_link_type = $params->{'method_link_type'};
    }
  }

  ## Get the number of analysis_jobs for Gerp (or any other specified analysis)
  my $count1 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM analysis LEFT JOIN analysis_job ".
      " USING (analysis_id) WHERE logic_name = \"$logic_name\"");

  ## Get the number of Pecan (or any other specified method_link_type) alignments
  my $count2 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM method_link".
      " LEFT JOIN method_link_species_set USING (method_link_id)".
      " LEFT JOIN genomic_align_block USING (method_link_species_set_id)".
      " WHERE method_link.type = \"$method_link_type\"");

  if ($count1 != $count2) {
    die("There are $count1 analysis_jobs for $logic_name while there are $count2 $method_link_type alignments!\n");
  }
}


1;
