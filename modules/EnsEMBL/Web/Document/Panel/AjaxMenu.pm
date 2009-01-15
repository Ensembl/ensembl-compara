package EnsEMBL::Web::Document::Panel::AjaxMenu;

use strict;
use Data::Dumper qw(Dumper);
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Document::Panel);

sub _start {
  my $self = shift;
}

sub _end   { 
  my $self = shift;
}

sub add_entry {
  my( $self, $hashref ) = @_;
  $self->{'entries'} ||= [];
  foreach( 'label', 'label_html' ){
    unless( defined $hashref->{$_} ){$hashref->{$_} = '' }
  }
  push @{$self->{'entries'}}, {
    'code'       => $hashref->{'code'}      || 'entry_'.($self->{'counter'}++),
    'type'       => $hashref->{'type'}      || '',
    'label'      => $hashref->{'label'},
    'label_html' => $hashref->{'label_html'},
    'link'       => $hashref->{'link'}      || undef,
    'priority'   => $hashref->{'priority'}  || 100,
    'class'      => $hashref->{'class'}     || '',
    'extra'      => $hashref->{'extra'}     || {},
  };
}

sub content {
  my $self = shift;
  $self->print('
<tbody class="real">');
  $self->printf('
  <tr>
    <th class="caption" colspan="2">%s</th>
  </tr>', escapeHTML($self->{'caption'}) );
  foreach my $entry ( sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'label'} cmp $b->{'label'} } @{$self->{'entries'}||[]} ) {
    my $txt = escapeHTML( $entry->{'label'} );
    $txt .= ( $entry->{'label_html'} );
    if( $entry->{'link'} ) {
      if ($entry->{'extra'}{'abs_url'}) {
	$txt = $entry->{'link'};
      }
      else {
	$txt = sprintf( '<a href="%s"%s %s>%s</a>',
          escapeHTML($entry->{'link'}),
	  $entry->{'extra'}{'external'} ? ' rel="external"' : '',
	  $entry->{'class'} ? sprintf(' class="%s"',$entry->{'class'} ) : '',
	  $txt
        );
      }
    }
    if( $entry->{'type'} ) {
      $self->printf( '
  <tr>
    <th>%s</th>
    <td>%s</td>
  </tr>', escapeHTML($entry->{'type'}), $txt );
    } else {
      $self->printf( '
  <tr>
    <td colspan="2">%s</td>
  </tr>', $txt );
    }
  }
  $self->print('
</tbody>');
}

sub render {
  my( $self, $first ) = @_;
  $self->content();
}

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_entry( 
    "$caption: $body" 
  );
}

1;
