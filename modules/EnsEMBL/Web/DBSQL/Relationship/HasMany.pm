package EnsEMBL::Web::DBSQL::Relationship::HasMany;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::Relationship;
our @ISA = qw(EnsEMBL::Web::DBSQL::Relationship);

{

my %LinkTable_of;
my %LinkedKey_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new((
                                from            => $params{table}, 
                                to              => $params{has_many},
                                option_columns  => $params{option_columns},
                                option_order    => $params{option_order},
                                type            => 'has many'
                               ));

  $LinkTable_of{$self}          = defined $params{linked_by} ? $params{linked_by} : "";
  $LinkedKey_of{$self}          = defined $params{linked_key} ? $params{linked_key} : "";
  return $self;
}

sub link_table {
  ### a
  my $self = shift;
  $LinkTable_of{$self} = shift if @_;
  return $LinkTable_of{$self};
}

sub linked_key {
  ### a
  my $self = shift;
  $LinkedKey_of{$self} = shift if @_;
  return $LinkedKey_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $LinkTable_of{$self};
  delete $LinkedKey_of{$self};
}
 
}

1;
