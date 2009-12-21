package EnsEMBL::Web::Document::HTML::TOC;

### Generates full table of contents for documentation (/info/)

use strict;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  
  my $tree = $ENSEMBL_WEB_REGISTRY->species_defs->STATIC_INFO;
  my @page_list;
  
  $self->_traverse_tree(\@page_list, $tree);

  ## Create A-Z listing
  my @AtoZ = sort { $a->{'title'} cmp $b->{'title'} } @page_list;
  my $previous = '-';
  my $html;

  foreach my $page (@AtoZ) {
    my $title   = $page->{'title'};
    my $url     = $page->{'url'};
    my $initial = substr $title, 0, 1;
    
    $html .= "<h3>$initial</h3>\n" if $initial ne $previous;
    $html .= qq(<p><a href="$url">$title</a></p>\n);
    
    $previous = $initial;
  }

  return $html;
}

sub _traverse_tree {
  my ($self, $page_list, $node, $path) = @_;

  my (@sections, $section);
  
  foreach $section (keys %$node) {
    push @sections, $section if ref $node->{$section} eq 'HASH';
  }

  foreach $section (@sections) {
    next if $section =~ /^_/;
    
    my $subsection = $node->{$section};
    
    next unless keys %$subsection;

    my $title = $subsection->{'_title'} || ucfirst $section;
    
    ## Remove articles from beginning of page titles, for better ordering
    $title =~ s/^The (.)/$1/;
    $title =~ s/^A (.)/$1/;
    
    ## Compensate for article removal and random whitespace
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;
    
    $title = ucfirst $title;
    
    my $url = $subsection->{'_path'} || $path . $section;
    
    push @$page_list, { title => $title, url => $url } unless $subsection->{'_nolink'};
    
    $self->_traverse_tree($page_list, $subsection, $subsection->{'_path'});
  }
}

1;
