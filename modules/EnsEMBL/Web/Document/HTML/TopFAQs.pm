package EnsEMBL::Web::Document::HTML::TopFAQs;

### This module outputs a selection of FAQs for the help home page, 

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $html = '
    <h2 class="box-header">FAQs</h2>
    <h3>Top 5 Frequently Asked Questions</h3>
  ';

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($self->hub);

  my $args = {'limit' => 5};
  my @faqs = @{$adaptor->fetch_faqs($args)};

  if (scalar @faqs > 0) {
    $html .= '
      <ul>';

    foreach my $faq (@faqs) {
      $html .= sprintf('
        <li><strong>%s</strong><br /><a href="/Help/Faq?id=%s" class="popup">See answer &rarr;</a></li>', 
        $faq->{'question'}, $faq->{'id'}
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
