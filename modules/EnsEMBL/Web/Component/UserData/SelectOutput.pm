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

package EnsEMBL::Web::Component::UserData::SelectOutput;

use strict;

use URI::Escape qw(uri_escape);

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self  = shift; 
  my $hub   = $self->hub;
  my $code  = $hub->param('code');
  my $count = $hub->param('count');
  my ($html_action, $text_action, $title, $data_format);

  if ($hub->param('id_mapper') ) {
    $title       = 'Stable ID Mapper';
    $html_action = 'IDConversion';
    $text_action = 'MapIDs';       
    $data_format = 'id';
  } elsif ($hub->param('consequence_mapper')) {
    $title       = 'Variant Effect Predictor';  
    $html_action = 'ConsequenceCalculator';
    $text_action = 'PreviewConvertIDs';
    $data_format = 'snp';
  }

  my $html = "<h2>$title</h2>";
  my $text = 'Please select the format you would like your output in:';

  if ($hub->param('consequence_mapper') && $count) {
    $html .= $self->_info(
      'Too many features',
      sprintf('<p>Your file contained %s features; however this web tool will only convert the first %s features in the file.</p>', $count, $hub->param('size_limit'))
    );
  }
  
  my %params = map { $hub->param($_) ? ($_ => $hub->param($_)) : () } qw(convert_file id_limit variation_limit _time);
     $params{'data_format'} = $data_format;
  
  my $html_url = $hub->url({
    action => $html_action,
    format => 'html',
    code   => $code || undef,
    %params
  });
  
  my $text_url = $hub->url({
    action => $text_action,
    format => 'text',
    %params
  });

  my $list = [
    qq{<a class="modal_link" href="$html_url">HTML</a>},
    qq{<a class="modal_link" href="$text_url">Text</a>}
  ];
  
  my $form = $self->modal_form('select', $hub->url({ action => 'IDMapper' }, 1)->[0], { no_button => 1 });
  
  $form->add_fieldset;
  $form->add_notes({ class => undef, text => $text });
  $form->add_notes({ class => undef, list => $list });
  
  $html .= $form->render;

  if ($code) {
    my $nearest = $self->hub->session->get_data(code => $code) ?  $self->hub->session->get_data(code => $code)->{'nearest'} : undef;
    
    if ($nearest) {
      ## does location use HGVS format?
      if ($nearest =~ />/) {
        $nearest =~ /^(\d+)\D+(\d+)/;
        $nearest = $1.':'.$2;
      }

      $html .= sprintf(qq{
        <p>or view a sample SNP in <a href="%s">Region in Detail</a></p>
        <p>(You can also view or download your converted file from 'Manage Your Data')</p>
      }, $hub->url({ type => 'Location', action => 'View', r => $nearest, __clear => 1 }));
    }
  }

  return $html;
}

1;
