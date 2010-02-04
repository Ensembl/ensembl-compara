package EnsEMBL::Web::Document::Renderer::Apache;

use strict;

use base qw(EnsEMBL::Web::Document::Renderer);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(formats => {}, @_);
  return $self;
}

sub valid  { return $_[0]->{'r'}; }
sub printf { shift->r->print( sprintf shift, @_ ); }
sub print  { shift->r->print(@_); }

sub fh {
  my $self = shift;
  tie *APACHE_FH => $self->{'r'};
  binmode(APACHE_FH);
  return \*APACHE_FH;
}

1;
