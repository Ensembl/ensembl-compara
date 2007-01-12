package EnsEMBL::Web::Document::Renderer::Stdout;
use strict;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  return $self;
}

sub fh {
  binmode(STDOUT);
  return \*STDOUT; 
}
sub valid  { 1; }
sub printf { my $self = shift; printf( @_ ); }
sub print  { my $self = shift; print(  @_ ); }
sub close  { }
1;
