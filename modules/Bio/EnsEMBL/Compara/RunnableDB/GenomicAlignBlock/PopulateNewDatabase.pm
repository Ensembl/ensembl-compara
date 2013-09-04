=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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
