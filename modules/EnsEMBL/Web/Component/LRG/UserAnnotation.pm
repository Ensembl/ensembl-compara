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

package EnsEMBL::Web::Component::LRG::UserAnnotation;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;
  my $html;

  if ($user) {
    my $id          = $hub->param('lrg');
    my $type        = 'LRG';
    my $species     = $hub->species;
    my @annotations = $user->annotations;
    my @gene_annotations;
    
    foreach my $record (@annotations) {
      next unless $record->stable_id eq $id;
      push @gene_annotations, $record;
    }
    
    if (scalar(@gene_annotations)) {
      foreach my $annotation (@gene_annotations) {
        $html = '<h2>' . $annotation->title.'</h2><pre>' . $annotation->annotation . '</pre>';
        $html .= qq{<p><a href="/Account/Annotation/Edit?id=} . $annotation->id . qq{;species=$species" class="modal_link">Edit this annotation</a>.</p>};
      }
    } else {
      $html = qq{<p>You don't have any annotation on this LRG. <a href="/Account/Annotation/Add?stable_id=$id;ftype=$type;species=$species" class="modal_link">Add an annotation</a>.</p>};
    }
  } else {
    $html = $self->_info('User Account', 'You need to be logged in to save your own annotation');
  }
  
  return $html;
}

1;
