package ExaLead::TextSeg;
use strict;

sub new {
  my( $class ) = @_;
  my $self = {
    'parts'     => []
  };
  bless $self, $class;
  return $self;
}

sub addPart   { push @{$_[0]{'parts'}},  [$_[1],$_[2]]; }

sub getParts  { return $_[0]{'parts'}; }

sub getString { return join '', map { $_->[0] } @{$_[0]{'parts'}}; }
sub getHighlighted { return join '', map { $_->[1]==1 ? qq(<span class="hi">$_->[0]</span>) : $_->[0] } @{$_[0]{'parts'}}; }
1;
