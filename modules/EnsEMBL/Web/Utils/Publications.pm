=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

## Given the ID of a publication, or a specific query string, 
## retrieve details from EuropePMC REST service 

## Supported identifiers:
##
## PMC123456
## MED/123456
## PPR00123


use strict;

use URI::Escape qw(uri_escape);
use EnsEMBL::Web::REST;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(parse_publication_list get_publication_by_id get_publications_by_query_string);

sub parse_publication_list {
  my ($content, $hub) = @_;

  my $rest_url = $hub->species_defs->EUROPE_PMC_REST;
  return $content unless $rest_url;
  my $rest = EnsEMBL::Web::REST->new($hub, $rest_url);
  return $content unless $rest;

  my $converted;
  my @lines = split(/\n/, $content);
  foreach my $line (@lines) {
    if ($line =~ m#<li>([A-Z]{3})(/*)(\d+)#) {
      my ($source, $separator, $id) = ($1, $2, $3);
      my $pub_content = get_publication_by_id($rest, $source, $id, $hub);
      $line =~ s/$source$separator$id/$pub_content/;
    }
    $converted .= $line."\n";
  }
  return  $converted;
}

sub get_publication_by_id {
## Get a single publication using an ID
  my ($rest, $source, $id, $hub) = @_;
  my $pub_text  = '';
  my $full_id   = $id;
  $source       = uc $source;

  ## Format parameters for non-PMC ids
  my $extra_params = '';
  unless ($source eq 'PMC') {
    $full_id   = $source.$id if $source eq 'PPR';
    $id = "EXT_ID:$full_id";
    $extra_params = "&resultType=core&src=$source";
  }

  my $endpoint = "search?query=$id&format=json$extra_params";
  my $publications = _get_publications($rest, $endpoint, $hub);
  my $pub_text;

  ## Could be multiple hits on an ID query, but we only want the best match
  foreach my $publication (@$publications) {
    next unless (($publication->{'pmcid'} && $publication->{'pmcid'} eq "PMC$id")
              || ($publication->{'source'} eq $source && $publication->{'id'} eq $full_id)
              );

    ## Format publication info
    my $title   = $publication->{'title'};
    my $link    = $hub->get_ExtURL('EUROPE_PMC', {'SOURCE' => $source, 'ID' => $full_id});
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
  return $pub_text;  
}

sub get_publications_by_query_string {
## Get an array of hashes containing publication details
  my ($query, $hub) = @_;

  my $rest_url = $hub->species_defs->EUROPE_PMC_REST;
  return [] unless $rest_url;
  my $rest = EnsEMBL::Web::REST->new($hub, $rest_url);
  return [] unless $rest;

  my $endpoint = "search?format=json&query=$query";
  my $results = _get_publications($rest, $endpoint, $hub);
  
  my $publications = [];

  foreach my $publication (@$results) {
    my $pub = {
                'title'   => $publication->{'title'},
              };
    ## Link back to Europe PMC
    my $full_id   = $publication->{'id'};
    my $source    = $publication->{'source'};
    $pub->{'pubmed_id'} = sprintf '<a href="%s" style="white-space:nowrap">%s</a>', $hub->get_ExtURL('EUROPE_PMC', {'SOURCE' => $source, 'ID' => $full_id}), $full_id;

    ## Insert links into author string
    my $authors = $publication->{'authorString'};
    my @authors = split /\s*,\s+|\s*and\s+/, $publication->{authorString};
    $pub->{'authors'} = join (', ', map {sprintf '<a href="http://europepmc.org/search?page=1&query=%s">%s</a>', uri_escape(qq(AUTH:"$_")), $_  } @authors);

    my $journal;
    if ($publication->{'pubType'} && $publication->{'pubType'} eq 'preprint') {
      $journal = sprintf 'preprint (%s)', $publication->{'pubYear'}; 
    }
    else {
      $journal = sprintf '<i>%s %s</i>',
                          $publication->{'journalTitle'},
                          $publication->{'journalVolume'};
      if ($publication->{'issue'}) {
        $journal .= sprintf ' (%s)', $publication->{'issue'};
      }
      $journal .= ' '.$publication->{'pubYear'};
    }
    $pub->{'journal'} = $journal;

    push @$publications, $pub;
  }

  return $publications;
}

sub _get_publications {
  my ($rest, $endpoint, $hub, $format) = @_;
  my $response = $rest->fetch($endpoint);
  
  return ($response->{'resultList'}{'result'} || []); 
}

1;
