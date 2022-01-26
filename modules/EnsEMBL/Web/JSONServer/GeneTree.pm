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

package EnsEMBL::Web::JSONServer::GeneTree;

use strict;
use warnings;
use EnsEMBL::Web::File;
use Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Utils::GeneTreeHash;
use JSON;
use URI::Escape qw(uri_escape);

use parent qw(EnsEMBL::Web::JSONServer);

sub object_type {
  my $self = shift;
  return 'GeneTree';
}

sub json_fetch_wasabi {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $cdb     = shift || 'compara';
  my $gt_id   = $hub->param('gt');
  my $node_id = $hub->param('node');

  # # Wasabi key for session
  # my $wasabi_session_key  = $gt_id . "_" . $node_id;
  # my $wasabi_session_data = $hub->session->get_record_data({type => 'tree_files', code => 'wasabi'}) ;

  # # Return data if found in session store
  # if ($wasabi_session_data && $wasabi_session_data->{$wasabi_session_key}) {
  #   return $wasabi_session_data->{$wasabi_session_key};
  # }

  #  If not in session then create files for wasabi
  my $tree = $object->isa('EnsEMBL::Web::Object::GeneTree') ? $object->tree : $object->create_component($cdb);
  my $node = $tree->find_node_by_node_id($node_id);

  my $filename = $gt_id . '_' . $node_id;
  my $files;

  # Create tree and alingment file for wasabi and return its url paths
  if ($hub->param('treetype') && $hub->param('treetype') =~m/phyloxml/i) {
    $files = create_phyloxml($self, $node, $filename);
  }
  elsif ($hub->param('treetype') && $hub->param('treetype') =~m/json/i) {
    $files = create_json($self, $node, $filename);
  }
  else {
    $files = create_newick($self, $node);
  }

  # # Store new data into session
  # if (! keys %$wasabi_session_data) {
  #   $wasabi_session_data = {type => 'tree_files', code => 'wasabi'};
  # }
  # $wasabi_session_data->{$wasabi_session_key} = $files;

  # $hub->session->set_record_data($wasabi_session_data);

  return $files;
}

# Takes a compara tree and dumps the alignment and tree as text files.
# Returns the urls of the files that contain the trees
sub create_json {
  my $self = shift;
  my $tree = shift || die 'Need a ProteinTree object';
  my $filename = shift;
  my $method_type = ref($tree) =~ /Node/ ? 'subtrees' : 'trees';     

  my %args = (
                'name'            => $filename,
                'hub'             => $self->hub,
                'sub_dir'         => 'gene_tree',
                'input_drivers'   => ['IO'],
                'output_drivers'  => ['IO']
              );

  my $file_handle = EnsEMBL::Web::File::User->new(hub => $self->hub, name => $filename, extension => 'json');

  my $json = my $hash = Bio::EnsEMBL::Compara::Utils::GeneTreeHash->convert (
    $tree->tree, 
    -no_sequences => 0, 
    -aligned => 1, 
    -species_common_name => 0, 
    -exon_boundaries => 0
  );

  $file_handle->write_line(to_json($json));

  return {
    tree => $file_handle->read_url
  };
}

# Takes a compara tree and dumps phyloxml.
# Returns the urls of the files that contain the trees
sub create_phyloxml {
  my $self = shift;
  my $tree = shift || die 'Need a ProteinTree object';
  my $filename = shift || 'tree';
  my $file_handle = EnsEMBL::Web::File::User->new(hub => $self->hub, name => $filename, extension => 'xml');

  my $method_type = ref($tree) =~ /Node/ ? 'subtrees' : 'trees';     
  my $handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter->new(
      -SOURCE       => $SiteDefs::ENSEMBL_SITETYPE,
      -ALIGNED      => 1,
      -NO_SEQUENCES => 0,
      -HANDLE       => $handle,
  );

  my $method = 'write_trees'; #.$method_type;
  $w->$method($tree);
  $w->finish();

  my $out = ${$handle->string_ref()};
  $file_handle->write_line($out);
  return {
    tree => $file_handle->read_url
  };
}

# Takes a gene tree and dumps the alignment and newick tree as text files.
# Returns the urls of the files that contain the trees
sub create_newick {
  my $self = shift;
  my $tree = shift || die 'Need a ProteinTree object';
  my $var;

  my %args = (
                'hub'             => $self->hub,
                'sub_dir'         => 'gene_tree',
                'input_drivers'   => ['IO'],
                'output_drivers'  => ['IO'],
              );

  my $file_fa = EnsEMBL::Web::File->new(extension => 'fa', %args);
  my $file_nh = EnsEMBL::Web::File->new(extension => 'nh', %args);

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
