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

package EnsEMBL::Web::Document::Panel::Information;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _start { return qq{\n<table class="two-column">}; }
sub _end   { return "\n</table>"; }
sub _error { return shift->add_row(@_); }

sub add_row {
  my ($self, $label, $content, $status_switch) = @_;
  my ($extra, $button_image, $class);
  
  if ($status_switch =~ /=on$/) {
    $button_image = qq(<img src="/img/dd_menus/plus-box.gif" width="16" height="16" alt="+" />);
    $content      = '<p>To show this information click the + to the left</p>' if $status_switch =~ /=on$/;    
    $class        = ' class="print_hide_tr"';
  } else {
    $button_image = qq(<img src="/img/dd_menus/min-box.gif" width="16" height="16" alt="-" />);
  }
  
  $extra     = qq{<a class="print_hide" href="$status_switch">$button_image</a>} if $status_switch;
  $content ||= '&nbsp;';
  
  return qq{
    <tr$class>
      <th class="two-column">
        $extra$label
      </th>
      <td class="two-column">
        $content
      </td>
    </tr>
  };
}

1;
