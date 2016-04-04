=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::GeneTree;

use strict;
use warnings;
use EnsEMBL::Web::File::Dynamic;

use parent qw(EnsEMBL::Web::JSONServer);

sub object_type {
  my $self = shift;
  return 'GeneTree' if ($self->hub->param('gt'));
  return 'Gene'     if ($self->hub->param('g'));
}

sub json_fetch_wasabi {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $cdb     = shift || 'compara';
  my $gt_id   = $hub->param('gt');
  my $node_id = $hub->param('node');

  # Wasabi key for session
  my $wasabi_session_key  = $gt_id . "_" . $node_id;
  my $wasabi_session_data = $hub->session->get_data(type => 'tree_files', code => 'wasabi') ;

  # Return data if found in session store
  if ($wasabi_session_data && $wasabi_session_data->{$wasabi_session_key}) {
    return $wasabi_session_data->{$wasabi_session_key};
  }

  #  If not create files for wasabi

  my $tree = $object->isa('EnsEMBL::Web::Object::GeneTree') ? $object->tree : $object->get_GeneTree($cdb);
  my $node = $tree->find_node_by_node_id($node_id);

  # Create tree and alingment file for wasabi and return its url paths
  my $files = create_files_for_wasabi($self, $node);

  # Store new data into session
  $hub->session->add_data(
    type => 'tree_files',
    code => 'wasabi',
    $wasabi_session_key => $files
  );

  return $files;
}

# Takes a compara tree and dumps the alignment and tree as text files.
# Returns the urls of the files that contain the trees
sub create_files_for_wasabi {
  my $self = shift;
  my $tree = shift || die 'Need a ProteinTree object';
  
  my $var;

  my %args = (
                'hub'             => $self->hub,
                'sub_dir'         => 'gene_tree',
                'input_drivers'   => ['IO'],
                'output_drivers'  => ['IO'],
              );

  my $file_fa = EnsEMBL::Web::File::Dynamic->new(extension => 'fa', %args);
  my $file_nh = EnsEMBL::Web::File::Dynamic->new(extension => 'nh', %args);

  my $format  = 'fasta';
  my $align   = $tree->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1);
  $align->set_displayname_flat;

  my $aio     = Bio::AlignIO->new(-format => $format, -fh => IO::String->new($var));
  
  $aio->write_aln($align); # Write the fasta alignment using BioPerl
  
  $file_fa->write($var);
  $file_nh->write($tree->newick_format('ryo', '%{n-}%{-n|p}%{"_"-s}%{":"d}'));
  
  return {
    alignment => $file_fa->read_url, 
    tree      => $file_nh->read_url
  };
}


1;
