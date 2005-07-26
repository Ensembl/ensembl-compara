package EnsEMBL::Web::Document::Panel::InformationImage;

use strict;
use EnsEMBL::Web::Document::Panel::Information;
use Data::Dumper qw(Dumper);

our @ISA = qw(EnsEMBL::Web::Document::Panel::Information);

sub new {
  return shift->SUPER::new( @_, 'image_html' => '', 'max_image_width' => 0 );
}

sub _start {
  my $self = shift;
  $self->{'_temp_delayed_write_'} = $self->{'_delayed_write_'};
  $self->{'_delayed_write_'} = 1;
}

sub _end {
  my $self = shift;
  my $temp = $self->buffer;
  $self->reset_buffer;
  my $image_html = '';
  if( $self->{'max_image_width'} ) {
    $image_html = qq(<td class="image" style="width: $self->{'max_image_width'}px">$self->{'image_html'}</td>);
  }
  $self->{'_delayed_write_'} = $self->{'_temp_delayed_write_'};
  $self->print( qq(
<table class="info-image">
  <tr>
    $image_html
    <td class="info"><table class="stacked">$temp</table></td>
  </tr>
</table>) );
}

sub add_row {
  my( $self, $label, $content ) =@_;
  $self->print( sprintf qq(
  <tr>
    <th class="stacked">%s</th>
  </tr>
  <tr>
    <td class="stacked">%s</td>
  </tr>), $label, $content );
}

sub add_image {
  my( $self, $content, $width ) =@_;
  if( $width ) {
    $self->{'max_image_width'} = $width if $width > $self->{'max_image_width'};
    $self->{'image_html'} .= $content;
  }
}

1;
