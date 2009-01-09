package EnsEMBL::Web::Document::HTML::Logo;

### Generates the logo wrapped in a link to the homepage

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub image   :lvalue { $_[0]{'image'};   }
sub width   :lvalue { $_[0]{'width'};   }
sub height  :lvalue { $_[0]{'height'};   }
sub alt     :lvalue { $_[0]{'alt'};   }
sub href     :lvalue { $_[0]{'href'}  }
sub print_image   :lvalue { $_[0]{'print_image'};   }

sub logo_img {
### a
  my $self = shift;
  return sprintf(
    '<img src="%s%s" alt="%s" title="%s" class="print_hide" style="width:%spx;height:%spx" />',
    $self->img_url, $self->image, $self->alt, $self->alt, $self->width, $self->height
  );
}

sub logo_print {
### a
  my $self = shift;
  return sprintf(
    '<img src="%s%s" alt="%s" title="%s" class="screen_hide_inline" style="width:%spx;height:%spx" />',
    $self->img_url, $self->print_image, $self->alt, $self->alt, $self->width, $self->height
  );
}

sub render {
  my $self = shift;
  my $url = $self->href || $self->home_url;
  $self->printf( '<a href="%s">%s</a>%s',
    $url, $self->logo_img, $self->logo_print
  );
}

1;
