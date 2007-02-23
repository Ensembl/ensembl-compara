package EnsEMBL::Web::ParameterSet;

use strict;
use warnings;

{

my %CGI_of;
my %Data_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $CGI_of{$self} = defined $params{'cgi'} ? $params{'cgi'} : undef;
  $Data_of{$self} = defined $params{'data'} ? $params{'data'} : undef;
  return $self;
}

sub input {
  ### Convenience method to call the CGI accessor, {{cgi}}. 
  my $self = shift;
  return $self->cgi(@_);
}

sub cgi {
  ### a
  my $self = shift;
  $CGI_of{$self} = shift if @_;
  return $CGI_of{$self};
}

sub DESTROY {
  ### d
  my $self;
  delete $CGI_of{$self};
}

}

1;
