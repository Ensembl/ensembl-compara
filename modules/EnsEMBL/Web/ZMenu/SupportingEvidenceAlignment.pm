=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::SupportingEvidenceAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $hit_name   = $hub->param('id');
  my $hit_db     = $self->object->get_sf_hit_db_name($hit_name);
  my $link_name  = $hit_db eq 'RFAM' ? [ split '-', $hit_name ]->[0] : $hit_name;

  #Uniprot can't deal with versions in accessions
  if ($hit_db =~ /^Uniprot/){
    $link_name =~ s/(\w*)\.\d+/$1/;
  }
  ## And ENA adds version numbers that aren't used in URL
  if ($hit_db eq 'EMBL') {
    $link_name =~ s/#\w+//;
  }

  my $hit_length = $hub->param('hit_length');
  my $hit_url    = $hub->get_ExtURL_link($link_name, $hit_db, $link_name);

  my $tsid       = $hub->param('t_version') ? $hub->param('t').".".$hub->param('t_version') : $hub->param('t');
  my $esid       = $hub->param('exon');

  $self->caption("$hit_name ($hit_db)");

  if ($esid) {
    my $exon_length = $hub->param('exon_length');

    $self->add_entry({ label_html => "Entry removed from $hit_db" }) if $hub->param('er');

    $self->add_entry({
      type  => 'View alignments',
      label => "$esid ($tsid)",
      link  => $hub->url({
        type     => 'Transcript',
        action   => 'SupportingEvidence',
        function => 'Alignment',
        sequence => $hit_name,
        exon     => $esid
      })
    });

    $self->add_entry({
      type    => 'View record',
      label   => $hit_name,
      link    => $hit_url,
      abs_url => 1
    });

    $self->add_entry({
      type  => 'Exon length',
      label => "$exon_length bp"
    });

    if ($hub->param('five_end_mismatch')) {
      $self->add_entry({
        type  => "5' mismatch",
        label => $hub->param('five_end_mismatch') . ' bp'
      });
    }

    if ($hub->param('three_end_mismatch')) {
      $self->add_entry({
        type  => "3' mismatch",
        label => $hub->param('three_end_mismatch') . ' bp'
      });
    }
  } else {
    $self->add_entry({
      type    => 'View record',
      labe    => $hit_name,
      link    => $hit_url,
      abs_url => 1
    });
  }
}

1;
