package EnsEMBL::Web::Document::HTML::TOC;

### Generates full table of contents for documentation (/info/)

use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Document::HTML);

our @page_list;

sub render {
  my $self = shift;
  my $html;

  my $tree = $ENSEMBL_WEB_REGISTRY->species_defs->STATIC_INFO;
  $self->_traverse_tree($tree);

  ## Create A-Z listing
  my @AtoZ = sort { $a->{'title'} cmp $b->{'title'} } @page_list;
  my $previous = '-';

  foreach my $page (@AtoZ) {
    my $title = $page->{'title'};
    my $url   = $page->{'url'};
    my $initial = substr($title, 0, 1);
    if ($initial ne $previous) {
      $html .= "<h3>$initial</h3>\n";
    }
    $html .= qq(<p><a href="$url">$title</a></p>\n);
    $previous = $initial;
  }

  return $html;
}

sub _traverse_tree {
  my ($self, $node, $path) = @_;

  my (@sections, $section);
  foreach $section (keys %$node) {
    push (@sections, $section) if ref($node->{$section}) eq 'HASH';
  }

  foreach $section (@sections) {
    next if $section =~ /^_/;
    my $subsection = $node->{$section};
    next unless keys %$subsection;

    my $title = $subsection->{'_title'} || ucfirst($section);
    ## Remove articles from beginning of page titles, for better ordering
    $title =~ s/^The (.)/$1/;
    $title =~ s/^A (.)/$1/;
    ## Compensate for article removal and random whitespace
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;
    $title = ucfirst($title);
    
    my $url = $subsection->{'_path'} || $path.$section;
    push @page_list, {'title' => $title, 'url'=> $url} unless $subsection->{'_nolink'};
    $self->_traverse_tree($subsection, $subsection->{'_path'});
  }

}

1;
