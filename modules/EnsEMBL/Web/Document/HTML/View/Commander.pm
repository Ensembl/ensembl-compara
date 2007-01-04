package EnsEMBL::Web::Document::HTML::View::Commander;

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::View;
use EnsEMBL::Web::Commander;

our @ISA = qw(EnsEMBL::Web::Document::HTML::View);

{

sub new    { 
  my ($class, %params) = @_;
  my $self = shift->SUPER::new( 'html' => '' );
  return $self;
}

sub render_page {
  my ($self, $commander) = @_;
  $self->print($commander->render_current_node);
}

sub DESTROY {
  my $self = shift;
}

}

1;
