package EnsEMBL::Web::Document::Panel::Information;

use strict;
use EnsEMBL::Web::Document::Panel;
use Data::Dumper qw(Dumper);

@EnsEMBL::Web::Document::Panel::Information::ISA = qw(EnsEMBL::Web::Document::Panel);

sub _start { $_[0]->print(qq(\n<table class="two-column">)); }
sub _end   { $_[0]->print(qq(\n</table>)); }

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_row( $caption, $body );
}

sub add_row {
  my( $self, $label, $content, $status_switch ) =@_;
  my $extra = '';
  my( $button_image, $class );
  if( $status_switch =~ /=on$/ ) {
    $button_image = qq(<img src="/img/dd_menus/plus-box.gif" width="16" height="16" alt="+" />);
    $content = '<p>To show this information click the + to the left</p>' if $status_switch =~ /=on$/;    
    $class = ' class="print_hide"';
  } else {
    $button_image = qq(<img src="/img/dd_menus/min-box.gif" width="16" height="16" alt="-" />);
    $class = '';
  }
  if( $status_switch ) {
    $extra = sprintf '<a class="print_hide" href="%s">%s</a> ',
                     $status_switch, $button_image
  }
  $self->printf( qq(
  <tr%s>
    <th class="two-column">
      %s%s
    </th>
    <td class="two-column">%s
    </td>
  </tr>), $class, $extra, $label, $content || '&nbsp;' );
}

1;
