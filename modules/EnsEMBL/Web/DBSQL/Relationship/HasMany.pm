package EnsEMBL::Web::DBSQL::Relationship::HasMany;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::Relationship;
our @ISA = qw(EnsEMBL::Web::DBSQL::Relationship);

{

my %LinkTable_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new((
                                 from => $params{table}, 
                                 to   => $params{has_many},
                                 type => 'has many'
                               ));

  $LinkTable_of{$self}          = defined $params{linked_by} ? $params{linked_by} : "";
  return $self;
}

sub link_table {
  ### a
  my $self = shift;
  $LinkTable_of{$self} = shift if @_;
  return $LinkTable_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $LinkTable_of{$self};
}
 
}

1;
