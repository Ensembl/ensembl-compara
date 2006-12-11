package EnsEMBL::Web::Document::Renderer::Apache;
use strict;
use Apache2::RequestUtil;

sub new {
  my $class = shift;
  my $self = { 'r' => shift || (Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request() : undef )};
  bless $self, $class;
  return $self;
}

sub valid  { return $_[0]->{'r'}; }
sub printf { my $self = shift; my $temp = shift; $self->{'r'}->print( sprintf $temp, @_ ) if $self->{'r'}; }
sub print  { my $self = shift; $self->{'r'}->print(  @_        ) if $self->{'r'}; }
sub close  {}
1;
