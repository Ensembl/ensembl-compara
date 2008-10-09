package EnsEMBL::Web::Document::HTML::BodyJavascript;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use warnings;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'scripts' => '', 'sources' => {}, 'debug' => 0 ); }

sub debug {
  my $self = shift;
  $self->{'debug'} = shift if @_;
  return $self->{'debug'};
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

sub render {
  my $self = shift;
  $self->print( $self->{'scripts'} );

  $self->print( q(  <div id="uploadframe_div" style="display: none"><iframe name="uploadframe"></iframe></div>) );
  $self->print( q(  <div id="debug"></div>)) if $self->debug();
} 
1;


