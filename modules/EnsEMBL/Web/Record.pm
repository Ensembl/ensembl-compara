package EnsEMBL::Web::Record;

use strict;
use warnings;
use EnsEMBL::Web::DBSQL::UserDB;
use Data::Dumper;

our $AUTOLOAD;

{

my %Adaptor_of;
my %Fields_of;
my %ParameterSet_of;
my %Records_of;
my %Id_of;

sub AUTOLOAD {
  ### AUTOLOAD method for getting and setting record attributes, and processing
  ### find_by requests. Attributes should be named after columns in the
  ### appropriate database table.
  ###
  ### Attribute names are not validated against the database table.
  my $self = shift;
  my ($key) = ($AUTOLOAD =~ /::([a-z].*)$/);
  my ($value, $options) = @_;
#  warn "AUTOLOADING $key";
  if ($value) {
    if (my ($find, $by) = ($key =~ /find_(.*)_by_(.*)/)) {
      if ($find eq "records") {
         $find = "";
         warn "FINDING ALL RECORDS";
      }
      warn "FINDING: $find " . $by . ": " . $value;
      return find_records(( type => $find, $by => $value, options => $options));
    } else {
      ## perform set
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
  ### Inside-out class representing persitent user information. This class
  ### follows the Active Record design pattern: it contains both the domain
  ### logic required to create and manipulate a piece of persistent data, and
  ### the information necessary to maintain this data in a database.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Adaptor_of{$self} = defined $params{'adaptor'} ? $params{'adaptor'} : undef;
  $Records_of{$self} = defined $params{'records'} ? $params{'records'} : [];
  $ParameterSet_of{$self} = defined $params{'parameter_set'} ? $params{'parameter_set'} : undef;
  $Id_of{$self} = defined $params{'id'} ? $params{'id'} : "";
  $Fields_of{$self} = {};
  if ($params{'data'}) {
    #$self->data($params{'data'});
    my $eval = eval($params{'data'});
    $Fields_of{$self} = $eval;
  } else {
    $Fields_of{$self} = {};
  }
  return $self;
}

sub dump_data {
  my $self = shift;
  my $dump = Dumper($self->fields);
  $dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}

sub fields {
  ### a
  my ($self, $key, $value) = @_;
  if ($key) {
    if ($value) {
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

sub records_of_type {
  my ($self, $type, $options) = @_;
  my @return = ();
  if ($self->records) {
    foreach my $record (@{ $self->records }) {
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
  my %params = @_;
  my $user_adaptor = EnsEMBL::Web::DBSQL::UserDB->new();
  my $results = $user_adaptor->find_records(%params);
  my @records = ();
  foreach my $result (@{ $results }) {
    my $record = EnsEMBL::Web::User::Record->new((
                                         id => $result->{id},
                                       type => $result->{type},
                                       user => $result->{user_id},
                                       data => $result->{data}
                                                ));
    push @records, $record;
  }
  if ($params{options}) {
    my %options = %{ $params{options} };
    if ($options{order_by}) {
      @records = sort { $b->click <=> $a->click } @records;
    }
  }
  return @records;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Adaptor_of{$self};
  delete $Fields_of{$self};
  delete $Id_of{$self};
  delete $Records_of{$self};
  delete $ParameterSet_of{$self};
}

}

1;
