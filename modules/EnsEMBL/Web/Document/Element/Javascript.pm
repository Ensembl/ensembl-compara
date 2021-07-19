=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  $self->{'scripts'} .= sprintf qq{ <script type="text/javascript" src="%s%s"></script>\n}, $src =~ /^\// ? $self->static_server : '', $src;
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
