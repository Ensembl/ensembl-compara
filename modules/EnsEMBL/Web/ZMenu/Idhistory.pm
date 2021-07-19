=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Idhistory;

use strict;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::ZMenu);

sub content {}

sub archive_adaptor {
  my $self = shift;
  my $hub  = $self->hub;
  return $hub->database($hub->param('db') || 'core')->get_ArchiveStableIdAdaptor;
}

sub archive_link {
  my ($self, $archive, $release) = @_;
  
  my $hub = $self->hub;
  
  return '' unless ($release || $archive->release) > $self->object->get_earliest_archive;
  
  my $type    = $archive->type eq 'Translation' ? 'peptide' : lc $archive->type;
  my $name    = $archive->stable_id . '.' . $archive->version;
  my $current = $hub->species_defs->ENSEMBL_VERSION;
  my $view    = "${type}view";
  my ($action, $p, $url);
  
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }
  
  # Set parameters for new style URLs post release 50
  if ($archive->release >= 51) {
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript') {
      $type = 'Transcript';
      $p = 't';
      $action = 'Summary';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'ProteinSummary';
    }
  }
  
  if ($archive->release == $current) {
     $url = $hub->url({ type => $type, action => $action, $p => $name });
  } else {
    my $release_id   = $archive->release;
    my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
    my $release = $adaptor->fetch_release($release_id); 
    my $archive_site = $release ? $release->{'archive'} : '';
    
    if ($archive_site) {
      $url = "//$archive_site.archive.ensembl.org";
      
      if ($archive->release >= 51) {
        $url .= $hub->url({ type => $type, action => $action, $p => $name });
      } else {
        $url .= $hub->species_path . "/$view?$type=$name";
      }
    }
  }
  
  return $url;
}

1;
