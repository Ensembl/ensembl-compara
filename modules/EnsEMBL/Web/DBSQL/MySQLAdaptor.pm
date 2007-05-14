package EnsEMBL::Web::DBSQL::MySQLAdaptor;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::SQL::Result;
use EnsEMBL::Web::DBSQL::SQL::Request;
use EnsEMBL::Web::Tools::DBSQL::TableName;
use Data::Dumper;

{

my %Handle :ATTR(:set<handle> :get<handle>);
my %Table :ATTR(:set<table_name> :get<table_name>);

}

sub BUILD {
  my ($self, $ident, $args) = @_;

  my $adaptor = $args->{adaptor} ? $args->{adaptor} : 'dbAdaptor';
  my $handle;

  if ($adaptor eq 'dbAdaptor' || $adaptor eq 'websiteAdaptor') {
  
    if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
      eval {
        $self->set_handle($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->$adaptor());
      };
    } 
    else {
      warn( "NO CACHED DATABASE HANDLE DEFINED" );
      $self->set_handle(undef);
    }
  }
  else {
    ## Allow non-cached db handles, eg Healthchecks
    eval {
      $self->set_handle($adaptor);
    };
  }

  if($self->get_handle) {
    #warn( "New MySQLAdaptor with DB handle: " . $self->get_handle );
    $self->set_table($args->{table});
  } 
  else {
    warn( "Unable to connect to database: $DBI::errstr" );
    $self->set_handle(undef);
  }
}

sub set_table {
  my ($self, $name) = @_;
  return $self->set_table_name($name);
}

sub get_table {
  my $self = shift;
  my $name = $self->get_table_name;
  return $self->parse_table_name($name);
}

sub parse_table_name {
  my ($self, $string) = @_;
  return EnsEMBL::Web::Tools::DBSQL::TableName::parse_table_name($string);
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
  my $data_field;

  if ($data->get_fields) {
    foreach $data_field (@{ $data->get_fields }) {
      $has_data = 1;
      $data_hash->{ $data_field->get_name } = $data->get_value( $data_field->get_name );
    }
  }
  foreach $data_field (@{ $data->get_queriable_fields }) {
    if (defined $data->get_value( $data_field->get_name)) {
      if ($self->is_allowed_in_set_clause($data_field->get_name)) {
        $sql .= $self->map_back($data_field->get_name) . " = '" . $data->get_value( $data_field->get_name ) . "', ";
      }
    }
  }
  if ($has_data) {
    $sql .= "data = '" . $self->dump_data($data_hash) . "'";
  }
  if (defined $data->get_belongs_to) {
  }
  $sql =~ s/, $/ /;
  return $sql;
}

sub map_back {
  my ($self, $field) = @_;
  if ($field eq 'group_id') {
    $field = 'webgroup_id';
  }
  return $field;
}

sub is_allowed_in_set_clause {
  my ($self, $field) = @_;
  if ($field eq 'id') {
    return 0;
  }
  return 1;
}

sub create {
  my ($self, $data) = @_;
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  my $sql = 'INSERT INTO ' . $self->get_table . ' SET '; 
  $sql .= $self->set_clause($data);  
  warn "CREATE: " . $sql;
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
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  $result->set_action('update');
  my $key = EnsEMBL::Web::Tools::DBSQL::TableName::parse_primary_key($data->get_primary_key);
  my $sql = 'UPDATE ' . $self->get_table . " ";
  $sql .= "SET " . $self->set_clause($data);
  $sql .= " WHERE " . $key . "='" . $data->id . "'";
  $sql .= ";";
  warn "UPDATE: " . $sql;
  $self->get_handle->prepare($sql);
  if ($self->get_handle->do($sql)) {
    $result->set_success(1);
  }
  return $result;
}

sub destroy {
  my ($self, $request) = @_;
  #warn "DESTROYING with $request";
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  $result->set_action('destroy');
  my $sql = $self->template($request->get_sql);
  #warn "SQL: " . $sql;
  $self->get_handle->prepare($sql);
  if ($self->get_handle->do($sql)) {
    $result->set_success(1);
    #warn "SUCCESS";
  }
  return $result;
}

sub find {
  my ($self, $data) = @_;
  #warn "FIND";
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  $result->set_action('find');
  my $key = EnsEMBL::Web::Tools::DBSQL::TableName::parse_primary_key($data->get_primary_key);
  my $sql = "SELECT * FROM " . $self->get_table . " WHERE " . $key . "='" . $data->id . "';";
  warn $sql;
  my $hashref = $self->get_handle->selectall_hashref($sql, $key);
  $result->set_result_hash($hashref->{$data->id});
  return $result;
}

sub find_many {
  my ($self, $request) = @_;
  #warn "FIND MANY";
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new();
  $result->set_action('find');
  my $sql = $self->template($request->get_sql);
  #warn "MANY: " . $sql;
  my $index_by = $self->parse_table_name($request->get_index_by); 
  #warn "INDEX: " . $index_by;
  my $hashref = $self->get_handle->selectall_hashref($sql, $index_by);
  #warn "OK";
  #warn "\n";
  $result->set_result_hash($hashref);
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

sub template {
  my ($self, $template) = @_;
  while ($template =~ m/<(.*)>/g) {
    my $get_accessor = "get_" . $1;
    my $get = $self->$get_accessor;
    $template =~ s/<$1>/$get/g;
  }
  return $self->parse_table_name($template);
}


1;
