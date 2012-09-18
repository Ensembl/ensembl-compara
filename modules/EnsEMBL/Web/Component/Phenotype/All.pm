package EnsEMBL::Web::Component::Phenotype::All;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my @phenotypes = @{$object->get_all_phenotypes};
  my (%index, @toc, %list);

  foreach my $phen (@phenotypes) {
    my $desc    = $phen->description;
    $desc =~ s/A(n?) //; ## get rid of leading indefinite article!
    my $initial = uc(substr($desc, 0, 1));
    ## NB - descriptions are a nasty mix of uppercase and mixed case,
    ## so we need to be able to sort them in a case-insensitive manner
    unless ($index{$initial}) {
      push @toc, sprintf('<a href="#phenotypes-%s">%s</a>', $initial, $initial);
    }
    $list{$initial}{uc($desc)} .= sprintf('<p><a href="/%s/Phenotype/Locations?ph=%s">%s</a></p>', $self->hub->species, $phen->id, ucfirst($desc));
    $index{$initial}++;
  } 

  my $html = '<p id="toc_top" style="margin:16px">'.join(' | ', sort @toc).'</p>';
  my $started = 0;
  foreach my $i (sort keys %list) {
    $html .= '<p style="text-align:right"><a href="#toc_top">Top</a></p>' if $started;
    $html .= sprintf('<h2 id="phenotypes-%s" style="margin-top:16px">%s</h2>', $i, $i);
    foreach my $j (sort keys %{$list{$i}}) {
      $html .= $list{$i}{$j};
    }
    $started = 1;
  }
  return $html;
}

1;
