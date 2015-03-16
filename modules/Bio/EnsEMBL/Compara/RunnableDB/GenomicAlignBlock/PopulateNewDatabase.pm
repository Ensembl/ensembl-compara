=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase

=cut

=head1 SYNOPSIS


$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Runs the $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/populate_new_database.pl script, dealing with missing parameters

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  return 1;
}

sub run
{
  my $self = shift;

  my $cmd = $self->param('program');

  #must have master db defined
  unless ($self->param('master_db')) {
      return 1;
  }

  #Append arguments if defined
  $cmd .= " --master " . $self->param('master_db') if ($self->param('master_db'));
  $cmd .= " --new " . $self->param('pipeline_db') if ($self->param('pipeline_db'));
  $cmd .= " --MT_only " . $self->param('MT_only') if ($self->param('MT_only'));
  $cmd .= " --species " . $self->param('speciesList') if ($self->param('species_list'));
  $cmd .= " --mlss " . $self->param('mlss_id') if ($self->param('mlss_id'));
  $cmd .= " --reg-conf " . $self->param('reg_conf') if ($self->param('reg_conf'));
  $cmd .= " --collection " . $self->param('collection') if ($self->param('collection'));
  $cmd .= " --old " . $self->param('old_compara_db') if ($self->param('old_compara_db'));

  if($self->debug()) {
      warn qq{cmd = "$cmd"\n};
  }
  
  if(my $return_value = system($cmd)) {
      $return_value >>= 8;
      die "system( $cmd ) failed: $return_value";
  }
  return 1;
}

sub write_output
{
  my $self = shift;
  return 1;
}

1;
