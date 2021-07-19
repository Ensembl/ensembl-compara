=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::404;

use strict;

use base qw( EnsEMBL::Web::Component);

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $html;

  my $nav_message;
  my $page = $hub->controller->page;
  if ($page->template->{'lefthand_menu'}) {
    $nav_message = 'Please select a valid link from the menu on the left.';
  }
  else {
    $nav_message = 'Please select a link from the top of the page.';
  }

  ## Is this a real page?
  my $config = $hub->controller->configuration;
  ## For some reason the configuration is empty, so populate it
  $config->populate_tree;
  my $tree      = $config->tree;
  my $node_key  = join '/', grep $_, $hub->action, $hub->function;
  my $node      = $tree->get_node($node_key);

  if ($node) {
    ## Get the actual title for this page
    $html .= sprintf '<h1>%s</h1>', $node->get_data('caption');
    $html .= "<p>Sorry, this page is not available for this feature. $nav_message</p>";
  }
  else {
    $html .= '<h1>Invalid URL</h1>';
    $html .= "<p>Sorry, you have entered an invalid URL. $nav_message</p>";
  }

  $html .= qq(
    <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="popup">contact our HelpDesk team</a>.</p>
);
  return $html;
}


1;
