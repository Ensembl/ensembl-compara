# $Id$

package EnsEMBL::Web::Component::Search;

use strict;

use EnsEMBL::Web::Component::Help::Faq;
use base qw(EnsEMBL::Web::Component);


sub no_results {
  my ($self, $search_term) = @_;

  my $html = qq{<p>Your query <strong>- $search_term  -</strong> did not match any records in the database. Please make sure all terms are spelled correctly</p>};

  my $faq = EnsEMBL::Web::Component::Help::Faq->new($self->hub, $self->builder, $self->renderer);
  $html .= $faq->content(373);

  return $html;  
}

1;
