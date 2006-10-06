package ExaLead::Value;
use strict;

sub new {
### c
  my( $class, $value, $query ) = @_;
  my $self = { 'value'     => $value, 'query' => $query };
  bless $self, $class;
  return $self;
}

sub value  :lvalue {
### a
  $_[0]->{'value'};
} # get/set string

sub getString {
### Returns a plain (un-highlighted) version of the string for the renderer
### (exhibits same intreface as {{Exalead::TextSeg}})
  return $_[0]->{'value'}; }

sub getHighlighted {
### Returns a string with query terms tagged with with a highlighted span
### (exhibits same intreface as {{Exalead::TextSeg}}
  my $string = $_[0]->{'value'};
  foreach my $qt ( sort { length($b->regexp) <=> length($a->regexp) }  $_[0]->{'query'}->terms ) {
    my $R = '('.$qt->regexp.')';
    $string =~ s/$R/<span class="hi">$1<\/span>/ismg;
  }
  return $string;
}
1;
