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
  
  if ($species) {
    $archives     = $species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {};
    $assemblies   = $species_defs->get_config($species, 'ASSEMBLIES')       || {};
    $initial_sets = $species_defs->get_config($species, 'INITIAL_GENESETS') || {};
    $latest_sets  = $species_defs->get_config($species, 'LATEST_GENESETS')  || {};
    
    if (scalar grep $_ != $current, keys %$archives) {
      if ($type =~ /\.html/ || $action =~ /\.html/) {
        foreach (sort keys %$archives) {
          next if $_ == $current;
          push @links, $self->output_link($archives, $_, $url, $assemblies->{$_}, $initial_sets, $latest_sets);
        }
      }
      
      # species home pages
      if ($type eq 'Info') {
        foreach (reverse sort keys %$archives) {
          next if $_ == $current;
          push @links, $self->output_link($archives, $_, $url, $assemblies->{$_}, $initial_sets, $latest_sets);
        }
      } else {
        my $releases = get_archive_redirect($type, $action, $hub) || [];
        my $missing  = 0;
        
        foreach my $poss_release (reverse sort keys %$archives) {
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
          
          push @links, $self->output_link($archives, $poss_release, $url, $assemblies->{$poss_release}, $initial_sets, $latest_sets) if $release_happened;
        }
        
        $html .= '<p>Some earlier archives are available, but this view was not present in those releases.</p>' if $missing;
      }
    } else {
      $html .= '<p>This is a new species, so there are no archives containing equivalent data.</p>';
    }
  } else { # TODO - map static content moves
    my $archives = $species_defs->ENSEMBL_ARCHIVES;
       @links    = map { $_ == $current ? () : $self->output_link($archives, $_, $url) } reverse sort keys %$archives;
  }
 
  $html .= sprintf '<p>The following archives are available for this page:</p><ul>%s</ul>', join '', @links if scalar @links;
  $html .= '<p><a href="/info/website/archives/" class="cp-external">More information about the Ensembl archives</a></p>';

  return $html;
}

sub output_link {
  my ($self, $archives, $release, $url, $assembly, $initial_sets, $latest_sets) = @_;
  my $sitename         = $self->hub->species_defs->ENSEMBL_SITETYPE;
  my $date             = $archives->{$release};
  my $month            = substr $date, 0, 3;
  my $year             = substr $date, 3, 4;
  my $release_date     = "$month $year";
  my $initial_geneset  = $initial_sets->{$release}    || ''; 
  my $current_geneset  = $latest_sets->{$release}     || '';
  my $previous_geneset = $latest_sets->{$release - 1} || '';
 
  my $string  = qq{<li><a href="http://$date.archive.ensembl.org/$url" class="cp-external">$sitename $release: $month $year</a>};
     $string .= sprintf ' (%s)', $assembly if $assembly;

  if ($current_geneset) {
    if ($current_geneset eq $initial_geneset) {
      $string .= sprintf ' - gene set updated %s', $current_geneset;
    } elsif ($current_geneset ne $previous_geneset) {
      $string .= sprintf ' - patched/updated gene set %s', $current_geneset;
    }
  }
  
  $string .= '</li>';
  
  return $string;
}

1;
