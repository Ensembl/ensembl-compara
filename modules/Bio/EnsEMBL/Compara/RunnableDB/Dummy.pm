#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Dummy

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::Dummy->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object is used as a place holder in the hive system.
It does nothing, but is needed so that a Worker can grab
a job, pass the input through to output, and create the
next layer of jobs in the system.

=cut

=head1 CONTACT

jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Dummy;

use strict;

use Bio::EnsEMBL::Pipeline::RunnableDB;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 batch_size
  Title   :   batch_size
  Usage   :   $value = $self->batch_size;
  Description: Defines the number of jobs the RunnableDB subclasses should run in batch
               before querying the database for the next job batch.  Used by the
               Hive system to manage the number of workers needed to complete a
               particular job type.
  Returntype : integer scalar
=cut
sub batch_size { return 7000; }

=head2 carrying_capacity
  Title   :   carrying_capacity
  Usage   :   $value = $self->carrying_capacity;
  Description: Defines the total number of Workers of this RunnableDB for a particular
               analysis_id that can be created in the hive.  Used by Queen to manage
               creation of Workers.
  Returntype : integer scalar
=cut
sub carrying_capacity { return 1; }


##############################################################
#
# override inherited fetch_input, run, write_output methods
# so that nothing is done
#
##############################################################

sub fetch_input {
  my $self = shift;
  return 1;
}

sub run
{
  my $self = shift;
  #call superclasses run method
  return $self->SUPER::run();
}

sub write_output {
  my $self = shift;
  return 1;
}

1;
