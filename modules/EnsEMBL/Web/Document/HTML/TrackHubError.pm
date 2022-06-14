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

package EnsEMBL::Web::Document::HTML::TrackHubError;

### Help page for situations where we don't support any of the assemblies in a hub

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use parent qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self     = shift;
  my $hub      = $self->hub;
  my $html;

  my $error_type = $hub->param('error');
  $html         .= $self->$error_type if $self->can($error_type);

  return $html;
}

sub archive_only {
### Hub has no species on current assemblies - link to archives if possible
  my $self = shift;
  my $hub  = $self->hub;
  my $message = '<p>Sorry, this hub is on an assembly not supported by this site.';

  if ($hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'NAME'}) {

    my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
    ## Only fetch archives from 75 onwards, as we don't have track hub support
    ## on anything earlier
    my $archive_info = $adaptor->fetch_archive_assemblies(75); 

    my (@species) = grep { $_ =~ /^species_/ } $hub->param;
    my %archives;

    foreach (@species) {
      (my $species = $_) =~ s/species_//;
      my $assembly = $hub->param($_);
      my $info = $archive_info->{$species};
      foreach my $release (reverse sort keys %$info) {
        my $archive_assembly = $info->{$release}{'assembly_version'};
        if ($archive_assembly eq $assembly) {
          $archives{$species} = $release;
          last;
        }
      }
    }

    my $count = scalar keys %archives;
    if ($count) {
      my $alt_site;
      if ($hub->species_defs->ENSEMBL_SERVERNAME =~ /grch37|archive/) {
        $message .= " Please try our main website:";
        $alt_site = 'www';
      }
      else {
        my $plural = $count > 1 ? 's' : '';
        $message .= " Please try the following archive site$plural:</p><ul>";
      }
      my $trackhub = $hub->param('url');
      $message .= '<ul>';

      foreach my $species (sort keys %archives) {
        my $subdomain = $alt_site ? $alt_site 
                          : $species eq 'Homo_sapiens' ? 'grch37' : 'e'.$archives{$species};
        my $r   = $hub->species_defs->get_config($species, 'SAMPLE_DATA')->{'LOCATION_PARAM'};
        my $url = $subdomain.'.ensembl.org';
        $message .= qq(<li><a href="//$url/$species/Location/View?r=$r;contigviewbottom=url:$trackhub;format=DATAHUB#modal_user_data">$url</a>);
      }

      $message .= '</ul>';
    }
  
=pod
    if ($hub->param('assembly_hg19') || $hub->param('assembly_')) {
      $message .= qq( Try our <a href="//grch37.ensembl.org">GRCh37 archive site</a>);
    }
=cut
  }
  else {
    $message .= '</p>';
  }

  return $message;
}

sub other { 
  my $self = shift;
  my $message;
  my $error = $self->hub->session->get_record_data({
                type     => 'message',
                code     => 'HubAttachError',
              });

  if ($error && $error->{'message'}) {
    $message = sprintf '<div class="error"><h3>Attachment Error</h3><div class="message-pad">%s</div></div>', 
                          $error->{'message'};
    $self->hub->session->delete_records({'type' => 'message', 'code' => 'HubAttachError'});
  }
  else {
    $message = qq(<p>Sorry, your track hub could not be attached. Please check the URL and try again</p>);
  }
  return $message;
}

sub unknown_species {
### Hub (or link) contains no valid species for this site
  my $self = shift;
  my $hub  = $self->hub;

  my $species = $hub->param('species') || 'Your species';

  my $message = qq(<p>$species could not be found on this site. Please check the spelling in your URL, or try one of our sister sites:</p>
<ul>);

  my @sisters   = qw(www bacteria fungi plants protists metazoa rapid);
  my @domain    = split(/\./, $hub->species_defs->ENSEMBL_SERVERNAME);
  my $subdomain = $domain[0];

  foreach (@sisters) {
    next if $subdomain eq $_;
    my $name  = 'Ensembl';
    $name    .= $_ eq 'www' ? ' Vertebrates' : ' '.ucfirst($_);
    $message .= sprintf('<li><a href="//%s.ensembl.org">%s</a></li>', $_, $name);
  }

  $message .= '</ul>';

  return $message;
}

sub no_url {
### Link to trackhub had no URL
  my $self = shift;
  return qq(<p>No track hub url was provided - please check your link and try again.</p>);
}

1;
