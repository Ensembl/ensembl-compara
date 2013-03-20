package EnsEMBL::Web::Document::HTML::Glossary;

### This module outputs a selection of FAQs for the help home page, 

use strict;
use warnings;

use EnsEMBL::Web::Component::Help::Glossary;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $component = EnsEMBL::Web::Component::Help::Glossary->new($self->hub);

  return $component->content;
}

1;
