# $Id$

package EnsEMBL::Web::Component::Gene::Compara_Portal;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $avail     = $self->object->availability;

  my ($align_url, $tree_url, $ortho_url, $para_url, $fam_url);
  if ($avail->{'has_alignments'}) {
    $align_url   = $hub->url({'action' => 'Compara_Alignments'});
  }
  if ($avail->{'has_gene_tree'}) {
    $tree_url   = $hub->url({'action' => 'Compara_Tree'});
  }
  if ($avail->{'has_orthologs'}) {
    $ortho_url  = $hub->url({'action' => 'Compara_Ortholog'});
  }
  if ($avail->{'has_paralogs'}) {
    $para_url   = $hub->url({'action' => 'Compara_Paralog'});
  }
  if ($avail->{'family'}) {
    $fam_url    = $hub->url({'action' => 'Family'});
  }

  my @buttons = (
    {'title' => 'Genomic alignments', => 'img' => '/img/compara_align.gif', 'url' => $align_url},
    {'title' => 'Gene tree',          => 'img' => '/img/compara_tree.gif',  'url' => $tree_url},
    {'title' => 'Orthologues',        => 'img' => '/img/compara_ortho.gif', 'url' => $ortho_url},
    {'title' => 'Paralogues',         => 'img' => '/img/compara_para.gif',  'url' => $para_url},
    {'title' => 'Families',           => 'img' => '/img/compara_fam.gif',   'url' => $fam_url},
  );

  my $html = qq(
    <div class="centered">
  );
  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img = $button->{'img'};
    my $url = $button->{'url'};
    if ($url) {
      $html .= qq(<a href="$url" title="$title"><img src="$img" class="portal" alt="" /></a>);
    }
    else {
      $title .= ' (NOT AVAILABLE)';
      $html .= qq(<img src="$img" class="portal" alt="" title="$title" />);
    }
  }
  $html .= qq(
    </div>
  );
 
  return $html;
}


1;
