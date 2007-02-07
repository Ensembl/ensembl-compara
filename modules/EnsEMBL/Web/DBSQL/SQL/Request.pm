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
    $sql = "SELECT * FROM " . $self->get_table . " WHERE " . $self->get_where . ";";
  }
  return $sql; 
}

sub add_where {
  my ($self, $key, $value) = @_;
  unless (defined $self->get_where_attributes) { 
    $self->set_where_attributes([]);
  }
  push @{ $self->get_where_attributes }, { field => $key, value => $value };
}

sub get_where {
  my ($self) = @_;
  my $sql = "";
  foreach my $where (@{ $self->get_where_attributes }) {
    $sql .= $where->{field} . " = '" . $where->{value} . "' and ";
  }
  $sql =~ s/ and $/ /;
  return $sql;
}

}

1;
