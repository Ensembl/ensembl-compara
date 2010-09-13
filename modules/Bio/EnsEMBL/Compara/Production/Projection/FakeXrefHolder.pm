#
# You may distribute this module under the same terms as perl itself
#

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder

=head1 DESCRIPTION

This class is used as a way of getting database entries from a core
database quickly by not having to go through core objects and being able
to do the join using stable IDs alone. At the moment it will return XRefs
linked to the peptide if given a gene or peptide member.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: dev@ensembl.org

=cut

package Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::OntologyXref;

=head2 new()

  Arg[-dbentries] : required; ArrayRef of entries of type DBEntry
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $dbentries, ) = rearrange( [qw(dbentries )], @args );

  assert_ref( $dbentries, 'ARRAY' );
  confess('The attribute dbentries must be specified during construction or provide a builder subroutine') if !defined $dbentries;
  $self->{dbentries} = $dbentries;

  return $self;
}

=head2 dbentries()

  Description : Getter. ArrayRef of entries of type DBEntry

=cut

sub dbentries {
  my ($self) = @_;
  return $self->{dbentries};
}

=head2 get_all_DBEntries()

  Arg[1]      : String; entry type where the value given is a dbname
  Description : Returns all DBEntries or just the DBEntries matching the given
                db name
  Returntype  : ArrayRef of the entries 

=cut

sub get_all_DBEntries {
  my ($self, $entry_type) = @_;
  
  return $self->dbentries() unless $entry_type;
  
  my @entries;
  foreach my $entry (@{$self->dbentries()}) {
    if($entry->dbname() eq $entry_type) {
      push(@entries, $entry);
    }
  }
  
  return \@entries;
}

### Factory

=head2 build_peptide_dbentries_from_member()

  Arg[1]      : Bio::EnsEMBL::Compara::Member; The member to search by
  Arg[2]      : String; The dbname to look for. Supports like
  Description : Searches for entries linked to the given Member. If given
                a gene member it will look for the cannonical links and if
                given a peptide member it assumes this is the correct 
                identifier to use.
  Returntype  : ArrayRef of DBEntry objects.

=cut

sub build_peptide_dbentries_from_Member {
  my ($class, $member, $dbname) = @_;
    
  my $peptide_member = ($member->source_name() eq 'ENSEMBLGENE') ? $member->get_canonical_peptide_Member() : $member;
  my $dbc = $peptide_member->genome_db()->db_adaptor()->dbc();
  my $t = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $dbc);
  
  my $sql = q{SELECT x.xref_id, x.external_db_id, x.dbprimary_acc, x.display_label, x.version, x.description, x.info_type, x.info_text, oxr.linkage_type, ed.db_name, ed.type, ed.db_release
FROM translation_stable_id tsi
JOIN object_xref ox ON (tsi.translation_id = ox.ensembl_id AND ox.ensembl_object_type = 'Translation')
JOIN xref x USING (xref_id)
JOIN external_db ed on (x.external_db_id = ed.external_db_id)
LEFT JOIN ontology_xref oxr ON (ox.object_xref_id = oxr.object_xref_id)
WHERE tsi.stable_id =?};
  
  my $params = [$peptide_member->stable_id()];
  
  if($dbname) {
    $sql .= ' AND ed.db_name like ?';
    push(@{$params}, $dbname);
  }
  
  my $entries = $t->execute(-SQL => $sql, -CALLBACK => sub {
    my ($row) = @_;
    my ($xref_id, $external_db_id, $primary_ac, $display_label, $version, $description, $info_type, $info_text, $linkage, $dbname, $type, $db_release) = @{$row};
    
    my $hash_to_bless = {
      dbID => $xref_id,
      primary_id => $primary_ac,
      display_id => $display_label,
      version => $version,
      info_type => $info_type,
      info_text => $info_text,
      type => $type,
      dbname => $dbname,
      description => $description,
      release => $db_release
    };
    
    my $xref;
    
    #It was an OntologyXref if we had this
    if($linkage) {
      $hash_to_bless->{linkage_types} = [[$linkage]];
      $xref = Bio::EnsEMBL::OntologyXref->new_fast($hash_to_bless);
    } else {
      $xref = Bio::EnsEMBL::DBEntry->new_fast($hash_to_bless);
    }
    return $xref;
  }, -PARAMS => $params);
  
  return $class->new(-DBENTRIES => $entries);
}

1;