=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::GeneAlignment;

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
  return 'Gene';
}

sub json_fetch_wasabi {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $cdb       = shift || 'compara';
  my $g_id      = $hub->param('g');
  my $family_id = $hub->param('family');
  my $type      = $hub->param('_type') || '';

  my $fam_obj         = $object->create_family($family_id, $cdb);
  my $ensembl_members = $fam_obj->get_Member_by_source('ENSEMBLPEP');

  my @all_pep_members;
  push @all_pep_members, @$ensembl_members;
  push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SPTREMBL')};
  push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SWISSPROT')};

  # # Wasabi key for session
  # my $wasabi_session_key  = join ('_', ($g_id, $family_id, $type));
  # my $wasabi_session_data = $hub->session->get_record_data({type => 'tree_files', code => 'wasabi'}) ;

  # # Return data if found in session store
  # if ($wasabi_session_data && $wasabi_session_data->{$wasabi_session_key}) {
  #   return $wasabi_session_data->{$wasabi_session_key};
  # }

  my $file = {};
  #  If not in session then create files for wasabi
  if ($type eq 'Ensembl') {
    $file = $self->generate_alignment($type, $ensembl_members);
  }
  else {
    $file = $self->generate_alignment($type, \@all_pep_members);
  }

  # # Store new data into session
  # if (! keys %$wasabi_session_data) {
  #   $wasabi_session_data = {type => 'tree_files', code => 'wasabi'};
  # }
  # $wasabi_session_data->{$wasabi_session_key} = $file;

  # $hub->session->set_record_data($wasabi_session_data);

  return $file;
}

# Takes a gene tree and dumps the alignment and newick tree as text files.
# Returns the urls of the files that contain the trees
sub generate_alignment {
  my( $self, $type, $refs ) = @_;
  my $object   = $self->object;
  my $count    = @$refs;
  my $outcount = 0;
  return unless $count;
  
  my $file = EnsEMBL::Web::File->new(
                                      hub             => $self->hub,
                                      extension       => 'fa',
                                      input_drivers   => ['IO'],
                                      output_drivers  => ['IO'],
                                      base_dir        => 'image',
                                    );

  foreach my $member (@$refs) {
    my $align;
    eval { $align = $member->alignment_string; };
    unless ($@) {
      if($member->alignment_string) {
        $file->write_line([
                            '>'.$member->stable_id,
                            $member->alignment_string,
                          ]);
        $outcount++;
      }
    }
  }
  return {} unless $outcount;
  
  return { alignment => $file->read_url };
}

1;
