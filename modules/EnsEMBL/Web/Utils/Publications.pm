=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::Publications;

## Given the ID of a publication, retrieve details from EuropePMC REST service 

use EnsEMBL::Web::REST;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(get_pub_details parse_file_contents);

sub get_pub_details {
  my ($id, $hub, $rest) = @_;
  my $pub_text  = '';
  my $full_id   = $id;

  if ($id =~ /^PMC/) {
    $id =~ s/PMC//;
  }

  my $endpoint = "search?format=json&query=$id";
  my $response = $rest->fetch($endpoint);
  if ($response && $response->{'resultList'}) {  
    foreach my $publication (@{$response->{'resultList'}{'result'}}) {
      next unless ($publication->{'pmcid'} && $publication->{'pmcid'} eq $full_id);

      ## Format publication info
      my $title   = $publication->{'title'};
      my $link    = $hub->get_ExtURL('EUROPE_PMC', $publication->{'id'});
      my $authors = $publication->{'authorString'};
      my $journal = sprintf '<i>%s %s</i>',
                              $publication->{'journalTitle'},
                              $publication->{'journalVolume'};
      if ($publication->{'issue'}) {
        $journal .= sprintf ' (%s)', $publication->{'issue'};
      }

      $pub_text = sprintf '<a href="%s">%s</a><br/>%s. %s',
                            $link, $title, $authors, $journal;
      last;
    }
  }
  return $pub_text;
}

sub parse_file_contents {
  my ($content, $hub) = @_;

  my $rest_url = $hub->species_defs->EUROPE_PMC_REST;
  return $content unless $rest_url;
  $rest = EnsEMBL::Web::REST->new($hub, $rest_url);
  return $content unless $rest;

  my $converted;
  my @lines = split(/\n/, $content);
  foreach my $line (@lines) {
    if ($line =~ /<li>(PMC\d+)/) {
      my $id = $1;
      my $pub_content = get_pub_details($id, $hub, $rest);
      $line =~ s/$id/$pub_content/;
    }
    $converted .= $line."\n";
  }
  return  $converted;
}

1;
