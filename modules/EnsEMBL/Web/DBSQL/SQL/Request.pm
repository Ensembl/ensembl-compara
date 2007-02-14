package EnsEMBL::Web::DBSQL::SQL::Request;

use strict;
use warnings;

use Class::Std;

our @ISA = qq(EnsEMBL::Web::DBSQL::SQL);

{

my %Where :ATTR(:set<where_attributes> :get<where_attributes>);
my %Action :ATTR(:set<action> :get<action>);
my %Table :ATTR(:set<table> :get<table>);
my %Index :ATTR(:set<index_by> :get<index_by>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_table("<table>");
}

sub get_sql {
  my ($self) = @_;
  my $sql = "";
  if ($self->get_action eq 'select') {
    $sql = "SELECT * FROM " . $self->get_table;
  }
  if ($self->get_where) {
    $sql .= " WHERE " . $self->get_where;
  }
  $sql .= ';';
  return $sql; 
}

sub add_where {
  my ($self, $key, $value, $operator) = @_;
  unless (defined $self->get_where_attributes) { 
    $self->set_where_attributes([]);
  }
  push @{ $self->get_where_attributes }, { field => $key, value => $value, operator => $operator };
}

sub get_where {
  my ($self) = @_;
  my $sql = "";
  if ($self->get_where_attributes) {
    foreach my $where (@{ $self->get_where_attributes }) {
      my $operator = $where->{operator} ? $where->{operator} : '=';
      $sql .= $where->{field} . " $operator '" . $where->{value} . "' and ";
    }
  }
  $sql =~ s/ and $/ /;
  return $sql;
}

}

1;
