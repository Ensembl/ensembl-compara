package EnsEMBL::Web::Document::Panel::Navigation;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _start {
  my $self = shift;
  $self->printf(q(
  <div class="nav-panel">
    <div class="left-button">%s</div> 
    <div class="right-button">%s</div> 
    <h2>XX%s</h2>
  ),
    $self->{'previous'} ? sprintf( '<a href="%s">%s</a>' , $self->{'previous'}{'url'}, $self->{'previous'}{'caption'} ) : '',
    $self->{'next'}     ? sprintf( '<a href="%s">%s</a>' , $self->{'next'}{'url'},     $self->{'next'}{'caption'}     ) : '',
    $self->{'current'}{'caption'}
  
  );
}
sub _end   { 
  my $self = shift;
  $self->print(q(
  </div>));
}

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_content( $caption, $body );
}

sub add_content {
  my( $self, $content ) =@_;
  $self->print( $content );
}

1;
