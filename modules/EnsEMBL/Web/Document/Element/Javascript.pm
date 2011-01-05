# $Id$

package EnsEMBL::Web::Document::Element::Javascript;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    scripts => '',
    sources => {}
  });
}

sub add_source { 
  my ($self, $src) = @_;
  
  return unless $src;
  return if $self->{'sources'}{$src};
  
  $self->{'sources'}{$src} = 1;
  $self->{'scripts'} .= sprintf qq{ <script type="text/javascript" src="%s%s"></script>\n}, $self->static_server, $src;
}

sub add_script {
  return unless $_[1];
  $_[0]->{'scripts'} .= qq{  <script type="text/javascript">\n$_[1]</script>\n};
}

sub content { return $_[0]->{'scripts'}; }

sub init {
  my ($self, $controller) = @_;
  
  return unless $controller->request eq 'ssi';
  
  my $head = $controller->content =~ /<head>(.*?)<\/head>/sm ? $1 : '';
  
  while ($head =~ s/<script(.*?)>(.*?)<\/script>//sm) {
    my ($attr, $cont) = ($1, $2);
    
    next unless $attr =~ /text\/javascript/;
    
    if ($attr =~ /src="(.*?)"/) {
      $self->add_source($1);
    } else {
      $self->add_script($cont);
    }   
  }
}

1;
