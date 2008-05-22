package EnsEMBL::Web::Document::HTML;

use strict;
use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $self = { '_renderer' => undef, @_ };
  bless $self, $class;
  return $self;
}

sub home_url {
  ### a
  return '/';
}

sub img_url  {
  ### a
  return '/i/';
}

sub _root_url { return $_[0]->species_defs->ENSEMBL_ROOT_URL; }

sub species_defs :lvalue { return $_[0]->{'_species_defs'}; }

sub renderer :lvalue { return $_[0]->{_renderer}; }

sub printf { my $self = shift; $self->renderer->printf( @_ ) if $self->{'_renderer'}; }
sub print { my $self = shift; $self->renderer->print( @_ )   if $self->{'_renderer'}; }

1;
