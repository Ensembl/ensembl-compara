package ExaLead::Value;
use strict;

sub new {
  my( $class, $value, $query ) = @_;
  my $self = { 'value'     => $value, 'query' => $query };
  bless $self, $class;
  return $self;
}

sub value  :lvalue { $_[0]->{'value'};  } # get/set string

sub getString { return $_[0]->{'value'}; }

sub getHighlighted {
  my $string = $_[0]->{'value'};
  foreach my $qt ( sort { length($b->regexp) <=> length($a->regexp) }  $_[0]->{'query'}->terms ) {
    my $R = '('.$qt->regexp.')';
    $string =~ s/$R/<span class="hi">$1<\/span>/ismg;
  }
  return $string;
}
1;
