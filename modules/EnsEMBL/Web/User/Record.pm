package EnsEMBL::Web::User::Record;

use strict;
use warnings;
use Data::Dumper;
use EnsEMBL::Web::DBSQL::UserDB;
our $AUTOLOAD;

{

my %Adaptor_of;
my %User_of;
my %Fields_of;
my %Id_of;
my %Type_of;

sub AUTOLOAD {
  ### AUTOLOAD method for getting and setting record attributes, and processing
  ### find_by requests. Attributes should be named after columns in the
  ### appropriate database table.
  ###
  ### Attribute names are not validated against the database table.
  my ($self, $value) = @_;
  my ($key) = ($AUTOLOAD =~ /::([a-z].*)$/);
  if ($value) {
    if (my ($find, $by) = ($key =~ /find_(.*)_by_(.*)/)) {
      #warn "FIND " . $find . " BY " . $by;
      return find_records(( type => $find, $by => $value )); 
    } else {
      ## perform set
      $self->fields($key, $value);
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
  $Type_of{$self} = defined $params{'type'} ? $params{'type'} : "record";
  $User_of{$self} = defined $params{'user'} ? $params{'user'} : 0;
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

sub delete {
  my $self = shift;
  $self->adaptor->delete_record((
                                  id => $self->id
                               ));
}

sub save {
  my $self = shift;
  my $dump = Dumper($self->fields);
  $dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  if ($self->id) {
    $self->adaptor->update_record((
                                    id => $self->id,
                                  user => $self->user, 
                                  type => $self->type,
                                  data => $dump 
                                 ));
  } else {
    $self->adaptor->insert_record(( 
                                  user => $self->user, 
                                  type => $self->type,
                                  data => $dump 
                                 ));
  }
  return 1;
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

sub adaptor {
  ### a
  my $self = shift;
  $Adaptor_of{$self} = shift if @_;
  return $Adaptor_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub user {
  ### a
  my $self = shift;
  $User_of{$self} = shift if @_;
  return $User_of{$self};
}

sub id {
  ### a
  my $self = shift;
  $Id_of{$self} = shift if @_;
  return $Id_of{$self};
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
  return @records;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Adaptor_of{$self};
  delete $Type_of{$self};
  delete $User_of{$self};
  delete $Fields_of{$self};
  delete $Id_of{$self};
}

}

1;
