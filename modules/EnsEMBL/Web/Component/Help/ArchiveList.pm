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

package EnsEMBL::Web::Component::Help::ArchiveList;

use strict;
use warnings;
no warnings "uninitialized";

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::OldLinks qw(get_archive_redirect);
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $current      = $species_defs->ENSEMBL_VERSION;
  my $url          = $hub->referer->{'uri'};
  my $r            = $hub->param('r');
  my $match        = $url =~ m/^\//;
  my $count        = 0;
  my ($html, $archives, $assemblies, $initial_sets, $latest_sets, @links);
  
  if ($r) {
    $url  =~ s/([\?;&]r=)[^;]+(;?)/$1$r$2/;
    $url .= ($url =~ /\?/ ? ';r=' : '?r=') . $r unless $url =~ /[\?;&]r=[^;&]+/;
  }
  
  my ($path, $params) = split '\?', $url;
  
  $url =~ s/^\///;
  
  # is this a species page?
  
  my @check = split '/', $path;
  my ($part1, $part2, $part3, $part4, $species, $type, $action);
  
  if ($match) {
    ($part1, $part2, $part3, $part4) = ($check[1], $check[2], $check[3], $check[4]);
  } else {
    ($part1, $part2, $part3) = ($check[0], $check[1], $check[2]);
  }
  
  if ($species_defs->valid_species($part1)) {
    $species = $part1;
    $type    = $part2;
    $action  = $part4 ? "$part3/$part4" : $part3;
  } else {
    $type    = $part1;
    $action  = $part2;
  }
  
  ## NB: we create an array of links in ascending date order so we can build the
  ## 'New genebuild' bit correctly, then we reverse the links for display
  
  my $adaptor   = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($self->hub);
  if ($species) {
    $archives     = $adaptor->fetch_archives_by_species($species); 
    if (scalar grep $_ != $current, keys %$archives) {
      if ($path =~ /\.html$/) {
        ## Static (or pseudostatic) pages
        foreach (sort {$b <=> $a} keys %$archives) {
          next if $_ == $current;
          push @links, $self->output_link($archives, $_, $url);
        }
      }
      elsif ($type eq 'Info') {
        # species home pages
        foreach (sort {$b <=> $a} keys %$archives) {
          next if $_ == $current;
          push @links, $self->output_link($archives, $_, $url);
        }
      } else {
        my $releases = get_archive_redirect($type, $action, $hub) || [];
        my $missing  = 0;
        
        foreach my $poss_release (sort {$b <=> $a} keys %$archives) {
          next if $poss_release == $current;
          
          my $release_happened = 0;
          
          foreach my $r (@$releases) {
            my ($old_view, $initial_release, $final_release, $missing_releases) = @$r;
            
            if ($poss_release < $initial_release || ($final_release && $poss_release > $final_release) || grep $poss_release == $_, @$missing_releases) {
              $missing = 1;
              next;
            }
            
            $release_happened = 1;
          }
          
          push @links, $self->output_link($archives, $poss_release, $url) if $release_happened;
        }
        
        $html .= '<p>Some earlier archives are available, but this view was not present in those releases.</p>' if $missing;
      }
    } else {
      $html .= '<p>This is a new species, so there are no archives containing equivalent data.</p>';
    }
  } else { # TODO - map static content moves
    my $archives = $adaptor->fetch_archives_by_species($species_defs->ENSEMBL_PRIMARY_SPECIES); 
    push @links, map { $_ == $current ? () : $self->output_link($archives, $_, $url) } sort {$b <=> $a} keys %$archives;
  }
  $html .= sprintf '<p>The following archives are available for this page:</p><ul>%s</ul>', join '', @links if scalar @links;
  $html .= '<p><a href="/info/website/archives/" class="cp-external">More information about the Ensembl archives</a></p>';

  return $html;
}

sub output_link {
  my ($self, $archives, $release, $url) = @_;
  my $sitename         = $self->hub->species_defs->ENSEMBL_SITETYPE;
  my $assembly         = $archives->{$release}{'assembly'};
  my $date             = $archives->{$release}{'archive'};
  my $month            = substr $date, 0, 3;
  my $year             = substr $date, 3, 4;
  my $release_date     = "$month $year";
  my $initial_geneset  = $archives->{$release}{'initial_release'}  || ''; 
  my $current_geneset  = $archives->{$release}{'last_geneset'}  || '';
  my $previous_geneset = $archives->{$release - 1}{'last_geneset'} || '';
 
  my $string;
  if ($archives->{$release}{'date'}) {
    $string = qq{<li><a href="http://$date.archive.ensembl.org/$url" class="cp-external">$sitename $release: $month $year</a>};
    $string .= sprintf ' (%s)', $assembly if $assembly;

    if ($current_geneset) {
      if ($current_geneset eq $initial_geneset) {
        $string .= sprintf ' - gene set updated %s', $current_geneset;
      } elsif ($current_geneset ne $previous_geneset) {
        $string .= sprintf ' - patched/updated gene set %s', $current_geneset;
      }
    }
  }
  else {
    $string = sprintf('<li><strong><a href="http://%s.ensembl.org">Ensembl %s</a></strong>: %s', lc($date), $date, $archives->{$release}{'description'});
  }
 
  $string .= '</li>';
  
  return $string;
}

1;
