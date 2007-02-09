package EnsEMBL::Web::DBSQL::SQL::Result;

use strict;
use warnings;

use Class::Std;

our @ISA = qq(EnsEMBL::Web::DBSQL::SQL);

{

my %Result :ATTR(:set<result> :get<result>);
my %SetParameters :ATTR(:set<set_parameters> :get<set_parameters>);
my %Action :ATTR(:set<action> :get<action>);
my %LastInsertedId :ATTR(:set<last_inserted_id> :get<last_inserted_id>);
my %Success :ATTR(:set<success> :get<success>);
my %ResultHash:ATTR(:set<result_hash> :get<result_hash>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  if (defined $args->{action}) {
    $self->set_action($args->{action});
  }
}

sub get_value {
  my ($self, $field) = @_;
  return $self->get_result_hash->{$field};
}

sub fields {
  my ($self) = @_;
  my @field_array = keys %{ $self->get_result_hash };
  return \@field_array;
}

}

1;
