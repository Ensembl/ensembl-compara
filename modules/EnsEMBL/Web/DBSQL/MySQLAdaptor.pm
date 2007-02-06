package EnsEMBL::Web::DBSQL::MySQLAdaptor;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data;
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

sub create {
  my ($self, $data) = @_;
  warn "CREATING new data object";
}

sub populate {
  my ($self, $select_hash);
  return $self->get_handle->selectall_hashref(@_);
}

sub update {
  my ($self, $data) = @_;
  warn "UPDATING data object with ID " . $data->id;
  my $data_hash = {};
  my $has_data = 0;
  foreach my $data_field (@{ $data->get_fields }) {
    $has_data = 1;
    $data_hash->{ $data_field->get_name } = $data->get_value( $data_field->get_name );
  }
  my $sql = 'UPDATE ' . $self->get_table . " ";
  $sql .= "SET ";
  foreach my $data_field (@{ $data->get_queriable_fields }) {
    if (defined $data->get_value( $data_field->get_name)) {
      $sql .= $data_field->get_name . " = '" . $data->get_value( $data_field->get_name ) . "', ";
    }
  }
  if ($has_data) {
    $sql .= "data = '" . $self->dump_data($data_hash) . "'";
  }
  $sql =~ s/, $/ /;
  $sql .= " WHERE id='" . $data->id . "'";
  $sql .= ";";
  $self->get_handle->prepare($sql);
  return $self->get_handle->execute;
}

sub destroy {
  my ($self, $data) = @_;
  return 1;
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

1;
