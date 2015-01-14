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

package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $url  = $self->ajax_url('ajax', {
    r            => $hub->referer->{'params'}->{'r'}[0],
    code         => $hub->param('code'),
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
  my $data    = $session->get_data(type => $type, code => $hub->param('code'));
  
  return unless $data;
  
  my $format  = $data->{'format'};
  my $formats = $hub->species_defs->multi_val('REMOTE_FILE_FORMATS');
  my $html;
  
  unless ($format eq 'DATAHUB' && $hub->param('assembly') !~ $hub->species_defs->get_config($hub->data_species, 'ASSEMBLY_VERSION')) { ## Don't give parsing message if this is a hub and we can't show it!
    if (grep /^$format$/i, @$formats) {
      $html .= '<p>We cannot parse large file formats to navigate to the nearest feature. Please select appropriate coordinates after closing this window</p>';
    } 
    else {
      my $size = int($data->{'filesize'} / (1024 ** 2));
  
      if ($size > 10) {
        $html .= "<p>Your uncompressed file is over $size MB, which may be very slow to parse and load. Please consider using a smaller dataset.</p>";
      } 
      else {
        my $session_data = $hub->get_data_from_session($type, $hub->param('code'));
        my $parser = $session_data->{'parser'};
        my $error;
        if ($parser) {
          my $nearest = $parser->nearest;
          warn ">>> NEAREST $nearest";
          $nearest = undef if $nearest && !$hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', split /[^\w|\.]/, $nearest); # Make sure we have a valid location
        
          if ($nearest) {
            $data->{'format'}  ||= $parser->format;
            $data->{'style'}     = $parser->style;
            $data->{'nearest'}   = $nearest;
    
            $session->set_data(%$data);
            $session->configure_user_data($type, $data);
    
            $html .= sprintf '<p class="space-below"><strong>Total features found</strong>: %s</p>', $parser->feature_count;
    
            if ($nearest) {
              $html .= sprintf('
                <p class="space-below"><strong>Go to %s region with data</strong>: <a href="%s;contigviewbottom=%s">%s</a></p>
                <p class="space-below">or</p>',
                $hub->referer->{'params'}{'r'} ? 'nearest' : 'first',
                $hub->url({
                  species  => $data->{'species'},
                  type     => 'Location',
                  action   => 'View',
                  function => undef,
                  r        => $nearest,
                  __clear => 1
                }),
                join(',', map $_ ? "$_=on" : (), $data->{'analyses'} ? split ', ', $data->{'analyses'} : join '_', $data->{'type'}, $data->{'code'}),
                $nearest
              );
            }
          } 
          else {
            if ($error) {
              $error = sprintf 'Region %s does not exist.', $parser->nearest if $error eq $parser->nearest;
              $error = qq{<p class="space-below">$error</p>};
            }
        
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
              })
            );
          }
        }
      }
    }
  }

  $html .= '<p>Close this window to return to current page</p>';

  return $html;
}

1;
