package EnsEMBL::Web::Component::Help::ArchiveList;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::OldLinks;
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML unescape);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $url = CGI::unescape($object->param('url'));
  $url =~ s#^/##;
  my $html;

  ## is this a species page?
  my ($path, $param) = split('\?', $object->param('url'));
  my @check = split('/', $path);
  my ($part1, $part2, $part3, $species, $type, $action);
  if ($object->param('url') =~ m#^/#) {
    ($part1, $part2, $part3) = ($check[1], $check[2], $check[3]);
  }
  else {
    ($part1, $part2, $part3) = ($check[0], $check[1], $check[2]);
  }
  if ($part1 =~ /^[A-Z][a-z]+_[a-z]+$/) {
    $species  = $part1;
    $type     = $part2;
    $action   = $part3;
  }
  else {
    $type     = $part1;
    $action   = $part2;
  }

  my %archive;
  if ($species) {
    %archive = %{$object->species_defs->get_config($species, 'ENSEMBL_ARCHIVES')};
    if (keys %archive) {
      $html .= "<p>The following archives are available for this page:</p>
<ul>\n";
      my $missing = 0;

      if ($type =~ /\.html/ || $action =~ /\.html/) {
        foreach my $release (reverse sort keys %archive) {
          next if $release == $object->species_defs->VERSION;
          $html .= $self->_output_link(\%archive, $release, $url);
        }
      }
      else {
        my ($old_view, $initial_release) = EnsEMBL::Web::OldLinks::get_archive_redirect($type, $action);

        foreach my $release (sort keys %archive) {
          next if $release == $object->species_defs->ENSEMBL_VERSION;
          if ($release < 51) {
            if ($release >= $initial_release) {
              $url = $species.'/'.$old_view;
              ## Transform parameters
              my @params = split(';', $param);
              my (%parameter, @new_params);
              foreach my $pair (@params) {
                my @a = split('=', $pair);
                $parameter{$a[0]} = CGI::unescape($a[1]); 
              }
              if ($type eq 'Location') {
                my $location = $parameter{'r'};
                my ($chr, $start, $end) = $location =~ /^([a-zA-Z0-9]+):([0-9]+)\-([0-9]+)$/;
                @new_params = ('chr='.$chr, 'start='.$start, 'end='.$end);
              }
              elsif ($type eq 'Gene') {
                @new_params = ('gene='.$parameter{'g'});
              }
              elsif ($type eq 'Transcript') {
                @new_params = ('transcript='.$parameter{'t'});
              }
              else {
                @new_params = @params;
              } 
              $url .= '?'.join(';', @new_params) if scalar(@new_params);
            }
            else {
              $missing = 1;
            }
          }
          $html .= $self->_output_link(\%archive, $release, $url);
        }
      }
      $html .= qq(</ul>\n);
      if ($missing) {
        $html .= qq(<p>Some earlier archives are available, but this view was not present in those releases</p>\n);
      }
    }
    else {
      $html .= "<p>This is a new species, so there are no archives containing equivalent data.</p>\n";
    }
  }
  else {
    %archive = %{$object->species_defs->ENSEMBL_ARCHIVES};
    ## TO DO - map static content moves!
    $html .= qq(<ul>\n);
    foreach my $release (reverse sort keys %archive) {
      next if $release == $object->species_defs->ENSEMBL_VERSION;
      $html .= $self->_output_link(\%archive, $release, $url);
    }
    $html .= qq(</ul>\n);
  }
  $html .= qq(<p><a href="/info/website/archives/" class="cp-external">More information about the Ensembl archives</a></p>);
  
  return $html;
}

sub _output_link {
  my ($self, $archive, $release, $url) = @_;
  my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
  my $date = $archive->{$release};
  my $month = substr($date, 0, 3);
  my $year = substr($date, 3, 4);
  return qq(<li><a href="http://$date.archive.ensembl.org/$url" class="cp-external">$sitename $release: $month $year</a></li>);
}

1;
