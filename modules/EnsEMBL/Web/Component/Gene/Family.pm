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

package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $cdb            = shift || $hub->param('cdb') || 'compara';
  my $object         = $self->object;
  my $sp             = $hub->species_defs->DISPLAY_NAME || $hub->species_defs->species_label($object->species);
  my $families       = $object->get_all_families($cdb);
  my $gene_stable_id = $object->stable_id;
  my ($gene_name)    = $object->display_xref;
  my $gene_label = $gene_name || $gene_stable_id;

  my $ckey = $cdb eq 'compara_pan_ensembl' ? '_pan_compara' : '';

  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'id asc' ] });

  $table->add_columns(
    { key => 'id',          title => 'Family ID',                            width => '20%', align => 'left', sort => 'html'   },
    { key => 'annot',       title => 'Consensus annotation',                 width => '30%', align => 'left', sort => 'string' },
    { key => 'proteins', title => "Other $gene_label proteins in this family", width => '30%', align => 'left', sort => 'html'   },
    { key => 'jalview',     title => 'Multiple alignments',                  width => '20%', align => 'left', sort => 'none'   }
  );

  foreach my $family_id (sort keys %$families) {
    my $family     = $families->{$family_id};
    my $row        = { id => sprintf qq(<a href="%s">$family_id</a><br />), $hub->url({ species => 'Multi', type => "Family$ckey", action => 'Details', fm => $family_id, __clear => 1 })};
    my $gene_count = scalar @{$families->{$family_id}{'info'}{'genes'}};
    my $url_params = { function => "Genes$ckey", family => $family_id, g => $gene_stable_id, cdb => $cdb };
    my $label;

    if ($gene_count) {
      $label      =  $gene_count > 1 ? 'genes' : 'gene';
      $row->{'id'}  .= sprintf('(<a href="%s">%s %s</a>)', $hub->url($url_params), $gene_count, $label);
    }
    $row->{'annot'}        = $families->{$family_id}{'info'}{'description'};

    $row->{'proteins'}  = '<ul class="compact">';
    foreach my $t ( @{$family->{'transcripts'}}) {
      (my $name) = $t->display_xref;
      $label = $name ? ' ('.$name.')' : '';
      my $url = $hub->url({type => 'Transcript', action => 'ProteinSummary', t => $t->stable_id });
      $row->{'proteins'} .= $t->Obj->translation ? sprintf '<li><a href="%s">%s</a>%s</li>', $url, $t->Obj->translation->stable_id, $label : '';
    }
    $row->{'transcripts'} .= '</ul>';

    my $fam_obj         = $object->create_family($family_id, $cdb);
    my $ensembl_members = $fam_obj->get_Member_by_source('ENSEMBLPEP');

    my @all_pep_members;
    push @all_pep_members, @$ensembl_members;
    push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SPTREMBL')};
    push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SWISSPROT')};

    $row->{'jalview'} = $self->jalview_link($family_id, 'Ensembl', $ensembl_members, $cdb) . $self->jalview_link($family_id, '', \@all_pep_members, $cdb) || 'No alignment has been produced for this family.';

    $table->add_row($row);
  }
  
  return $table->render;
}

sub jalview_link {
  my ($self, $family, $type, $refs, $cdb) = @_;
  my $count = @$refs;
  (my $ckey = $cdb) =~ s/compara//;
  my $url   = $self->hub->url({ function => "Alignments$ckey", family => $family });
  
  return qq{<p class="space-below">$count $type members of this family <a href="$url">JalView</a></p>};
}

1;
