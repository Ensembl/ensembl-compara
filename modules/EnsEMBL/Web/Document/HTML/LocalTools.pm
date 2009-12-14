package EnsEMBL::Web::Document::HTML::LocalTools;

# Generates the local context tools - configuration, data export, etc.

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use EnsEMBL::Web::RegObj;

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
  $self->print($self->_content);
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

  foreach( @{$self->entries} ) {
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled $classes{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>};
    } else {
      my $attrs = $_->{'class'};
      my $rel = lc $_->{'rel'};
      $attrs .= ($attrs ? ' ' : '') . 'external' if $rel eq 'external';
      $attrs .= ($attrs ? ' ' : '') . $classes{$_->{'caption'}} if $classes{$_->{'caption'}};
      $attrs = qq{class="$attrs"} if $attrs;
      $attrs .= ' style="display:none"' if $attrs =~ /modal_link/;
      $attrs .= qq{ rel="$rel"} if $rel;

      $html .= qq{
        <p><a href="$_->{'url'}" $attrs>$_->{'caption'}</a></p>};
    }

  }
  $html .= '</div>';

  return $html; 

}

sub get_json {
  my $self = shift;

  my $content = $self->_content;

  return qq{'tools':'$content'};
}


1;
