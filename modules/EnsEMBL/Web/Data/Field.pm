package EnsEMBL::Web::Data::Field;

use strict;
use warnings;

use Class::Std;

{

my %Name :ATTR(:set<name> :get<name>);
my %Type :ATTR(:set<type> :get<type>);
my %Queriable :ATTR(:set<queriable> :get<queriable>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $Name{$ident} = $args->{name};
  $Type{$ident} = $args->{type};
  $Queriable{$ident} = $args->{queriable};
}

sub is_queriable {
  my $self = shift;
  if (defined $self->get_queriable) {
    if ($self->get_queriable eq 'yes') {
      return 1;
    }  
  }
  return 0;
}

sub get_values {
  ### Parses an enum or set type and returns the values as an array
  my $self = shift;
  my $type = $self->get_type;
  my $values = [];

  if ($type =~ /^enum/ || $type =~ /^set/) {
    if ($type  =~ /^enum/) {
      $type =~ s/enum\(//;
    }
    else {
      $type =~ s/set\(//;
    }
    $type =~ s/\)//;
    
    my @types = split(',', $type);
    foreach my $value (@types) {
      $value =~ s/^'//;
      $value =~ s/'$//;
      push @$values, $value;
    }
  }
  return $values;
}

}

1;
