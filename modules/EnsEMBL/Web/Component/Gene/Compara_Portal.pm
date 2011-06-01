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
    {'title' => 'Genomic alignments', => 'img' => 'compara_align', 'url' => $align_url},
    {'title' => 'Gene tree',          => 'img' => 'compara_tree',  'url' => $tree_url},
    {'title' => 'Orthologues',        => 'img' => 'compara_ortho', 'url' => $ortho_url},
    {'title' => 'Paralogues',         => 'img' => 'compara_para',  'url' => $para_url},
    {'title' => 'Families',           => 'img' => 'compara_fam',   'url' => $fam_url},
  );

  my $html = qq(
    <div class="centered">
  );
  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img = $button->{'img'};
    my $url = $button->{'url'};
    if ($url) {
      $img  .= '.gif';
      $html .= qq(<a href="$url" title="$title"><img src="/img/$img" class="portal" alt="" /></a>);
    }
    else {
      $img   .= '_off.gif';
      $title .= ' (NOT AVAILABLE)';
      $html  .= qq(<img src="/img/$img" class="portal" alt="" title="$title" />);
    }
  }

  my $url = $self->hub->url({'type'=>'Location', 'action'=>'Compara'});
  $html .= qq(<p>More views of comparative genomics data, such as multiple alignments and synteny, are available on the <a href="$url">Location</a> page for this gene.</p>);
 
  $html .= qq(
    </div>
  );

  return $html;
}


1;
