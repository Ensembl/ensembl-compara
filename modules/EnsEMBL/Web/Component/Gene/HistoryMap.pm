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

package EnsEMBL::Web::Component::Gene::HistoryMap;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub caption { return 'ID History Map'; }

sub content_protein {
  my $self = shift;
  $self->content(1);
}

sub content {
  my $self    = shift;
  my $protein = shift;
  my $hub     = $self->hub;
  my $object  = $self->object || $self->hub->core_object('gene');
  my $archive;
  my $htree;

  if ($protein == 1) {
    my $transcript = $object->transcript;
    
    if ($transcript->isa('Bio::EnsEMBL::ArchiveStableId') || $transcript->isa('EnsEMBL::Web::Fake')) { 
       my $p  = $hub->param('p')  || $hub->param('protein') || $transcript->get_all_translation_archive_ids->[0]->stable_id; 
       my $db = $hub->param('db') || 'core';
       my $a  = $hub->database($db)->get_ArchiveStableIdAdaptor;
       
       $archive = $a->fetch_by_stable_id($p);
       $htree   = $a->fetch_history_tree_by_stable_id($p); ## get tree from Archve stableid object
    } else {
       my $translation = $object->translation_object;
       $archive        = $translation->get_archive_object;
       $htree          = $translation->history;
    }
  } else {
    $archive = $object->get_archive_object; # retrieve archive object
  }

  return '<p><b>There is no history available.</b></p>' unless $archive;

  my $name        = $archive->stable_id . '.' . $archive->version;
  my $historytree = $htree || $object->history; 

  return '<p><b>There are too many stable IDs related to '.  $name .' to draw a history tree.</b></p>' unless defined $historytree;
  return '<p><b>There is no history for '. $name .' stored in the database.</b></p>' if scalar @{$historytree->get_release_display_names} < 2;

  my $tree = $self->_create_idhistory_tree($archive, $historytree);

  return unless $tree; # it's an export image request

  my $html = $historytree->is_incomplete ? '<p>Too many related stable IDs found to draw complete tree - tree shown is only partial.</p>' : '';

  return $html . $tree->render;
}

sub _create_idhistory_tree {
  my ($self, $archive, $tree) = @_;

  my $hub          = $self->hub;
  my $image_config = $hub->get_imageconfig('idhistoryview');
  
  $image_config->set_parameters({
    container_width => $self->image_width || 800,
    image_width     => $self->image_width || 800, ## hack at the moment....
    slice_number    => '1|1',
  });

  $image_config->{'_object'} = $archive;
  
  my $image = $self->new_image($tree, $image_config, [ $archive->stable_id ]);
  
  return if $self->_export_image($image, 'no_text');
  
  $image->image_type       = 'idhistorytree';
  $image->image_name       = $hub->param('image_width') . '-' . $archive->stable_id;
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image;
}

1;
