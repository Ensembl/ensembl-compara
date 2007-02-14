package EnsEMBL::Web::DBSQL::StructureDef;

### Object to encapsulate information about the MySQL structure of a database record.
### Note that this object does *not* contain any data (see Interface::InterfaceDef)

use strict;
use warnings;
use EnsEMBL::Web::DBSQL::ColumnDef;

{

my %DataAdaptor_of;
my %UserAdaptor_of;
my %Columns_of;
my %PrimaryKey_of;
my %Relationships_of;
my %Where_of;
my %SaveMethod_of;
my %DeleteMethod_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $DataAdaptor_of{$self}    = defined $params{data_adaptor} ? $params{data_adaptor} : [];
  $UserAdaptor_of{$self}    = defined $params{user_adaptor} ? $params{user_adaptor} : [];
  $Columns_of{$self}        = defined $params{columns} ? $params{columns} : {};
  $PrimaryKey_of{$self}     = defined $params{primary_key} ? $params{primary_key} : undef;
  $Relationships_of{$self}  = defined $params{relationships} ? $params{relationships} : [];
  $Where_of{$self}          = defined $params{where} ? $params{where} : {};
  $SaveMethod_of{$self}     = defined $params{save_method} ? $params{save_method} : undef;
  $DeleteMethod_of{$self}   = defined $params{delete_method} ? $params{delete_method} : undef;
  return $self;
}

sub data_adaptor {
  ### a
  my $self = shift;
  $DataAdaptor_of{$self} = shift if @_;
  return $DataAdaptor_of{$self};
}

sub user_adaptor {
  ### a
  my $self = shift;
  $UserAdaptor_of{$self} = shift if @_;
  return $UserAdaptor_of{$self};
}

sub columns {
  ### a
  ### instantiates an EnsEMBL::Web::DBSQL::ColumnDef object for each column
  ### in the database table and adds it to a hashref
  ### NB We use a hash, not an array, to make the data easier to access via column name
  my $self = shift;
  if (@_ && ref($_[0]) eq 'ARRAY') {
    my $columns = {};
    my $count = 0;
    foreach my $field (@{$_[0]}) {
      $columns->{$field->{'Field'}} = EnsEMBL::Web::DBSQL::ColumnDef->new({      
          'type'    => $field->{'Type'},
          'null'    => $field->{'Null'},
          'key'     => $field->{'Key'},
          'default' => $field->{'Default'},
          'extra'   => $field->{'Extra'},
          'index'   => $count
        });
      $count++;
    }
    $Columns_of{$self} = $columns;
  }
  return $Columns_of{$self};
}

sub column {
  ### a
  my ($self, $name, $attribs) = @_;
  if ($name) {
    my $columns = $Columns_of{$self};
    if ($attribs) {
      $columns->{$name} = EnsEMBL::Web::DBSQL::ColumnDef->new($attribs);
      $Columns_of{$self} = $columns;
    }
    return $columns->{$name};
  }
  return undef;
}

sub primary_key {
  ### a
  my $self = shift;
  $PrimaryKey_of{$self} = shift if @_;
  return $PrimaryKey_of{$self};
}

sub relationships {
  ### a
  my $self = shift;
  $Relationships_of{$self} = shift if @_;
  return $Relationships_of{$self};
}

sub where {
  ### a
  my $self = shift;
  $Where_of{$self} = shift if @_;
  return $Where_of{$self};
}

sub save_method {
  ### a
  ### Sets/gets the save method for this type of record
  ### If not set, defaults to 'save_[table_name]' or just 'save'
  my $self = shift;
  $SaveMethod_of{$self} = shift if @_;
  if ($SaveMethod_of{$self}) {
    return $SaveMethod_of{$self};
  }
  else { ## try to guess the method name!
    my $table = $self->data_adaptor->table;
    if ($table) {
      return 'save_'.$table;
    }
    else {
      return 'save';
    }
  }
}

sub delete_method {
  ### a
  ### Sets/gets the delete method for this type of record
  ### If not set, defaults to 'delete_[table_name]' or just 'delete'
  my $self = shift;
  $DeleteMethod_of{$self} = shift if @_;
  if ($DeleteMethod_of{$self}) {
    return $DeleteMethod_of{$self};
  }
  else { ## try to guess the method name!
    my $table = $self->data_adaptor->table;
    if ($table) {
      return 'delete_'.$table;
    }
    else {
      return 'delete';
    }
  }
}


#---------------------------------------------------------------------------------------

sub adaptors {
  my ($self, $adaptors) = @_;
  if ($adaptors && ref($adaptors) eq 'ARRAY') {
    $self->data_adaptor($adaptors->[0]);
    $self->user_adaptor($adaptors->[1]);
  }
  return [$self->data_adaptor, $self->user_adaptor];
}

sub add_relationship {
  ### Adds a relationship to the data structure
  my ($self, $relationship) = @_;
  push @{ $self->relationships }, $relationship;
}

sub discover {
  my ($self, $table) = @_;
  if ($table) {
    return $self->data_adaptor->discover($table);
  } else {
    $self->columns($self->data_adaptor->discover);
  }

  ## Auto-set primary key and user names
  my %columns = %{$self->columns};
  my $tracking = 0;
  my @names;
  foreach my $name (keys %columns) {
    ## history tracking
    if ($name =~ /^created_|^modified_/) {
      $tracking = 1;
      push @names, $name;
    } 
    ## primary key
    my $column = $columns{$name};
    if ($column->key eq 'PRI') {
      $self->primary_key($name);
    }
  }
  if ($tracking) {
    ## Add in standard placeholder columns for user names
    $self->column('created_name', {
              'type' => 'varchar(255)',
              'null'    => '',
              'key'     => '',
              'default' => '',
              'extra'   => '',
            });
    $self->column('modified_name', {
              'type' => 'varchar(255)',
              'null'    => '',
              'key'     => '',
              'default' => '',
              'extra'   => '',
            });
  }

  ## check for one-to-many relationships
  my $relationships = $self->relationships;
  foreach my $r (@$relationships) {
    if ($r->type eq 'has many') {
      my $other_table = $r->to;
      my $extras = $self->data_adaptor->discover($other_table);
      foreach my $field (@$extras) {
        if ($field->{'Key'} eq 'PRI') {
          $self->column($field->{'Field'}, {'type' => $field->{'Type'}});
          $r->linked_key($field->{'Field'});
        }
      }
    }
  }

  return $self->columns;
}


sub DESTROY {
  my $self = shift;
  delete $DataAdaptor_of{$self};
  delete $UserAdaptor_of{$self};
  delete $Columns_of{$self};
  delete $PrimaryKey_of{$self};
  delete $Relationships_of{$self};
  delete $Where_of{$self};
  delete $SaveMethod_of{$self};
  delete $DeleteMethod_of{$self};
}

}

1;
