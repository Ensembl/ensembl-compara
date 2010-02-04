package EnsEMBL::Web::DBSQL::MySQLAdaptor;

use strict;
## N.B. Must turn off warnings in this module, otherwise children 
## of this class will not compile!
#use warnings;

use EnsEMBL::Web::SpeciesDefs;
use base qw(Class::DBI::Sweet);

## Setup sonfig on startup time
__PACKAGE__->mk_classdata(species_defs => EnsEMBL::Web::SpeciesDefs->new);

##
## Patch for accessor name without '_id' 
##
sub accessor_name_for {
  my ($class, $column) = @_;

  return $column
  unless my ($accessor_name_for_obj) = $column =~ /^(.+)_id$/;

  # make original accessor return object ID (force call to stringify) 
  no strict 'refs';
  *{"$class\::$column"} = sub { '' . &{"$class\::$accessor_name_for_obj"} };
  return $accessor_name_for_obj;
}

sub has_a {
  my $class = shift; 
  my $accessor = shift;

  # suffix accessor name with '_id' to get real column name
  $accessor .= '_id'
    if $class->find_column($accessor . '_id');

  return $class->SUPER::has_a($accessor => @_); 
}
## /Patch

## FIX for mutator name, helps when mk_accessor is used
sub mutator_name_for {
  my ($class, $column) = @_;
  if ($class->can('mutator_name')) { 
    #warn "Use of 'mutator_name' is deprecated. Use 'mutator_name_for' instead\n";
    return $class->mutator_name($column) 
  }

  if (ref $column) {
    return $column->mutator if ref $column;
  } else {
    return $column;
  }
}

1;
__END__

=head1 NAME

EnsEMBL::Web::DBSQL::MySQL - implements simple database abstraction

=head1 SYNOPSIS

=head1 DESCRIPTION

This module implements simple database abstraction. It inherited from Class::DBI module from cpan.
Refer to cpan for more details.

=cut

