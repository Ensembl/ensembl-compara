package EnsEMBL::Web::Document::HTML::ModalContext;

# Generates the modal context navigation menu, used in dynamic pages

use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Document::HTML);

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}

sub entries {
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift; 
  
  # Static pages - add Custom Data and Your account links
  if (!scalar @{$self->entries}) {
    my $time = time;
    
    $self->add_entry(
      'type'    => 'UserData',
      'id'      => 'user_data',
      'caption' => 'Custom Data',
      'url'     => "/UserData/ManageData?time=$time"
    );
    
    $self->add_entry(
      'type'    => 'Account',
      'id'      => 'account',
      'caption' => 'Your account',
      'url'     => "/Account/Login?time=$time"
    );
  }
  
  my $panels;
  
  my $content = '
  <div id="modal_bg"></div>
  <div id="modal_panel" class="js_panel">
    <input type="hidden" class="panel_type" value="ModalContainer" />
    <div class="modal_title">
      <ul class="tabs">';
    
  foreach my $entry (@{$self->entries}) {
    my $name = $entry->{'caption'};
    
    if ($name eq '-') {
      $name = qq{<span title="$entry->{'disabled'}">$entry->{'type'}</span>};
    } else {
      my $id = 'modal_' . lc($entry->{'id'} || $entry->{'type'});
      
      $name =~ s/<\\\w+>//g;
      $name =~ s/<[^>]+>/ /g;
      $name =~ s/\s+/ /g;
      $name = encode_entities($name);
      
      if ($id =~ /config/) {
        $name = qq{<a rel="$id" href="$entry->{'url'}">$name</a>};
        $panels .= qq{<div id="$id" class="modal_content js_panel" style="display:none"></div>};
      } else {
        $name = qq{<a href="$entry->{'url'}">$name</a>};
      }
    }
    
    $content .= qq{<li class="$entry->{'class'}">$name</li>};
  }
  
  $content .= qq{
      </ul>
      <div class="modal_caption"></div>
      <img class="modal_close" src="/i/cp_close.png" alt="Save and close" title="Save and close" />
    </div>
    $panels
    <div id="modal_default" class="modal_content js_panel" style="display:none"></div>
  </div>
  };
  
  $self->print($content);
}

1;
