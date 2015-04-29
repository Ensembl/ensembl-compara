=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
    $list{$initial}{uc($desc)} .= sprintf('<p><a href="/%s/Phenotype/Locations?ph=%s">%s</a></p>', $self->hub->species, $phen->dbID, ucfirst($desc));
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
