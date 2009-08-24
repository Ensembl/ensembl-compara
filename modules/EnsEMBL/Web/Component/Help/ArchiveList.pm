package EnsEMBL::Web::Component::Help::ArchiveList;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(unescape);

use EnsEMBL::Web::OldLinks qw(get_archive_redirect);

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $html;
  my $url = unescape($object->param('url'));
  $url =~ s#^/##;
  
  # is this a species page?
  my ($path, $params) = split '\?', $object->param('url');
  my @check = split '/', $path;
  my ($part1, $part2, $part3, $part4, $species, $type, $action);
  
  if ($object->param('url') =~ m#^/#) {
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

  my %archive;
  
  if ($species) {
    %archive = %{$object->species_defs->get_config($species, 'ENSEMBL_ARCHIVES')};
    
    if (keys %archive) {
      $html .= '
      <p>The following archives are available for this page:</p>
        <ul>
      ';
      
      my $missing = 0;
      
      if ($type =~ /\.html/ || $action =~ /\.html/) {
        foreach my $release (reverse sort keys %archive) {
          next if $release == $object->species_defs->ENSEMBL_VERSION;
          $html .= $self->_output_link(\%archive, $release, $url);
        }
      }
      
      # species home pages
      if ($type eq 'Info' && $action eq 'Index') {
        foreach my $release (reverse sort keys %archive) {
          next if $release == $object->species_defs->ENSEMBL_VERSION;
          
          if ($release > 50) {
            $html .= $self->_output_link(\%archive, $release, $url);
          } else {
            $url =~ s/Info\/Index/index\.html/;
            $html .= $self->_output_link(\%archive, $release, $url);
          }
        }
      } else {
        my $releases = get_archive_redirect($type, $action, $object);
        my ($old_params, $old_url) = get_old_params($params, $type, $action);

        foreach my $poss_release (reverse sort keys %archive) {
          my $release_happened = 0;
          
          next if $poss_release == $object->species_defs->ENSEMBL_VERSION;
          
          foreach my $r (@$releases) {
            my ($old_view, $initial_release, $final_release, $missing_releases) = @$r;
            
            if ($poss_release < $initial_release || $poss_release > $final_release || grep $poss_release == $_, @$missing_releases) {
              $missing = 1;
              next;
            }
            
            $release_happened = 1;
            
            $url = "$species/" . ($old_url || $old_view) . $old_params if $poss_release < 51;
          }
          
          $html .= $self->_output_link(\%archive, $poss_release, $url) if $release_happened;
        }
        
        $html .= "</ul>\n";
      }
      
      $html .= "<p>Some earlier archives are available, but this view was not present in those releases</p>\n" if $missing;
    } else {
      $html .= "<p>This is a new species, so there are no archives containing equivalent data.</p>\n";
    }
  } else {
    # TODO - map static content moves
    %archive = %{$object->species_defs->ENSEMBL_ARCHIVES};
    
    $html .= "<ul>\n";
    
    foreach my $poss_release (reverse sort keys %archive) {
      next if $poss_release == $object->species_defs->ENSEMBL_VERSION;
      
      $html .= $self->_output_link(\%archive, $poss_release, $url);
    }
    
    $html .= "</ul>\n";
  }
  
  $html .= '<p><a href="/info/website/archives/" class="cp-external">More information about the Ensembl archives</a></p>';

  return $html;
}

sub _output_link {
  my ($self, $archive, $release, $url) = @_;
  
  my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
  my $date  = $archive->{$release};
  my $month = substr $date, 0, 3;
  my $year  = substr $date, 3, 4;
  
  return qq{<li><a href="http://$date.archive.ensembl.org/$url" class="cp-external">$sitename $release: $month $year</a></li>};
}

# Map new parameters to old 
sub get_old_params {
  my ($new_params, $type, $action) = @_;
  
  my %parameters = map { $_->[0] => unescape($_->[1]) } map {[ split '=' ]} split ';', $new_params;
  
  my $old_params;
  
  if ($type eq 'Location') {
    my $location = $parameters{'r'};
    my ($chr, $start, $end) = $location =~ /^([a-zA-Z0-9]+):([0-9]+)\-([0-9]+)$/;
    
    if ($action eq 'Marker') {
      if (my $m = $parameters{'m'}) {
        $old_params = "marker=$m";
      } else {        
        return ("chr=$chr;start=$start;end=$end", 'contigview');
      }
    } elsif ($action eq 'Multi') {
      $old_params = "c=$chr:" . ($start+$end)/2 . ';w=' . ($end-$start+1);
      $old_params .= ";$_=$parameters{$_}" for grep { /s\d+/ } keys %parameters;
    } else {
      $old_params = "chr=$chr;start=$start;end=$end";
    }
  } elsif ($type eq 'Gene') {
    $old_params = "gene=$parameters{'g'}";
  } elsif ($type eq 'Variation') {
    $old_params = "snp=$parameters{'v'}";
  } elsif ($type eq 'Transcript') {
    if ($action eq 'Idhistory/Protein') {
      $old_params = "peptide=$parameters{'t'}";
    } elsif ($action eq 'SupportingEvidence/Alignment' || $action eq 'Similarity/Align') {
      $old_params = "transcript=$parameters{'t'};exon=$parameters{'exon'};sequence=$parameters{'sequence'}";
    } elsif ($action eq 'Domains/Genes') {
      $old_params = "domainentry=$parameters{'domain'}";
    } else {
      $old_params = "transcript=$parameters{'t'}";
    }
  } else {
    $old_params = $new_params;
  }
  
  $old_params = "?$old_params" if $old_params;
  
  return $old_params;
}

1;
