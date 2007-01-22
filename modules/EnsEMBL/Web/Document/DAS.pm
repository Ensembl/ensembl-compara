package EnsEMBL::Web::Document::DAS;
use strict;

sub new {
  my $class = shift;
  my $self = { '_renderer' => undef, @_ };
  bless $self, $class;
  return $self;
}

sub renderer :lvalue { return $_[0]->{_renderer}; }

sub printf { my $self = shift; $self->renderer->printf( @_ ) if $self->{'_renderer'}; }
sub print  { my $self = shift; $self->renderer->print( @_ )   if $self->{'_renderer'}; }

1;
