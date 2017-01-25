=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->mcacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $url  = $self->ajax_url('ajax', {
    r            => $hub->referer->{'params'}->{'r'}[0],
    code         => $hub->param('code') || '',
    nearest      => $hub->param('nearest') || '',
    description  => $hub->param('description') || '',
    count        => $hub->param('count') || 0,
    _type        => $hub->param('type') || 'upload',
    update_panel => 1,
    __clear      => 1
  });

  return qq{<div class="ajax"><input type="hidden" class="ajax_load" value="$url" /></div><div class="modal_reload"></div>};
}

sub content_ajax {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $type    = $hub->param('_type');
  my $code    = $hub->param('code');
  return unless $type && $code;

  my ($data, $record_owner);
  if ($record_owner = $hub->user) {
    $data = $hub->user->get_record_data({type => $type, code => $code});
  }

  ## Can't find a user record - check session
  unless (keys %{$data || {}}) {
    $data = $session->get_record_data({type => $type, code => $code});
    $record_owner = $session;
  }

  return unless keys %$data;

  my $format  = $data->{'format'};
  my $html;

  unless ($format eq 'TRACKHUB' && $hub->param('assembly') !~ $hub->species_defs->get_config($hub->data_species, 'ASSEMBLY_VERSION')) { ## Don't give parsing message if this is a hub and we can't show it!
    if ($type eq 'url') {
      $html .= '<p>We cannot parse remote files to navigate to the nearest feature. Please select appropriate coordinates after closing this window</p>';
    } 
    else {
      my $size = int($data->{'filesize'} / (1024 ** 2));
  
      if ($size > 10) {
        $html .= "<p>Your uncompressed file is over $size MB, which may be very slow to parse and load. Please consider using a smaller dataset.</p>";
      } 
      else {
        my $error;
        my $nearest     = $hub->param('nearest');
        my $count       = $hub->param('count');
        my $description = $hub->param('description');
        
        if ($nearest) {

          $data->{'nearest'}      = $nearest;
          $data->{'description'}  = $description if $description;
          $record_owner->set_record_data($data);
   
          if ($hub->param('count')) { 
            $html .= sprintf '<p class="space-below"><strong>Total features found</strong>: %s</p>', $count;
          }

          my $contigviewbottom = join(',', map $_ ? "$_=on" : (), $data->{'analyses'} ? split ', ', $data->{'analyses'} : join '_', $data->{'type'}, $data->{'code'});
          my $location_view = ($hub->referer->{ENSEMBL_TYPE} eq 'Location' && $hub->referer->{ENSEMBL_ACTION} eq 'View') ? 1 : 0;

          $html .= sprintf('
                <br>
                <p><strong>Go to%s:</strong></p>
                <ul>
                  <li>%s region with data: <a href="%s;contigviewbottom=%s">%s</a></li>
                  <li>Current region: <a href="%s;contigviewbottom=%s">%s</a></li>
                </ul>
                <p class="space-below">or</p>',
                !$location_view ? ' Location view' : '',
                $hub->referer->{'params'}{'r'} ? 'Nearest' : 'First',
                $hub->url({
                  species  => $data->{'species'},
                  type     => 'Location',
                  action   => 'View',
                  function => undef,
                  r        => $nearest,
                  __clear => 1
                }),
                $contigviewbottom,
                $nearest,
                $hub->url({
                  species  => $data->{'species'},
                  type     => 'Location',
                  action   => 'View',
                  function => undef,
                  r        => $hub->param('r'),
                  __clear => 1
                }),
                $contigviewbottom,
                $hub->param('r')
              );
        }
        elsif ($count) {
          ## Maybe the user uploaded the data on a non-location page?
          $html .= sprintf '<p class="space-below"><strong>Total features found</strong>: %s</p>', $count;
        }
        else {
        
          $html .= sprintf('
              <div class="ajax_error">
                %s
                <p class="space-below">None of the features in your file could be mapped to the %s genome.</p>
                <p class="space-below">Please check that you have selected the right species.</p>
              </div>
              <p class="space-below"><a href="%s" class="modal_link" rel="modal_user_data">Delete upload and start again</a></p>
              <p class="space-below">or</p>',
              $error,
              $hub->species_defs->get_config($data->{'species'}, 'SPECIES_SCIENTIFIC_NAME'),
              $hub->url({
                action   => 'ModifyData',
                function => 'delete_upload',
                goto     => 'SelectFile',
                code     => $hub->param('code'),
                r        => $hub->param('r'),
              })
            );
        }
      }
    }
  }

  $hub->configure_user_data($type, $data);

  $html .= '<p>Close this window to return to current page</p>';

  return $html;
}

1;
