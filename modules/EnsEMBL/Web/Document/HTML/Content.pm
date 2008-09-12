package EnsEMBL::Web::Document::HTML::Content;
use strict;
use CGI qw(escapeHTML);
use Data::Dumper qw(Dumper);

use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::Content::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'panels' => [], 'first' => 1, 'form' => '' );
  my $timer = shift;
  $self->{'timer'} = $timer;  
  return $self;
}

sub add_panel_first { $_[1]->renderer = $_[0]->renderer; unshift @{$_[0]{'panels'}}, $_[1]; }
sub add_panel_last  { $_[1]->renderer = $_[0]->renderer;    push @{$_[0]{'panels'}}, $_[1]; }
sub add_panel       { $_[1]->renderer = $_[0]->renderer;    push @{$_[0]{'panels'}}, $_[1]; }

sub add_panel_after {
  my( $self, $panel, $code ) = @_;
  $panel->renderer = $self->renderer;
  my $counter = 0;
  foreach( @{$self->{'panels'}} ) {
    $counter++;
    last if $_->{'code'} eq $code;
  }
  splice @{$self->{'panels'}}, $counter,0, $panel;
}

sub add_panel_before {
  my( $self, $panel, $code ) = @_;
  $panel->renderer = $self->renderer;
  my $counter = 0;
  foreach( @{$self->{'panels'}} ) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  splice @{$self->{'panels'}}, $counter,0, $panel;
}

sub replace_panel {
  my( $self, $panel, $code ) = @_;
  $panel->renderer = $self->renderer;
  my $counter = 0;
  foreach( @{$self->{'panels'}} ) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  splice @{$self->{'panels'}}, $counter,1, $panel;
}

sub remove_panel {
  my( $self, $code ) = @_;
  my $counter = 0;
  foreach( @{$self->{'panels'}} ) {
    if( $_->{'code'} eq $code ) {
      splice @{$self->{'panels'}}, $counter,1;
      return;
    }
    $counter++;
  }
}

sub panels{
  # Lists the codes for each panel in this page content
  my( $self ) = @_;
  return map{ $_->{'code'} } @{ $self->{'panels'} || [] };
}

sub _start { $_[0]->print(); return 1; }
sub _end {   $_[0]->print(); }

sub panel {
  my( $self, $code ) = @_;
  foreach( @{$self->{'panels'}} ) {
    return $_ if $code eq $_->{'code'};
  }
  return undef;
}

sub first :lvalue { $_[0]->{'first'}; }
sub form  :lvalue { $_[0]->{'form'}; }


sub timer_push { $_[0]->{'timer'} && $_[0]->{'timer'}->push( $_[1], 2 ); }

sub render {
  my $self = shift;
  $self->_start;
  $self->print( "\n$self->{'form'}" ) if $self->{'form'};
  foreach my $panel ( @{$self->{'panels'}} ) { 
    $panel->{'timer'} = $self->{'timer'};
    $panel->render( $self->{'first'} );
    $self->{'first'} = 0;
    $self->timer_push( "Rendered panel ".$panel->{'code'} );
  }
  $self->print( "\n</form>" ) if $self->{'form'};
  $self->_end;
}

1;

