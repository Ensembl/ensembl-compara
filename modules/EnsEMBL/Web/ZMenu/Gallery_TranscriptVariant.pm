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

package EnsEMBL::Web::ZMenu::Gallery_TranscriptVariant;

## Popup menu for variant gallery entries that map to more than one transcript

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::REST;

use parent qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self          = shift;
  my $hub           = $self->hub;

  $self->caption('Select a transcript');

  ## Get consequences of this variant
  my $rest = EnsEMBL::Web::REST->new($hub);
  my $endpoint = sprintf '/vep/%s/id/%s', $hub->species, $hub->param('v');
  my $vep_output = $rest->fetch($endpoint);
  #use Data::Dumper; warn Dumper($vep_output);
  my $consequences = {};
  unless (ref($vep_output) eq 'HASH' && $vep_output->{'error'}) {
    foreach (@$vep_output) {
      foreach my $c (@{$_->{'transcript_consequences'}||[]}) {
        (my $description = $c->{'consequence_terms'}[0]) =~ s/_/ /g;
        $consequences->{$c->{'transcript_id'}} = $description;
      }
    }
  }
  my $has_consequences = keys %$consequences;

  my $params = {};
  ## Unpack the parameters for the link to the view
  foreach (grep /link_/, $hub->param) {
    (my $p = $_) =~ s/link_//;
    $params->{$p} = $hub->param($_);
  }

  my $table = '
      <table class="zmenu" cellpadding="0" cellspacing="0">
        <tr class="subheader"><th>Stable ID</th><th>Biotype</th><th>Variant consequence</th></tr>
    ';

  foreach (split(':', $hub->param('transcripts'))) {
    my ($id, $biotype) = split('_', $_);
    $params->{'t'} = $id;
    $table .= sprintf('<tr><td><a href="%s">%s</td><td>%s</td><td>%s</td></tr>', 
                        $hub->url($params), $id, $biotype, $consequences->{$id});
  }

  $table .= '</table>';

  $self->add_entry({ label_html => $table });
}

1;
