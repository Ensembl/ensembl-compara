package ExaLead::TextSeg;
use strict;

sub new {
### c
  my( $class ) = @_;
  my $self = {
    'parts'     => []
  };
  bless $self, $class;
  return $self;
}

sub addPart   {
### a
### each element of the array is a pait - the first value is the text and the second
### value is a flag either 1 - highlighted, 0 - unhighlighted
  push @{$_[0]{'parts'}},  [$_[1],$_[2]]; }

sub getParts  {
### a
  return $_[0]{'parts'};
}

sub getString {
### Returns a plain (un-highlighted) version of the string for the renderer
### (exhibits same intreface as {{exalead::Value}})
  return join '', map { $_->[0] } @{$_[0]{'parts'}};
}
sub getHighlighted {
### Returns a string with query terms tagged with with a highlighted span
### (exhibits same intreface as {{Exalead::Value}})
  return join '', map { $_->[1]==1 ? qq(<span class="hi">$_->[0]</span>) : $_->[0] } @{$_[0]{'parts'}};
}
1;
