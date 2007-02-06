package EnsEMBL::Web::DBSQL::MySQLAdaptor;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::SQL::Result;
use Data::Dumper;

{

my %Handle :ATTR(:set<handle> :get<handle>);
my %Table :ATTR(:set<table> :get<table>);

}

sub BUILD {
  my ($self, $ident, $args) = @_;
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    eval {
      $self->set_handle($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->dbAdaptor());
    };
    unless($self->get_handle) {
       warn( "Unable to connect to database: $DBI::errstr" );
       $self->set_handle(undef);
    } else {
       warn( "New MySQLAdaptor with DB handle: " . $self->get_handle );
       $self->set_table($args->{table});
    }
  } else {
    warn( "NO DB USER DATABASE DEFINED" );
    $self->set_handle(undef);
  }
}

sub save {
  my ($self, $data) = @_;
  if ($data->has_id) {
    return $self->update($data);  
  } else {
    return $self->create($data);
  } 
}

sub set_clause {
  my ($self, $data) = @_;
  my $data_hash = {};
  my $has_data = 0;
  my $sql = "";
  foreach my $data_field (@{ $data->get_fields }) {
    $has_data = 1;
    $data_hash->{ $data_field->get_name } = $data->get_value( $data_field->get_name );
  }
  foreach my $data_field (@{ $data->get_queriable_fields }) {
    if (defined $data->get_value( $data_field->get_name)) {
      $sql .= $data_field->get_name . " = '" . $data->get_value( $data_field->get_name ) . "', ";
    }
  }
  if ($has_data) {
    $sql .= "data = '" . $self->dump_data($data_hash) . "'";
  }
  $sql =~ s/, $/ /;
  return $sql;
}

sub create {
  my ($self, $data) = @_;
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  my $sql = 'INSERT INTO ' . $self->get_table . ' SET '; 
  $sql .= $self->set_clause($data);  
  $self->get_handle->prepare($sql);
  $result->set_action('create');
  if ($self->get_handle->do($sql)) {
    $result->set_last_inserted_id($self->last_inserted_id);
    $result->set_success(1);
  }
  return $result;
}

sub update {
  my ($self, $data) = @_;
  warn "UPDATING data object with ID " . $data->id;
  my $sql = 'UPDATE ' . $self->get_table . " ";
  $sql .= "SET " . $self->set_clause($data);
  $sql .= " WHERE id='" . $data->id . "'";
  $sql .= ";";
  $self->get_handle->prepare($sql);
  return $self->get_handle->execute;
}

sub destroy {
  my ($self, $data) = @_;
  return 1;
}

sub find {
  my ($self, $data) = @_;
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  $result->set_action('find');
  my $sql = "SELECT * FROM " . $self->get_table . " WHERE " . $data->get_primary_key . "='" . $data->id . "';";
  warn $sql;
  my $hashref = $self->get_handle->selectall_hashref($sql, $data->get_primary_key);
  $result->set_result_hash($hashref->{$data->id});
  return $result;
}

sub dump_data {
  my ($self, $data) = @_;
  my $temp_fields = {};
  foreach my $key (keys %{ $data }) {
    $temp_fields->{$key} = $data->{$key};
    $temp_fields->{$key} =~ s/'/\\'/g;
  }
  my $dumper = Data::Dumper->new([$temp_fields]);
  $dumper->Indent(0);
  my $dump = $dumper->Dump();
  $dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}

sub last_inserted_id {
  my ($self) = @_;
  my $sql = "SELECT LAST_INSERT_ID()";
  my $T = $self->get_handle->selectall_arrayref($sql);
  return '' unless $T;
  my @A = @{$T->[0]}[0];
  my $result = $A[0];
  return $result;
}


1;
