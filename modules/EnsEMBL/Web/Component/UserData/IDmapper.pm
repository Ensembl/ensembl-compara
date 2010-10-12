# $Id$

package EnsEMBL::Web::Component::UserData::IDmapper;

use strict;

use Bio::EnsEMBL::StableIdHistoryTree;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

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
  
  my @files = ($hub->param('convert_file'));

  foreach my $file_name (@files) {
    my ($file, $name)    = split ':', $file_name;
    my ($ids, $unmapped) = @{$object->get_stable_id_history_data($file, $size_limit)}; 
    my $table            = $self->format_mapped_ids($ids);
    
    $html .= $table;
    $html .= $self->_info('Information', '<p>The numbers in the above table indicate the version of a stable ID present in a particular release.</p>');
    $html .= $self->add_unmapped_ids($unmapped) if scalar keys %$unmapped > 0;
  }

  return $html;
}    

sub add_unmapped_ids {
  my ($self, $unmapped) = @_;
  my $html = '<h2>No ID history was found for the following identifiers:</h2>';
  $html   .= "<br />$_" for sort keys %$unmapped;
  
  return $html;
}

sub format_mapped_ids { 
  my ($self, $ids) = @_;
  my %stable_ids       = %$ids;
  my $earliest_archive = $self->hub->species_defs->EARLIEST_ARCHIVE;
  
  return '<p>No IDs were succesfully converted</p>' if scalar keys %stable_ids < 1;
  
  my $table = $self->new_table([], [], { margin => '1em 0px' });
  
  $table->add_option('triangular', 1);
  $table->add_columns(
    { key => 'request', align => 'left', title => 'Requested ID'  },
    { key => 'match',   align => 'left', title => 'Matched ID(s)' },
    { key => 'rel',     align => 'left', title => 'Releases:'     },
  );


  my (%releases, @rows);

  foreach my $req_id (sort keys %stable_ids) {
    my $matches = {};
    
    foreach my $a_id (@{$stable_ids{$req_id}->[1]->get_all_ArchiveStableIds}) {
      my $linked_text = $a_id->version;
      $releases{$a_id->release} = 1; 
      
      if ($a_id->release > $earliest_archive) {
        my $archive_link = $self->archive_link($stable_ids{$req_id}->[0], $a_id->stable_id, $a_id->version, $a_id->release);
        $linked_text = qq{<a href="$archive_link">$linked_text</a>} if $archive_link;
      }
      
     $matches->{$a_id->stable_id}->{$a_id->release} = $linked_text; 
    }
    
    # self matches
    push @rows, {
      request => $self->idhistoryview_link($stable_ids{$req_id}->[0], $req_id),
      match   => $req_id,
      rel     => '',
       %{$matches->{$req_id}}
    };

    # other matches
    foreach my $a_id (sort keys %$matches) {
      next if $a_id eq $req_id;
      
      push @rows, {
        request => '',
        match   => $a_id,
        rel     => '',
        %{$matches->{$a_id}},
      };
    }
  } 
  
  $table->add_columns({ key => $_, align => 'left', title => $_ }) for sort keys %releases;
  $table->add_rows(@rows);

  return  $table->render;
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
  my $url   =  qq{<a href="$link">$stable_id</a>};
  
  return $url;
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
    my $adaptor      = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
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
