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

package EnsEMBL::Web::Command::UserData::MapIDs;

use strict;

use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my @files      = $hub->param('convert_file');
  my $size_limit = $hub->param('id_limit');
  my ($params, $output, @temp_files);
  
  foreach my $file_name (@files) {
    next unless $file_name;
    
    my ($file, $name)    = split ':', $file_name;
    my ($ids, $unmapped) = @{$object->get_stable_id_history_data($file, $size_limit)};
    
    $output .= $self->process_data($ids); 
    $output .= $self->add_unmapped($unmapped);

    ## Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
        extension    => 'txt',
        prefix       => 'export',
        content_type => 'text/plain; charset=utf-8',
    );

    $temp_file->print($output);
    
    push @temp_files, $temp_file->filename . ':' . $name;
  }
  
  ## Set these separately, or they cause an error if undef
  $params->{'_time'}     = $hub->param('_time');
  $params->{'species'}   = $hub->param('species');
  $params->{'converted'} = \@temp_files;
  
  $self->ajax_redirect($hub->species_path($hub->data_species) . '/UserData/PreviewConvertIDs', $params);
}

sub process_data {
  my ($self, $ids) = @_; 
  my %stable_ids = %$ids;
  my $table      = EnsEMBL::Web::Document::Table->new([], [], { margin => '1em 0px' });
  
  $table->add_columns(
    { key => 'request', align =>'left', title => 'Requested ID'  },
    { key => 'match',   align =>'left', title => 'Matched ID(s)' },
    { key => 'rel',     align =>'left', title => 'Releases:'     },
  );
  
  foreach my $req_id (sort keys %stable_ids) {
    my (%release_match_string, %matches);
    
    $matches{$_->stable_id}{$_->release} = $_->release . ':'. $_->version for @{$stable_ids{$req_id}[1]->get_all_ArchiveStableIds};
    
    foreach (sort keys %matches) {
      my %release_data   = %{$matches{$_}};
      my @rel            = map $release_data{$_}, sort keys %release_data;
      my $release_string = join ',', @rel;
      
      $release_match_string{$_} = $release_string; 
    }       

    # self matches
    $table->add_row({
      request => $req_id,
      match   => $req_id,
      rel     => $release_match_string{$req_id},
    });
    
    # other matches
    foreach (sort keys %matches) {
      next if $_ eq $req_id;

      $table->add_row({
        request => '',
        match   => $_,
        rel     => $release_match_string{$_},
      });
    }
  } 
  
  return $table->render_Text;
}
 
sub add_unmapped {
  my ($self, $unmapped) = @_;
  
  return unless scalar keys %$unmapped > 0;
  
  my $text  = "\n\nNo ID history was found for the following identifiers:\n";
     $text .= "$_\n" for sort keys %$unmapped;
  
  return $text;
}

1;
