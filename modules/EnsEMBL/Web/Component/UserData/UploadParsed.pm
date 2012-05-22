# $Id$

package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

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
  
  my $parser  = new EnsEMBL::Web::Text::FeatureParser($hub->species_defs, $hub->param('r'), $data->{'species'});
  my $format  = $data->{'format'};
  my $formats = $hub->species_defs->REMOTE_FILE_FORMATS;
  my $html;
  
  if (grep /^$format$/i, @$formats) {
    $html .= '<p>We cannot parse large file formats to navigate to the nearest feature. Please select appropriate coordinates after closing this window</p>';
  } else {
    my $size = int($data->{'filesize'} / (1024 ** 2));
  
    if ($size > 10) {
      $html .= "<p>Your uncompressed file is over $size MB, which may be very slow to parse and load. Please consider using a smaller dataset.</p>";
    } else {
      my $content;
      
      if ($type eq 'url') {
        $content = get_url_content($data->{'url'})->{'content'};
      }  elsif ($type eq 'upload') {
        $content = new EnsEMBL::Web::TmpFile::Text(filename => $data->{'filename'}, extension => $data->{'extension'})->retrieve;
      }

      if ($content) {      
        my $error   = $parser->parse($content, $data->{'format'});
        my $nearest = $parser->nearest;
           $nearest = undef if $nearest && !$hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', split /\W/, $nearest); # Make sure we have a valid location
        
        if ($nearest) {
          $data->{'format'}  ||= $parser->format;
          $data->{'style'}     = $parser->style;
          $data->{'nearest'}   = $nearest;
    
          $session->set_data(%$data);
    
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
        } else {
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
            <p class="space-below"><a href="%s" class="modal_link">Delete upload and start again</a></p>
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
  
  $html .= '<p>Close this window to return to current page</p>';

  return $html;
}

1;
