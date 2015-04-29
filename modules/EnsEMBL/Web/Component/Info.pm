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

package EnsEMBL::Web::Component::Info;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use parent qw(EnsEMBL::Web::Component::Shared);

sub assembly_dropdown {
  my $self              = shift;
  my $hub               = $self->hub;
  my $adaptor           = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my $species           = $hub->species;
  my $archives          = $adaptor->fetch_archives_by_species($species);
  my $species_defs      = $hub->species_defs;
  my $pre_species       = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  my $done_assemblies   = { map { $_ => 1 } $species_defs->ASSEMBLY_NAME, $species_defs->ASSEMBLY_VERSION };

  my @assemblies;

  foreach my $version (reverse sort {$a <=> $b} keys %$archives) {

    my $archive           = $archives->{$version};
    my $archive_assembly  = $archive->{'version'};

    if (!$done_assemblies->{$archive_assembly}) {

      my $desc      = $archive->{'description'} || sprintf '(%s release %s)', $species_defs->ENSEMBL_SITETYPE, $version;
      my $subdomain = ((lc $archive->{'archive'}) =~ /^[a-z]{3}[0-9]{4}$/) ? lc $archive->{'archive'}.'.archive' : lc $archive->{'archive'};

      push @assemblies, {
        url      => sprintf('http://%s.ensembl.org/%s/', $subdomain, $species),
        assembly => $archive_assembly,
        release  => $desc,
      };

      $done_assemblies->{$archive_assembly} = 1;
    }
  }

  ## Don't link to pre site on archives, as it changes too often
  push @assemblies, { url => "http://pre.ensembl.org/$species/", assembly => $pre_species->{$species}[1], release => '(Ensembl pre)' } if ($pre_species->{$species} && $species_defs->ENSEMBL_SITETYPE !~ /archive/i);

  my $html = '';

  if (scalar @assemblies) {
    if (scalar @assemblies > 1) {
      $html .= qq(<form action="/$species/redirect" method="get"><select name="url">);
      $html .= qq(<option value="$_->{'url'}">$_->{'assembly'} $_->{'release'}</option>) for @assemblies;
      $html .= '</select> <input type="submit" name="submit" class="fbutton" value="Go" /></form>';
    } else {
      $html .= qq(<ul><li><a href="$assemblies[0]{'url'}" class="nodeco">$assemblies[0]{'assembly'}</a> $assemblies[0]{'release'}</li></ul>);
    }
  }

  return $html;
}

1;
