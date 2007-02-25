package ExaLead::Query;
use strict;

sub new {
  my( $class, $string, $context ) = @_;
  my $self = {
    'string'   => $string,
    'context'  => $context,
    'parameters'   => [],
    'terms'    => []
  };
  bless $self, $class;
  return $self;
}

sub context :lvalue { $_[0]->{'context'}; } # get/set string
sub string  :lvalue { $_[0]->{'string'};  } # get/set string

sub addTerm      { 
  my( $self, $term ) = @_;
  $term->{'regexp'} =~ s/\./\\S/g;
  foreach my $oldTerm (@{$self->{'terms'}}) {
    return if $term->{'regexp'} =~ /^$oldTerm->{'regexp'}$/; 
  }
  push @{$self->{'terms'}},      $term;
}
sub addParameter { push @{$_[0]{'parameters'}}, $_[1]; }

sub terms      { return @{$_[0]{'terms'}};      }
sub parameters { return @{$_[0]{'parameters'}}; }

1;
