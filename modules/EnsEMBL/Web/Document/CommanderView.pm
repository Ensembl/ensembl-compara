package EnsEMBL::Web::Document::CommanderView;

use strict;
use warnings;

use EnsEMBL::Web::Document::WebPage;

use CGI;
our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{

sub simple {
  my ($type, $commander, $parameter) = @_;
  my $self = __PACKAGE__->new(('objecttype' => $type, 'doctype' => 'Commander', 'access' => $parameter->{'access'}));

  CGI::header;
  $self->page->render($commander);

}

}

1;
