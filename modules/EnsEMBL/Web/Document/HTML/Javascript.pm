package EnsEMBL::Web::Document::HTML::Javascript;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use warnings;

@EnsEMBL::Web::Document::HTML::Javascript::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'scripts' => '', 'sources' => {} );
  return $self;
}

sub add_source { 
  my( $self, $src ) = @_;
  return unless $src;
  
  return if $self->{'sources'}{$src};
  $self->{'sources'}{$src}=1;
  $self->{'scripts'}.=qq(  <script type="text/javascript" src="$src"></script>\n);
}

sub add_script {
  return unless $_[1];
  $_[0]->{'scripts'}.=qq(  <script type="text/javascript">\n$_[1]</script>\n);
}

sub render { $_[0]->print( $_[0]->{'scripts'} ); } 
1;


