#
# You may distribute this module under the same terms as perl itself
#

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter

=head1 DESCRIPTION

This class will write the results of the given projections to a 
database given at construction.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: dev@ensembl.org

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw(Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter);

=head2 new()

  Arg[-dba] : required; Assumed to be a DBA which we can write to
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $dba, ) = rearrange( [qw(dba )], @args );

  assert_ref( $dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
  confess(
'The attribute dba must be specified during construction or provide a builder subroutine'
  ) if !defined $dba;
  $self->{dba} = $dba if defined $dba;

  return $self;
}

=head2 dba()

  Description : Getter. Should be a write enabled connection

=cut

sub dba {
  my ($self) = @_;
  return $self->{dba};
}

=head2 write_projection()

Re-assigns the attacted DBEntry from the list of projections to the
core database which was given to this object during construction. This method
also stores the newly assigned DBEntry.

=cut

sub write_projection {
  my ($self, $p) = @_;
  my $db_entry_a = $self->dba()->get_DBEntryAdaptor();  
  my $entry = $self->_process_entry($p);
  my $translation = $p->to()->get_Translation(); 
  $translation->add_DBEntry($entry);
  $db_entry_a->store($entry, $translation->dbID(), 'Translation');
  return;
}

=head2 _process_entry()

Performs processing which at the moment is concerned with 
processing the Entry if it is an OntologyXref

All entries are setup with a linkage type of IEA, info type of PROJECTION
and a text description showing what species the linkage was from and
the stable ID of the source object.

=cut

sub _process_entry {
  my ($self, $p) = @_;
  my $entry = $p->entry();
  return $entry unless $entry->isa('Bio::EnsEMBL::OntologyXref');
  
  my $from_species = $p->from()->genome_db()->name();
  my $from = $p->from()->stable_id();
  $entry->flush_linkage_types();
  $entry->add_linkage_type("IEA");
  my $txt = "from $from_species translation $from";
  $entry->info_type("PROJECTION");
  $entry->info_text($txt);
  return $entry;
}

1;
