package EnsEMBL::Web::Document::Renderer::String;
use strict;

# use overload '""' => \&value;

sub new {
  my $class = shift;
  my $self  = { 'string' => '' };
  bless $self, $class;
  return $self;
}

sub valid  { return 1; }
sub printf { my $self = shift; my $temp = shift; $self->{'string'} .= sprintf( $temp, @_ ); }
sub print  { my $self = shift; $self->{'string'} .= join( '', @_ );    }
sub close  {}
sub value  { return $_[0]{'string'} }

1;
