# $Id$

package EnsEMBL::Web::Document::Element;

use strict;

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;
  
  my $self = {
    %$args,
    _home_url => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT   || '/',
    _img_url  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_IMAGE_ROOT || '/i/',
  };
  
  bless $self, $class;
  
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'};           }
sub home_url :lvalue { $_[0]->{'_home_url'};           }
sub img_url  :lvalue { $_[0]->{'_img_url'};            }
sub species_defs     { return $_[0]->{'species_defs'}; }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub content {}

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
        hub        => $controller->hub,
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
      builder => $controller->builder, 
      hub     => $controller->hub,
      object  => $controller->object,
      %params
    );
  };
  
  return $panel unless $@;
  
  push @{$controller->errors},
    new EnsEMBL::Web::Document::Panel(
      hub     => $controller->hub,
      builder => $controller->builder,
      object  => $controller->object,
      code    => "error_$params{'code'}",
      caption => "Panel runtime error",
      content => sprintf ('<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($@))
    );
  
  return undef;
}

1;
