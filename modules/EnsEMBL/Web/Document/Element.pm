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

package EnsEMBL::Web::Document::Element;

use strict;

use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Document::Panel;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $self  = shift;
  bless $self, $class;
  return $self;
}

sub shared { return $_[0]->{'shared'}; }
sub renderer :lvalue { $_[0]->{'renderer'};                                                         }
sub hub              { return $_[0]->{'hub'};                                                       }
sub dom              { return $_[0]->{'dom'} ||= EnsEMBL::Web::DOM->new                             }
sub species_defs     { return $_[0]->hub->species_defs;                                             }
sub home_url         { return $_[0]->{'home_url'} ||= $_[0]->species_defs->ENSEMBL_WEB_ROOT || '/'; }
sub printf           { my $self = shift; $self->renderer->printf(@_) if $self->renderer;            }
sub print            { my $self = shift; $self->renderer->print(@_)  if $self->renderer;            }
sub content          {}

sub new_panel {
  my ($self, $panel_type, $controller, %params) = @_;
  
  my $module_name = 'EnsEMBL::Web::Document::Panel';
  $module_name.= "::$panel_type" if $panel_type;
  
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;

  if ($panel_type && !$self->dynamic_use($module_name)) {
    my $error = $self->dynamic_use_failure($module_name);
    
    if ($error =~ /^Can't locate/) {
      $error = qq{<p>Unrecognised panel type "<b>$panel_type</b>"};
    } else {
      $error = sprintf '<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($error);
    }
    
    push @{$controller->errors},
      EnsEMBL::Web::Document::Panel->new(
        hub        => $self->hub,
        builder    => $controller->builder,
        object     => $controller->object,
        code       => "error_$params{'code'}",
        caption    => 'Panel compilation error',
        content    => $error,
        has_header => $params{'has_header'},
      );
    
    return undef;
  }
  
  my $panel;
  
  eval {
    $panel = $module_name->new(
      hub     => $self->hub,
      builder => $controller->builder, 
      object  => $controller->object,
      %params
    );
  };
  
  return $panel unless $@;
  
  push @{$controller->errors},
    EnsEMBL::Web::Document::Panel->new(
      hub     => $self->hub,
      builder => $controller->builder,
      object  => $controller->object,
      code    => "error_$params{'code'}",
      caption => "Panel runtime error",
      content => sprintf ('<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($@))
    );
  
  return undef;
}

1;
