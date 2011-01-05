# $Id$

package EnsEMBL::Web::Document::Element;

use strict;

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $self  = shift;
  bless $self, $class;
  return $self;
}

sub renderer :lvalue { $_[0]->{'renderer'};                                                         }
sub hub              { return $_[0]->{'hub'};                                                       }
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
      new EnsEMBL::Web::Document::Panel(
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
    new EnsEMBL::Web::Document::Panel(
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
