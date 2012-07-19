package EnsEMBL::Web::Component::Help::ArchiveList;

use strict;
use warnings;
no warnings "uninitialized";

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::OldLinks qw(get_archive_redirect);

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $url   = $hub->referer->{'uri'};
  my $r     = $hub->param('r');
  my $match = $url =~ m/^\//;
  
  if ($r) {
    $url  =~ s/([\?;&]r=)[^;]+(;?)/$1$r$2/;
    $url .= ($url =~ /\?/ ? ';r=' : '?r=') . $r unless $url =~ /[\?;&]r=[^;&]+/;
  }
  
  my ($path, $params) = split '\?', $url;
  my $html;
  
  $url =~ s/^\///;
  
  # is this a species page?
  
  my @check = split '/', $path;
  my ($part1, $part2, $part3, $part4, $species, $type, $action);
  
  if ($match) {
    ($part1, $part2, $part3, $part4) = ($check[1], $check[2], $check[3], $check[4]);
  } else {
    ($part1, $part2, $part3) = ($check[0], $check[1], $check[2]);
  }
  
  if ($part1 =~ /^[A-Z][a-z]+_[a-z]+$/) {
    $species = $part1;
    $type    = $part2;
    $action  = $part4 ? "$part3/$part4" : $part3;
  } else {
    $type    = $part1;
    $action  = $part2;
  }

  my (%archive, %assemblies, $initial_sets, $latest_sets, @links);
  my $count = 0;
  
  ## NB: we create an array of links in ascending date order so we can build the
  ## 'New genebuild' bit correctly, then we reverse the links for display

  if ($species) {
    %archive = %{$hub->species_defs->get_config($species, 'ENSEMBL_ARCHIVES')||{}};
    %assemblies = %{$hub->species_defs->get_config($species, 'ASSEMBLIES')||{}};
    $initial_sets = $hub->species_defs->get_config($species, 'INITIAL_GENESETS')||{};
    $latest_sets = $hub->species_defs->get_config($species, 'LATEST_GENESETS')||{};
    
    my @A = keys %archive;

    if (keys %archive) {
      my $missing = 0;
      
      if ($type =~ /\.html/ || $action =~ /\.html/) {
        foreach my $release (sort keys %archive) {
          next if $release == $hub->species_defs->ENSEMBL_VERSION;
          push @links, $self->_output_link(\%archive, $release, $url, $assemblies{$release}, $initial_sets, $latest_sets);
          $count++;
        }
      }
      
      # species home pages
      if ($type eq 'Info') {
        foreach my $release (reverse sort keys %archive) {
          next if $release == $hub->species_defs->ENSEMBL_VERSION;
          push @links, $self->_output_link(\%archive, $release, $url, $assemblies{$release}, $initial_sets, $latest_sets);
          $count++;
        }
      } else {
        my $releases = get_archive_redirect($type, $action, $hub) || [];
        
        foreach my $poss_release (reverse sort keys %archive) {
          my $release_happened = !scalar @$releases;
          
          next if $poss_release == $hub->species_defs->ENSEMBL_VERSION;
          
          foreach my $r (@$releases) {
            my ($old_view, $initial_release, $final_release, $missing_releases) = @$r;
            
            if ($poss_release < $initial_release || $poss_release > $final_release || grep $poss_release == $_, @$missing_releases) {
              $missing = 1;
              next;
            }
            
            $release_happened = 1;
          }
          
          push @links, $self->_output_link(\%archive, $poss_release, $url, $assemblies{$poss_release}, $initial_sets, $latest_sets) if $release_happened;
          $count++ unless $missing;
        }
      }
      
      $html .= "<p>Some earlier archives are available, but this view was not present in those releases</p>\n" if $missing;
    } else {
      $html .= "<p>This is a new species, so there are no archives containing equivalent data.</p>\n";
    }
  } else {
    # TODO - map static content moves
    %archive = %{$hub->species_defs->ENSEMBL_ARCHIVES};
    
    $html .= "<ul>\n";
    
    foreach my $poss_release (reverse sort keys %archive) {
      next if $poss_release == $hub->species_defs->ENSEMBL_VERSION;
      
      $html .= $self->_output_link(\%archive, $poss_release, $url);
    }
    
    $html .= "</ul>\n";
  }
 
  if ($count) {
    $html .= qq(
      <p>The following archives are available for this page:</p>
        <ul>
      );
    $html .= join(' ', @links);
    $html .= qq(
        </ul>
      );
  }
 
  $html .= '<p><a href="/info/website/archives/" class="cp-external">More information about the Ensembl archives</a></p>';

  return $html;
}

sub _output_link {
  my ($self, $archive, $release, $url, $assembly, $initial_sets, $latest_sets) = @_;
  
  my $sitename = $self->hub->species_defs->ENSEMBL_SITETYPE;
  my $date  = $archive->{$release};
  my $month = substr $date, 0, 3;
  my $year  = substr $date, 3, 4;

  my $release_date = $month.' '.$year;
  my $initial_geneset = $initial_sets->{$release} || ''; 
  my $current_geneset = $latest_sets->{$release} || '';
  my $previous_geneset = $latest_sets->{$release-1} || '';
 
  my $string = qq(<li><a href="http://$date.archive.ensembl.org/$url" class="cp-external">$sitename $release: $month $year</a>);
  if ($assembly) {
    $string .= sprintf ' (%s)', $assembly;
  }

  if ($current_geneset) {
    if ($current_geneset eq $initial_geneset) {
      $string .= sprintf ' - gene set updated %s', $current_geneset;
    }
    else {
      if ($current_geneset ne $previous_geneset) {
        $string .= sprintf ' - patched/updated gene set %s', $current_geneset;
      }
    }
  }
  $string .= '</li>';
  return $string;
}

1;
