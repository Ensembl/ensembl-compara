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

package EnsEMBL::Web::Component::Transcript::Summary;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

# status warnings would be eg out-of-date page, dubious evidence, etc
# which need to be displayed prominently at the top of a page. Only used
# in Vega plugin at the moment, but probably more widely useful.
sub status_warnings { return undef; }
sub status_hints    { return undef; }

sub content {
  my $self = shift;
  my $object = $self->object;

  return sprintf '<p>%s</p>', $object->Obj->description if $object->Obj->isa('EnsEMBL::Web::Fake');

  my $html = "";
 
  if ($object->Obj->isa('Bio::EnsEMBL::Transcript')) {

    my @warnings = $self->status_warnings;
    if(@warnings>1 and $warnings[0] and $warnings[1]) {
      $html .= $self->_info_panel($warnings[2]||'warning',
                                $warnings[0],$warnings[1]);
    }
    my @hints = $self->status_hints;
    if(@hints>1 and $hints[0] and $hints[1]) {
      $html .= $self->_hint($hints[2],$hints[0],$hints[1]);
    }
    $html .= $self->transcript_table;
  }
  else {
    my ($function, $text);
    if ($self->hub->action =~ /Prot|Domain/) {
      $function = 'Protein';
      $text     = 'Protein';
    }
    else {
      $text     = 'Transcript';
    }
    my $url = $self->hub->url({'action' => 'Idhistory', 'function' => $function});
    $html = sprintf '<p>This transcript is not in the current gene set. Previous versions of the %s may be available on the <a href="%s">%s History page</a>.</p>', lc($text), $url, $text; 
  }

  return $html;
}

1;
