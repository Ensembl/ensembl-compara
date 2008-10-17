package EnsEMBL::Web::Document::HTML::Title;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
@EnsEMBL::Web::Document::HTML::Title::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new    { return shift->SUPER::new( 'title' => 'Untitled document' ); }
sub set    { $_[0]{'title'}  = $_[1]; }
sub get    { return $_[0]{'title'}; }
sub render {
  my $self = shift;
  my $t = $self->get;
  $t =~ s/<[^>]+>//g;
  $self->printf( q(
  <title>%s</title>), $t );
}
1;

