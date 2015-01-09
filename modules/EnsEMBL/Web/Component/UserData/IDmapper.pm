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

package EnsEMBL::Web::Component::UserData::IDmapper;

use strict;

use Bio::EnsEMBL::StableIdHistoryTree;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $html       = '<h2>Stable ID Mapper Results:</h2>';
  my $size_limit = $hub->param('id_limit'); 
  my @files      = $hub->param('convert_file');

  foreach my $file_name (@files) {
    my ($file, $name)    = split ':', $file_name;
    my ($ids, $unmapped) = @{$object->get_stable_id_history_data($file, $size_limit)}; 
    
    $html .= $self->format_mapped_ids($ids);
    $html .= $self->_info('Information', '<p>The numbers in the above table indicate the version of a stable ID present in a particular release.</p>', '100%');
    $html .= $self->add_unmapped_ids($unmapped) if scalar keys %$unmapped > 0;
  }

  return $html;
}    

sub add_unmapped_ids {
  my ($self, $unmapped) = @_;
  my $html  = '<h2>No ID history was found for the following identifiers:</h2>';
     $html .= "<br />$_" for sort keys %$unmapped;
  
  return $html;
}

sub format_mapped_ids { 
  my ($self, $ids) = @_;
  my %stable_ids       = %$ids;
  my $earliest_archive = $self->object->get_earliest_archive;
  
  return '<p>No IDs were succesfully converted</p>' if scalar keys %stable_ids < 1;
  
  my $table = $self->new_table([], [], { margin => '1em 0px' });
  
  $table->add_columns(
    { key => 'request', align => 'left', title => 'Requested ID'  },
    { key => 'match',   align => 'left', title => 'Matched ID(s)' },
    { key => 'rel',     align => 'left', title => 'Releases:'     },
  );
  
  my (%releases, @rows);

  foreach my $req_id (sort keys %stable_ids) {
    my %matches;
    
    foreach (@{$stable_ids{$req_id}->[1]->get_all_ArchiveStableIds}) {
      my $linked_text = $_->version;
      
      $releases{$_->release} = 1; 
      
      if ($_->release > $earliest_archive) {
        my $archive_link = $self->archive_link($stable_ids{$req_id}[0], $_->stable_id, $_->version, $_->release);
           $linked_text  = qq{<a href="$archive_link">$linked_text</a>} if $archive_link;
      }
      
     $matches{$_->stable_id}{$_->release} = $linked_text; 
    }
    
    # self matches
    push @rows, {
      request => $self->idhistoryview_link($stable_ids{$req_id}->[0], $req_id),
      match   => $req_id,
      rel     => '',
       %{$matches{$req_id}}
    };

    # other matches
    foreach (sort keys %matches) {
      next if $_ eq $req_id;
      
      push @rows, {
        request => '',
        match   => $_,
        rel     => '',
        %{$matches{$_}},
      };
    }
  } 
  
  $table->add_columns({ key => $_, align => 'left', title => $_ }) for sort { $a <=> $b } keys %releases;
  $table->add_rows(@rows);

  return $table->render;
}


sub idhistoryview_link {
  my ($self, $type, $stable_id) = @_;
  
  return undef unless $stable_id;

  my $action = 'Idhistory';
  
  if ($type eq 'Translation') { 
    $type   = 'Transcript';
    $action = 'Idhistory/Protein';
  }
  
  my $param = lc substr $type, 0, 1;
  my $link  = $self->hub->url({ type => $type, action => $action, $param => $stable_id });
  
  return qq{<a href="$link">$stable_id</a>};
}

sub archive_link {
  my ($self, $type, $stable_id, $version, $release)  = @_;

  $type = $type eq 'Translation' ? 'peptide' : lc $type;
  
  my $hub     = $self->hub;
  my $name    = "$stable_id.$version";
  my $current = $hub->species_defs->ENSEMBL_VERSION;
  my $view    = "${type}view";
  my ($action, $p, $url);
  
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }
  
  # Set parameters for new style URLs post release 50
  if ($release >= 51) {
    if ($type eq 'gene') {
      $type   = 'Gene';
      $p      = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript') {
      $type = 'Transcript';
      $p    = 't';
      $action = 'Summary';
    } else {
      $type   = 'Transcript';
      $p      = 'p';
      $action = 'ProteinSummary';
    }
  }

  if ($release == $current) {
     $url = $hub->url({ type => $type, action => $action, $p => $name });
  } else {
    my $adaptor      = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
    my $release_info = $adaptor->fetch_release($release);
    
    return unless $release_info;
    
    my $archive_site = $release_info->{'archive'};
    
    return unless $archive_site && $release_info->{'online'} eq 'Y';
    
    $url = "http://$archive_site.archive.ensembl.org";
    
    if ($release >= 51) {
      $url .= $hub->url({ type => $type, action => $action, $p => $name });
    } else {
      $url .= $hub->species_path . "/$view?$type=$name";
    }
  }
  
  return $url;
}

1;
