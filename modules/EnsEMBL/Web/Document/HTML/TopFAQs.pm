package EnsEMBL::Web::Document::HTML::TopFAQs;

### This module outputs a selection of FAQs for the help home page, 

use strict;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Faq;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $html = '
    <h2 class="first">FAQs</h2>
    <h3>Top 3 Frequently Asked Questions</h3>
  ';

  my @faqs = EnsEMBL::Web::Data::Faq->fetch_sorted(3);

  if (scalar @faqs > 0) {
    $html .= '
      <ul>';

    foreach my $faq (@faqs) {
      $html .= sprintf('
        <li><strong>%s</strong><br /><a href="/Help/Faq?id=%s" class="popup">See answer &rarr;</a></li>', 
        $faq->question, $faq->help_record_id
      );
    }

    $html .= '
      </ul>
      <p><a href="/Help/Faq" class="popup">More...</a></p>
    ';
  }

  return $html;
}

1;
