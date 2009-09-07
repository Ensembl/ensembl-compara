package EnsEMBL::Web::Document::HTML::TopFAQs;

### This module outputs a selection of FAQs for the help home page, 

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Faq;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $html = qq(<h2 class="first">FAQs</h2>
    <h3>Top 3 Frequently Asked Questions</h3>);

  my @faqs = EnsEMBL::Web::Data::Faq->fetch_sorted(3);

  if (scalar(@faqs) > 0) {

    $html .= "<ul>\n";

    foreach my $faq (@faqs) {

      $html .= sprintf(qq(<li><strong>%s</strong><br /><a href="/Help/Faq?id=%s" class="popup">See answer &rarr;</a></li>\n),
              $faq->question, $faq->help_record_id);

    }

    $html .= qq(</ul>
<p><a href="/Help/Faq" class="popup">More...</a></p>\n);
  }

  return $html;
}

}

1;
