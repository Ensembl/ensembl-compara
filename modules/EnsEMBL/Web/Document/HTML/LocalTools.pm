# $Id$

package EnsEMBL::Web::Document::HTML::LocalTools;

# Generates the local context tools - configuration, data export, etc.

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub entries {
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, @_;
}

sub _content {
  my $self = shift;
  
  return unless @{$self->entries};
  
  my %classes = (
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark'
  );
  
  my $html = '<div id="local-tools">';

  foreach (@{$self->entries}) {
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled $classes{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>};
    } else {
      my $rel   = lc $_->{'rel'};
      my $attrs = $_->{'class'};
      $attrs   .= ($attrs ? ' ' : '') . 'external' if $rel eq 'external';
      $attrs   .= ($attrs ? ' ' : '') . $classes{$_->{'caption'}} if $classes{$_->{'caption'}};
      $attrs    = qq{class="$attrs"} if $attrs;
      $attrs   .= ' style="display:none"' if $attrs =~ /modal_link/;
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
  my $object      = $controller->object;
  my $view_config = $controller->view_config;
  my $config      = $view_config && $view_config->real ? $view_config->default_config : undef;
  
  if ($config) {
    my $action = join '/', map $hub->$_ || (), qw(type action function);
    (my $rel   = $config) =~ s/^_//;
    
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$rel",
      url     => $hub->url({ 
        time   => time, 
        type   => 'Config', 
        action => $action,
        config => $config
      })
    });
  } else {
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
  
  $self->add_entry({
    caption => 'Manage your data',
    class   => 'modal_link',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => 'ManageData',
      __clear => 1 
    })
  });
  
  if ($object && $object->can_export) {       
    $self->add_entry({
      caption => 'Export data',
      class   => 'modal_link',
      url     => $self->export_url($hub)
    });
  } else {
    $self->add_entry({
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    });
  }
  
  if ($hub->user) {
    my $title = $controller->page->title;
    
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type      => 'Account',
        action    => 'Bookmark/Add',
        __clear   => 1,
        name      => $title->get,
        shortname => $title->get_short,
        url       => $hub->species_defs->ENSEMBL_BASE_URL . $hub->url
      })
    });
  } else {
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    });
  } 
}

sub export_url {
  my $self   = shift;
  my $hub    = shift;
  my $type   = $hub->type;
  my $action = $hub->action;
  my $export;
  
  if ($type eq 'Location' && $action eq 'LD') {
    $export = 'LDFormats';
  } elsif ($type eq 'Transcript' && $action eq 'Population') {
    $export = 'PopulationFormats';
  } elsif ($action eq 'Compara_Alignments') {
    $export = 'Alignments';
  } else {
    $export = 'Configure';
  }
  
  return $hub->url({ type => 'Export', action => $export, function => $type });
}

1;
