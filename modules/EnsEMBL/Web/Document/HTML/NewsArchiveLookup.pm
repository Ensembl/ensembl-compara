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

package EnsEMBL::Web::Document::HTML::NewsArchiveLookup;

### This module outputs a form to select a news archive (Document::HTML::NewsArchive), 
### The functionality was split out in several subs, to make plugin development easier

use strict;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self            = shift;
  my $hub             = $self->hub;
  my $id              = $hub->param('id');
  my $ensembl_version = $hub->species_defs->ENSEMBL_VERSION;
  return unless $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE') < $ensembl_version;

  my $adaptor         = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my @releases;
  if (! $adaptor->fetch_releases) {
    $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  }
  my @releases        = $self->get_releases($adaptor, $hub->species_defs->ENSEMBL_VERSION);
  my $html;

  if (@releases) {
    $html = '<h2 id="archive_lookup">Archive of previous news</h2>';
    $html .= $self->format_release($_, $id) for @releases;
    $html  = qq{
      <form action="/info/website/news.html" method="get">
        <select name="id">
          $html
        </select> <input type="submit" name="submit" value="Go" />
      </form>
    };
  }
  
  return $html;
}

sub get_releases {
  my ($self, $adaptor, $ensembl_version) = @_;
  return sort { $b->{'id'} <=> $a->{'id'} } grep { $_->{'id'} != $ensembl_version && $_->{'id'} <= $ensembl_version } @{$adaptor->fetch_releases};
}

sub format_release {
  my ($self, $release, $id) = @_;

  my $html = qq(<option value="$release->{'id'}");
  $html   .= ' selected="selected"' if $release->{'id'} == $id;
  $html   .= sprintf '>Release %s (%s)</option>', $release->{'id'}, $release->{'date'};
  
  return $html;
}

1;
