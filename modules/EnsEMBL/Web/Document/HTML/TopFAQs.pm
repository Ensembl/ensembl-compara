=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
      ## Strip paragraph tags inserted by TinyMCE
      (my $question = $faq->{'question'}) =~ s/<\/?p>//g;
      $html .= sprintf('
        <li><strong>%s</strong><br /><a href="/Help/Faq?id=%s" class="popup">See answer &rarr;</a></li>', 
        $question, $faq->{'id'}
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
