package EnsEMBL::Web::Document::Renderer::String;

use strict;

use IO::String;

use base qw(EnsEMBL::Web::Document::Renderer);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(string => '', @_);
  return $self;
}

sub printf  { shift->{'string'} .= sprintf shift, @_; }
sub print   { shift->{'string'} .= join '', @_; }
sub content { return $_[0]{'string'}; }

sub fh {
  my $self = shift;
  $self->{'fh'} = new IO::String($self->{'string'}) unless $self->{'fh'};
  return $self->{'fh'};
}

1;