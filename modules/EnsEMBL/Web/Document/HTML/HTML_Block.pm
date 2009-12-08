package EnsEMBL::Web::Document::HTML::HTML_Block;
use strict;
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::HTML_Block::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new    { return shift->SUPER::new( 'html' => '' ); }
sub add    { $_[0]->{'html'}.= $_[1]; }
sub render { $_[0]->print( $_[0]->{'html'} ); } 
1;


