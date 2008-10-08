package EnsEMBL::Web::Document::HTML::Title;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
@EnsEMBL::Web::Document::HTML::Title::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new    { return shift->SUPER::new( 'title' => 'Untitled document' ); }
sub set    { $_[0]{'title'}  = $_[1]; }
sub get    { return $_[0]{'title'}; }
sub render { $_[0]->printf( qq(  <title>%s</title>\n), CGI::escapeHTML($_[0]->{'title'}) ); }

1;

