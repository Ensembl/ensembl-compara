package EnsEMBL::Web::Record;

### Inside-out class representing persistent user information. This class
### follows the Active Record design pattern: it contains both the domain
### logic required to create and manipulate a piece of persistent data, and
### the information necessary to maintain this data in a database.
  
### It allows the storage of arbitrary hash keys and their values 
### (user bookmarks, etc) in a single database field, and uses autoloading
### to enable new data to be stored at will without the need for additional code

use strict;
use warnings;
use EnsEMBL::Web::DBSQL::UserDB;
use EnsEMBL::Web::Record::User;
use EnsEMBL::Web::Record::Group;
use Data::Dumper;

#our @ISA = qw(EnsEMBL::Web::Root);

our $AUTOLOAD;

{

my %Adaptor_of;
my %Fields_of;
my %ParameterSet_of;
my %Records_of;
my %Tainted_of;
my %Id_of;
my %CreatedAt_of;
my %ModifiedAt_of;
my %Type_of;
my %Owner_of;

sub AUTOLOAD {
  ### AUTOLOAD method for getting and setting record attributes, and processing
  ### find_by requests. Attributes should be named after columns in the
  ### appropriate database table.
  ###
  ### Attribute names are not validated against the database table.
  my $self = shift;
  my ($key) = ($AUTOLOAD =~ /::([a-z].*)$/);
  my ($value, $options) = @_;
  #warn "AUTOLOADING $key";
  if ($value) {
    if (my ($find, $by) = ($key =~ /find_(.*)_by_(.*)/)) {
      my $table = "user";
      my $record_type = "User";
      if ($find eq "records") {
         $find = "";
      }
      if ($find eq "group_records") {
        $find = "";
        $table = "group";
      }
      if ($by =~ /group_record/) {
        $table = "group";  
        $record_type = "Group";
      }
      return find_records(( record_type => $record_type, type => $find, $by => $value, table => $table, options => $options));
    } else {
      if (my ($type) = ($key =~ /(.*)_records/)) {
        return $self->records_of_type($type, $value);
      }
      $self->fields($key, $value);
    }
  } else {
    if (my ($type) = ($key =~ /(.*)_records/)) {
      return $self->records_of_type($type);
    }
  }
  return $self->fields($key);
}

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Adaptor_of{$self} = defined $params{'adaptor'} ? $params{'adaptor'} : undef;
  $Records_of{$self} = defined $params{'records'} ? $params{'records'} : [];
  $ParameterSet_of{$self} = defined $params{'parameter_set'} ? $params{'parameter_set'} : undef;
  $Id_of{$self} = defined $params{'id'} ? $params{'id'} : undef;
  $CreatedAt_of{$self} = defined $params{'created_at'} ? $params{'created_at'} : undef;
  $ModifiedAt_of{$self} = defined $params{'modified_at'} ? $params{'modified_at'} : undef;
  $Type_of{$self} = defined $params{'type'} ? $params{'type'} : "record";
  $Fields_of{$self} = {};
  $Tainted_of{$self} = {};
  if ($params{'data'}) {
    #$self->data($params{'data'});
    my $eval = eval($params{'data'});
    $Fields_of{$self} = $eval;
  } else {
    $Fields_of{$self} = {};
  }
  return $self;
}


sub taint {
  ### Marks a particular collection of records for an update. Tainted 
  ### records are updated in the database when the Record's save method
  ### is called.
  my ($self, $type) = @_;
  $self->tainted->{$type} = 1;
}

sub dump_data {
  ### Uses Data::Dumper to format a record's data for storage, 
  ### and also handles escaping of quotes to avoid SQL errors
  my $self = shift;
  my $temp_fields = {};
  foreach my $key (keys %{ $self->fields }) {
    $temp_fields->{$key} = $self->fields->{$key};
    $temp_fields->{$key} =~ s/'/\\'/g;
  }
  my $dump = Dumper($temp_fields);
  #$dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}

sub fields {
  ### a
  my ($self, $key, $value) = @_;
  if ($key) {
    if ($value) {
      $value =~ s/'/\\'/g;
      $Fields_of{$self}->{$key} = $value;
    }
    return $Fields_of{$self}->{$key}
  } else {
    return $Fields_of{$self};
  }
}

sub records {
  ### a
  my $self = shift;
  $Records_of{$self} = shift if @_;
  return $Records_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub tainted {
  ### a
  my $self = shift;
  $Tainted_of{$self} = shift if @_;
  return $Tainted_of{$self};
}

sub adaptor {
  ### a
  my $self = shift;
  $Adaptor_of{$self} = shift if @_;
  return $Adaptor_of{$self};
}

sub parameter_set {
  ### a
  my $self = shift;
  $ParameterSet_of{$self} = shift if @_;
  return $ParameterSet_of{$self};
}

sub id {
  ### a
  my $self = shift;
  $Id_of{$self} = shift if @_;
  return $Id_of{$self};
}

sub created_at {
  ### a
  my $self = shift;
  $CreatedAt_of{$self} = shift if @_;
  return $CreatedAt_of{$self};
}

sub modified_at {
  ### a
  my $self = shift;
  $ModifiedAt_of{$self} = shift if @_;
  return $ModifiedAt_of{$self};
}

sub records_of_type {
  ### Returns an array of records
  ### Argument 1: Type - string corresponding to a type of record, e.g. 'bookmark'
  ### Argument 2: Options - hash ref ('order_by' => sort expression, e.g.) 
  my ($self, $type, $options) = @_;
  my @return = ();
  warn "===> FINDING RECORDS OF TYPE: $type";
  if ($self->records) {
    warn "RECORDS!";
    foreach my $record (@{ $self->records }) {
      warn "--> RECORD: " . $record->type;
      if ($record->type eq $type) {
        push @return, $record;
      }
    }
  } 
  if ($options->{'order_by'}) {
    my $sorter = $options->{'order_by'};
    @return = reverse sort { $a->$sorter <=> $b->$sorter } sort @return;
  }
  return @return;
}

sub find_records {
  my (%params) = @_;
  my $record_type = "User";
  if ($params{record_type}) {
    $record_type = $params{record_type};
    delete $params{record_type};
  }
  $record_type = "EnsEMBL::Web::Record::" . $record_type;
  warn "FINDING RECORDS FOR: " . $record_type;
  my $user_adaptor = EnsEMBL::Web::DBSQL::UserDB->new();
  my $results = $user_adaptor->find_records(%params);
  my @records = ();
  foreach my $result (@{ $results }) {
    #if (&dynamic_use($record_type)) {
      warn "FOUND: " . $result;
      my $record = $record_type->new((
                                         id => $result->{id},
                                       type => $result->{type},
                                       user => $result->{user},
                                       data => $result->{data},
                                 created_at => $result->{created_at},
                                modified_at => $result->{modified_at}
                                                ));
      push @records, $record;
    #}
  }
  if ($params{options}) {
    my %options = %{ $params{options} };
    if ($options{order_by}) {
      @records = sort { $b->click <=> $a->click } @records;
    }
  }
  return @records;
}

sub owner {
  ### a
  my $self = shift;
  $Owner_of{$self} = shift if @_;
  return $Owner_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Adaptor_of{$self};
  delete $Fields_of{$self};
  delete $Id_of{$self};
  delete $CreatedAt_of{$self};
  delete $ModifiedAt_of{$self};
  delete $Records_of{$self};
  delete $ParameterSet_of{$self};
  delete $Tainted_of{$self};
  delete $Type_of{$self};
  delete $Owner_of{$self};
}

}

1;
