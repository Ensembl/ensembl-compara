package EnsEMBL::Web::Document::Renderer::Apache;

use strict;
use EnsEMBL::Web::Document::Renderer::Table::HTML;
use EnsEMBL::Web::Document::Renderer::CellFormat::HTML;
use Apache2::RequestUtil;

sub new {
  my $class = shift;
  my $self = { 'r' => shift || (Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request() : undef ), 'formats' => {} };
  bless $self, $class;
  return $self;
}

sub new_table_renderer {
### Create a new table renderer.
  my $self = shift;
  return EnsEMBL::Web::Document::Renderer::Table::HTML->new( { 'renderer' => $self } );
}

sub fh {
  my $self = shift;
  tie *APACHE_FH => $self->{'r'};
  binmode(APACHE_FH);
  return \*APACHE_FH;
}

sub valid  { return $_[0]->{'r'}; }
sub printf { my $self = shift; my $temp = shift; $self->{'r'}->print( sprintf $temp, @_ ) if $self->{'r'}; }
sub print  { my $self = shift; $self->{'r'}->print(  @_        ) if $self->{'r'}; }
sub close  {}

sub new_cell_format {
  my( $self, $arg_ref ) = @_;
  $arg_ref ||= {};
  $arg_ref->{'format_hashref'} = $self->{'formats'};
  my $format = EnsEMBL::Web::Document::Renderer::CellFormat::HTML->new($arg_ref);
  return $format;
}

1;
