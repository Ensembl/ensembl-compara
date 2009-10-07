package EnsEMBL::Web::Document::HTML::LocalTools;

# Generates the local context tools - configuration, data export, etc.

use strict;
use base qw(EnsEMBL::Web::Document::HTML);

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub entries {
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  
  return unless @{$self->entries};
  
  my %icons = (
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark'
  );
  
  my $html = ' 
  <div id="local-tools" style="display:none">
  ';
  
  foreach (@{$self->entries}) {
    my $icon = qq{<img src="/i/$icons{$_->{'caption'}}.png" alt="" style="vertical-align:middle;padding:0px 4px" />};
    
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled" title="$_->{'title'}">$icon$_->{'caption'}</p>};
    } else {
      my $attrs = $_->{'class'};
      my $rel = lc $_->{'rel'};
      $attrs .= ($attrs ? ' ' : '') . 'external' if $rel eq 'external';
      $attrs = qq{class="$attrs"} if $attrs;
      $attrs .= ' style="display:none"' if $attrs =~ /modal_link/;
      $attrs .= qq{ rel="$rel"} if $rel;
      
      $html .= qq{
        <p><a href="$_->{'url'}" $attrs>$icon$_->{'caption'}</a></p>};
    }
  }
  
  $html .= '
  </div>';
  
  $self->print($html);
}

1;
