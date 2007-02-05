package EnsEMBL::Web::Object::DataField;

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

}

1;
