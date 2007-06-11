package EnsEMBL::Web::Document::HTML::Javascript;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use warnings;

@EnsEMBL::Web::Document::HTML::Javascript::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'scripts' => '', 'sources' => {} ); }

sub add_source { 
  my( $self, $src ) = @_;
  return unless $src;
  return if $self->{'sources'}{$src};
  $self->{'sources'}{$src}=1;
  
  foreach( qw(core42 prototype scriptaculous) ) {
    $self->{'scripts'}.=qq(  <script type="text/javascript" src="/js/$_.js"></script>\n) unless $self->{'sources'}{"/js/$_.js"};
    $self->{'sources'}{"/js/$_.js"} = 1;

  }
  $self->{'scripts'}.=qq(  <script type="text/javascript" src="$src"></script>\n);
#  warn "sr7: added $src\n";
  
}
sub add_script {
  return unless $_[1];
  $_[0]->{'scripts'}.=qq(  <script type="text/javascript">\n$_[1]</script>\n);
}

sub render { $_[0]->print( $_[0]->{'scripts'} ); } 
1;


