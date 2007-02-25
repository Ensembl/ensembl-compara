package ExaLead::Hit;
use strict;

sub new {
  my( $class, $URL, $score ) = @_;
  my $self = {
    'URL'       => $URL       ||'',
    'score'     => $score     ||0,
    'groups'    => [],
    'fields'    => {}
  };
  bless $self, $class;
  return $self;
}

sub URL       :lvalue { $_[0]->{'URL'};    } # get/set string
sub score     :lvalue { $_[0]->{'score'};  } # get/set int

sub field      { return $_[0]{'fields'}{$_[1]}; }
sub addField   {
  my($self,$key,$value) = @_;
  $self->{'fields'}{$key} = $value;
}
sub fields     { return @{ $_[0]{'fields'} }; }

sub addGroup   { push @{$_[0]{'groups'}},  $_[1]; }
sub groups     { return @{ $_[0]{'groups'} }; }

1;
