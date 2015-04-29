=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $html;
  my $page;
  if ($page && $page->include_navigation) {
    $html = qq(
    <p>Sorry, this view is not available for this feature. Please select a valid link from the menu on the left.</a>
);
  }
  else {
    $html = qq(
    <p>Sorry, you have entered an invalid URL. Please select a link from the top of the page.</a>
);
  }

  $html .= qq(
    <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="popup">contact our HelpDesk team</a>.</p>
);
  return $html;
}


1;
