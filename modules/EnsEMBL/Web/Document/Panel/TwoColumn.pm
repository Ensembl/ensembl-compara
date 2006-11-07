package EnsEMBL::Web::Document::Panel::TwoColumn;

### Panel with two columns (standard CSS floating divs)
### Chunks of HTML can be added to either column as required:
### $panel->add_content('r', $html);
### $panel->add_content('left', $html);
### (both the full name of the columns and the initial l or r are supported)


use strict;
use EnsEMBL::Web::Document::Panel;

@EnsEMBL::Web::Document::Panel::TwoColumn::ISA = qw(EnsEMBL::Web::Document::Panel);

sub new {
  ### c
  ### Sets default column widths of 47%, as per the col2 style in content.css
  return shift->SUPER::new( @_, 'column_left_html' => '', 'column_left_width' => '47%', 
                                'column_right_html' => '', 'column_right_width' => '47%' );
}

sub _start {
  ### Initialises the temporary buffer
  my $self = shift;
  $self->{'_temp_delayed_write_'} = $self->{'_delayed_write_'};
  $self->{'_delayed_write_'} = 1;
}

sub _end {
  ### outputs the HTML for each column to a temporary buffer
  my $self = shift;
  my $temp = $self->buffer;
  $self->reset_buffer;
  my $left_html = $self->{'column_left_html'};
  my $left_width = $self->{'column_left_width'};
  my $right_html = $self->{'column_right_html'};
  my $right_width = $self->{'column_right_width'};

  $self->{'_delayed_write_'} = $self->{'_temp_delayed_write_'};
  $self->print( qq(
<div class="col-wrapper">
  <div class="col" style="width:$left_width">
    $left_html
  </div>
  <div class="col" style="width:$right_width">
    $right_html
  </div>
</div>) );
}

sub set_column_width {
  ### a
  ### Arguments: side (l|left or r|right), width (any CSS-compatible measurement, e.g. %, px)
  my( $self, $side, $width ) =@_;
  if ($width) {
    if ($side =~ /r|right/i) {
      $self->{'column_right_width'} = $width;
    }
    elsif ($side =~ /l|left/i) {
      $self->{'column_left_width'} = $width;
    }
  }
}

sub add_content {
  ### a
  ### Arguments: side (l|left or r|right), content (HTML string)
  my( $self, $side, $content ) =@_;
  if( $content ) {
    if ($side =~ /r|right/i) {
      $self->{'column_right_html'} .= $content;
    }
    elsif ($side =~ /l|left/i) {
      $self->{'column_left_html'} .= $content;
    }
  }
}

return 1;
