package EnsEMBL::Web::Document::Renderer::String;

use strict;
use EnsEMBL::Web::Document::Renderer::Table::Text;
use Apache2::RequestUtil;

# use overload '""' => \&value;

sub new {
  my $class = shift;
  my $self = {
    r      => shift || (Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request() : undef ),
    string => '',
  };
  bless $self, $class;
  return $self;
}

sub fh { return undef; }

sub new_table_renderer {
### Create a new table renderer.
  my $self = shift;
  return EnsEMBL::Web::Document::Renderer::Table::Text->new( { 'renderer' => $self } );
}

sub valid  { return 1; }
sub printf { my $self = shift; my $temp = shift; $self->{'string'} .= sprintf( $temp, @_ ); }
sub print  { my $self = shift; $self->{'string'} .= join( '', @_ );    }
sub close  {}
sub value  { return $_[0]{'string'} }

1;
