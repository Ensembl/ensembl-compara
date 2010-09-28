# $Id$

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
