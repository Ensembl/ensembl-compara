# $Id$

package EnsEMBL::Web::Component::Gene::Compara_Portal;

use strict;

use base qw(EnsEMBL::Web::Component::Portal);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $availability = $self->object->availability;
  my $location     = $hub->url({ type => 'Location',  action => 'Compara' });

  $self->{'buttons'} = [
    { title => 'Genomic alignments', img => 'compara_align', url => $availability->{'has_alignments'} ? $hub->url({ action => 'Compara_Alignments' }) : '' },
    { title => 'Gene tree',          img => 'compara_tree',  url => $availability->{'has_gene_tree'}  ? $hub->url({ action => 'Compara_Tree'       }) : '' },
    { title => 'Orthologues',        img => 'compara_ortho', url => $availability->{'has_orthologs'}  ? $hub->url({ action => 'Compara_Ortholog'   }) : '' },
    { title => 'Paralogues',         img => 'compara_para',  url => $availability->{'has_paralogs'}   ? $hub->url({ action => 'Compara_Paralog'    }) : '' },
    { title => 'Families',           img => 'compara_fam',   url => $availability->{'family'}         ? $hub->url({ action => 'Family'             }) : '' },
  ];

  my $html  = $self->SUPER::content;
     $html .= qq{<p class="center">More views of comparative genomics data, such as multiple alignments and synteny, are available on the <a href="$location">Location</a> page for this gene.</p>};

  return $html;
}

1;
