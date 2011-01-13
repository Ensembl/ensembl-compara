# $Id$

package EnsEMBL::Web::Document::Element::ModalButtons;

# Generates the tools buttons below the control panel left menu - add track, reset configuration

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub entries {
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, @_;
}

sub class {
  my $self = shift;
  $self->{'class'} = shift if @_;
  return $self->{'class'};
}

sub get_json {
  my $self = shift;
  return { tools => $self->content };
} 

sub content {
  my $self = shift;
  
  return unless @{$self->entries};
  
  my %classes = (
    'Add custom track'  => 'data',
    'Reset to defaults' => 'data',
  );
  
  my $html = '<div id="modal-tools">';

  foreach (@{$self->entries}) {
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled $classes{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>};
    } else {
      my $rel   = lc $_->{'rel'};
      my $attrs = $_->{'class'};
      $attrs   .= ($attrs ? ' ' : '') . 'external' if $rel eq 'external';
      $attrs   .= ($attrs ? ' ' : '') . $classes{$_->{'caption'}} if $classes{$_->{'caption'}};
      $attrs    = qq{class="$attrs"} if $attrs;
      #$attrs   .= ' style="display:none"' if $attrs =~ /modal_link/;
      $attrs   .= qq{ rel="$rel"} if $rel;

      $html .= qq{
        <p><a href="$_->{'url'}" $attrs>$_->{'caption'}</a></p>};
    }
  }
  
  $html .= '</div>';

  return $html; 
}

sub init {
  my $self        = shift;  
  my $controller  = shift;
  my $hub         = $controller->hub;
  
  $self->add_entry({
    caption => 'Add custom track',
    class   => 'modal_link',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => 'SelectFile',
      __clear => 1 
    })
  });
  
  $self->add_entry({
    caption => 'Reset to defaults',
    class   => 'modal_link',
    url     => $hub->url({
      time      => time,
      type      => 'Config',
      action    => $hub->type,
      function  => $hub->action,
      reset     => 1,
      __clear => 1 
    })
  });
  
}

1;
