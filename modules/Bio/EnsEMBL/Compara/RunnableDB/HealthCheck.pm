#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HealthCheck

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module is inteded to run automatic checks at the end of a pipeline (or at any other time)

=head1 OPTIONS

This module has been designed to run one test per analysis_job. All the options are specific to
the test iself and therefore you shouldn't set any parameters in the analysis table. Use the input_id
column of the analysis_job to set these values.

=head2 test

The name of the test to be run. See below for a list of tests

=head2 params

Parameters used by the test

=head1 TESTS

=head2 conservation_jobs

This test checks that there are one conservation analysis per alignment.

Parameters:

=over

=item logic_name

Logic name for the Conservation analysis. Default: Gerp

=item method_link_type

method_link_type for the multiple alignments. Default: PECAN

=back

=head1 EXAMPLES

=over

=item {test=>'conservation_jobs'}

=item {test=>'conservation_jobs', params=>{logic_name=>'Gerp2', method_link_type=>'MLAGAN'}}

=back

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

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub fetch_input {
  my ($self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  return 1;
}


=head2 run

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub run
{
  my $self = shift;

  if ($self->test() eq "conservation_jobs") {
    $self->_run_conservation_jobs_test($self->parameters());
  }

  return 1;
}


=head2 write_output

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub write_output {
  my ($self) = @_;

  return 1;
}


=head2 get_params

  Arg [1]     : (optional) string $parameters
  Example     : $self->get_params("{blah=>'foo'}");
  Description : Reads and parses a string representing a hash
                with parameters for this job.
  Returntype  :
  Exceptions  : none
  Caller      : fetch_input
  Status      : Stable

=cut

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if (defined($params->{'test'})) {
    $self->test($params->{'test'});
  }

  if (defined($params->{'params'})) {
    $self->parameters($params->{'params'});
  }

  return 1;
}


=head2 test

  Arg [1]     : (optional) string $test
  Example     : $object->test($test);
  Example     : $test = $object->test();
  Description : Getter/setter for the test attribute, i.e. the
                name of the test to be run
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub test {
  my $self = shift;
  if (@_) {
    $self->{_test} = shift;
  }
  return $self->{_test};
}

=head2 parameters

  Arg [1]     : (optional) string $parameters
  Example     : $object->parameters($parameters);
  Example     : $parameters = $object->parameters();
  Description : Getter/setter for the parameters attribute
  Returntype  : string representing a hashref
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub parameters {
  my $self = shift;
  if (@_) {
    $self->{_parameters} = shift;
  }
  return $self->{_parameters};
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

  my $logic_name = "Gerp";
  my $method_link_type = "PECAN";

  if ($parameters) {
    if (defined($parameters->{'logic_name'})) {
      $logic_name = $parameters->{'logic_name'};
    }
    if (defined($parameters->{'from_method_link_type'})) {
      $method_link_type = $parameters->{'from_method_link_type'};
    }
    if (defined($parameters->{'method_link_type'})) {
      $method_link_type = $parameters->{'method_link_type'};
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
  } elsif ($count1 == 0) {
    die("There are no analysis_jobs for $logic_name and no $method_link_type alignments!\n");
  }
}


1;
