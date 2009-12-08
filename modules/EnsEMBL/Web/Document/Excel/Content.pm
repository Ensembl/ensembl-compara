package EnsEMBL::Web::Document::Excel::Content;
use strict;

use base qw(EnsEMBL::Web::Document::Excel);

sub new { return shift->SUPER::new( 'panels' => [], 'first' => 1, 'form' => '' ); }

sub add_panel {
  my( $self, $panel ) = @_;
warn "ADDING PANEL.......................  $panel";
  $panel->renderer = $self->renderer;
  push @{$self->{'panels'}}, $panel;
}

sub panel {
  my( $self, $code ) = @_;
  foreach( @{$self->{'panels'}} ) {
    return $_ if $code eq $_->{'code'};
  }
  return undef;
}

sub first :lvalue { $_[0]->{'first'}; }
sub form  :lvalue { $_[0]->{'form'}; }

sub render {
  my $self = shift;
warn "HERE.....";
  foreach my $panel ( @{$self->{'panels'}} ) {
warn "####\n####    $panel ",$self->renderer;
    $panel->{_renderer} = $self->renderer;
    $panel->render_Excel( 0 );
  }
}

1;

