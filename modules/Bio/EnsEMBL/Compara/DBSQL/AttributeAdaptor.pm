package Bio::EnsEMBL::Compara::DBSQL::AttributeAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub fetch_by_Member_Relation {
  my ($self, $member, $relation) = @_;

  my $sth;
  my @attributes;

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    my $sql = "SELECT * from family_member where family_id = ? AND member_id = ?";
    $sth = $self->prepare($sql);
    $sth->execute($relation->dbID, $member->dbID);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    my $sql = "SELECT * from domain_member where domain_id = ? AND member_id = ?";
    $sth = $self->prepare($sql);
    $sth->execute($relation->dbID, $member->dbID);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    my $sql = "SELECT * from homology_member where homology_id = ? AND member_id = ?";
    $sth = $self->prepare($sql);
    $sth->execute($relation->dbID, $member->dbID);
  }
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  while ($sth->fetch()) {
    my $attribute = new Bio::EnsEMBL::Compara::Attribute;
    foreach my $key (keys %column) {
      $attribute->$key($column{$key});
    }
    push @attributes, $attribute;
  }

  return \@attributes;
  # need to return a array list, because in the case of domain, a member can have more
  # than one attribute, repetition of the same domain in the protein...
  # not the case for Family and Homology
}

1;
