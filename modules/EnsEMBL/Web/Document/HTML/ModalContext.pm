package EnsEMBL::Web::Document::HTML::ModalContext;

### Generates the modal context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


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
  $self->print($self->_content);
}

sub _content {
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
  
  my $content = '
  <div id="modal_bg"></div>
  <div id="modal_panel" class="js_panel">
    <input type="hidden" class="panel_type" value="ModalContainer" />
    <div class="modal_title">
      <ul class="tabs">';
    
  foreach my $entry (@{$self->entries}) {
    my $name = $entry->{'caption'};
    
    if ($name eq '-') {
      $name = sprintf '<span title="%s">%s</span>', $entry->{'disabled'}, $entry->{'type'};
    } else {
      my $id = lc($entry->{'id'} || $entry->{'type'});
      
      $name =~ s/<\\\w+>//g;
      $name =~ s/<[^>]+>/ /g;
      $name =~ s/\s+/ /g;
      $name = CGI::escapeHTML($name);
      $name = sprintf '<a rel="%s" href="%s">%s</a>', $id, $entry->{'url'}, $name;
    }
    
    $content .= sprintf '
        <li class="link %s">%s</li>', $entry->{'class'}, $name;
  }
  
  $content .= '
      </ul>
      <div class="modal_caption"></div>
      <span class="modal_close modal_but">Close</span>
    </div>
    <div class="modal_content js_panel" style="display:none"></div>
  </div>
  ';
  
  return $content;
}

1;
