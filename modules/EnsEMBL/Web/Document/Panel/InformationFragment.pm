package EnsEMBL::Web::Document::Panel::InformationFragment;

use strict;
use warnings;

use URI::Escape qw(uri_escape);

use base qw(EnsEMBL::Web::Document::Panel);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{'html'} = undef;
  return $self;
}

sub add_row {
  my( $self, $label, $content, $status_switch ) =@_;
  $self->{html} .= $content;
}

sub html {
  my $self = shift;
  my $html = $self->{html};
  $html = uri_escape($html);
  return $html;
}

1;
