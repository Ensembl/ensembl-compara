package EnsEMBL::Web::DBSQL::Relationship::Lookup;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::Relationship;
our @ISA = qw(EnsEMBL::Web::DBSQL::Relationship);

{

my %ForeignKey_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new((
                                to              => $params{to}, 
                                from            => $params{from},
                                option_columns  => $params{option_columns},
                                option_order    => $params{option_order},
                                type            => 'lookup',
                               ));
  $ForeignKey_of{$self}   = defined $params{foreign_key} ? $params{foreign_key} : "";
  return $self;
}

sub foreign_key {
  ### a
  my $self = shift;
  $ForeignKey_of{$self} = shift if @_;
  return $ForeignKey_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $ForeignKey_of{$self};
}
 
}

1;
