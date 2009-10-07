package EnsEMBL::Web::Document::HTML::ModalContext;

# Generates the modal context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
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
    my $referer = $ENV{'REQUEST_URI'};
    my $time = time;
    
    $self->add_entry(
      'type'    => 'UserData',
      'id'      => 'user_data',
      'caption' => 'Custom Data',
      'url'     => "/UserData/ManageData?_referer=$referer;time=$time"
    );
    
    $self->add_entry(
      'type'    => 'Account',
      'id'      => 'account',
      'caption' => 'Your account',
      'url'     => "/Account/Login?_referer=$referer;time=$time"
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
      $name = escapeHTML($name);
      
      if ($id =~ /config/) {
        $name = qq{<a rel="$id" href="$entry->{'url'}">$name</a>};
        $panels .= qq{<div id="$id" class="modal_content js_panel" style="display:none"></div>};
      } else {
        $name = qq{<a href="$entry->{'url'}">$name</a>};
      }
    }
    
    $content .= qq{<li class="link $entry->{'class'}">$name</li>};
  }
  
  $content .= qq{
      </ul>
      <div class="modal_caption"></div>
      <span class="modal_close modal_but">Close</span>
    </div>
    $panels
    <div id="modal_default" class="modal_content js_panel" style="display:none"></div>
  </div>
  };
  
  $self->print($content);
}

1;
