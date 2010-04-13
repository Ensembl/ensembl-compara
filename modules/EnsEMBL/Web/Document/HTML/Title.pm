package EnsEMBL::Web::Document::HTML::Title;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new    { return shift->SUPER::new(@_, {'title' => 'Untitled document'} ); }
sub set    { $_[0]{'title'} = $_[1]; }
sub get    { return $_[0]{'title'}; }

sub render {
  my $self  = shift;
  my $title = $self->get;
  $title =~ s/<[^>]+>//g;
  $self->print("\n<title>$title</title>");
}
1;

