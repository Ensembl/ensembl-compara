package EnsEMBL::Web::Configuration::ArchiveStableId;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;
use Bio::EnsEMBL::DBSQL::ArchiveStableIdAdaptor;
use Data::Dumper;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub idhistoryview {
  my $self = shift;

  my $obj = $self->{'object'}; 

  $self->initialize_zmenu_javascript;
  $self->initialize_ddmenu_javascript;
  $self->{page}->add_body_attr( 'onload' => 'populate_trees(); ');
  $self->{page}->javascript->add_source("/js/ajax_fragment.js");
  $self->update_configs_from_parameter('idhistoryview');
  
  my $params = { lc($obj->type) => $obj->stable_id, 'db' => 'core'  }; 
 
  # main information panel
  if (my $info_panel = $self->new_panel('Information',
      'code'    => "info$self->{flag}",
      'caption' => 'ID History Report',
      'params'  => $params,
    )) {

    $info_panel->add_components(qw(
      name            EnsEMBL::Web::Component::ArchiveStableId::name
      id_status       EnsEMBL::Web::Component::ArchiveStableId::status
      latest_version  EnsEMBL::Web::Component::ArchiveStableId::latest_version
    ));
    $self->add_panel($info_panel);
  }

  # associated IDs spreadsheet
  if (my $assoc_panel = $self->new_panel('SpreadSheet',
      'code'    => "info_assoc",
      'caption' => 'Associated archived IDs for this stable ID version',
      'status'  => 'panel_assoc',
      'params'  => $params,
      'null_data' => '<p>No associated IDs found.</p>',
    )) {

    $assoc_panel->add_components(qw(
      associated_ids  EnsEMBL::Web::Component::ArchiveStableId::associated_ids
    ));
    $self->add_panel($assoc_panel);
  }

  # history tree
  if (my $tree_panel = $self->new_panel('Information',
      'code'    => "image",
      'caption' => 'ID History Map',
      'params'  => $params,
      'status'  => 'panel_image'
    )) {

    $tree_panel->add_components(qw(
      tree            EnsEMBL::Web::Component::ArchiveStableId::tree
    ));
    if ($ENSEMBL_WEB_REGISTRY->check_ajax) {
      $tree_panel->load_asynchronously('tree');
    }
    $self->add_panel($tree_panel);
  }

  # version information
  if (my $panel2 = $self->new_panel('',
    'code'    => "info_version",
    'caption' => 'Version information',
				       )) {

    $panel2->add_components(qw(
    version_info EnsEMBL::Web::Component::ArchiveStableId::version_info

     ));
    $self->{page}->content->add_panel( $panel2 );
  }
}

#---------------------------------------------------------------------------

## Configuration for historyview form

sub historyview {
  my $self   = shift;

  my $object = $self->{'object'};
  my $max = 30;
  my $max_ids = $max + 1;

  my $error;
  my @e = (qq(You did not upload any data, please try again.), 
           qq(You may only upload a maximum of $max stable ID's. If you require information for a large number of sequence please email the helpdek with your request.), 
           qq(You have selected two different types of data source. Please either paste your data into the box OR upload a file OR enter a URL.),
           qq(There was a problem with uploading your file, please try again.)
  );
  
  ## Check If we have data added by user
  if ($object->param('output')) {
    my ($fh, $data, $result, $param);		 

    if ($object->param('paste_file') or $object->param('upload_file') or $object->param('url_file')) {
      if ($object->param('paste_file')) {
        if ($object->param('upload_file') or $object->param('url_file')) {
          $error = $e[2];
        } else {
          $fh = 'ids.txt';
          $param = 'paste_file';                  	
        }
      } elsif ($object->param('upload_file')) {
        if ($object->param('paste_file') or $object->param('url_file')) {
          $error = $e[2];
        } else {
          $fh = $object->param('upload_file');
          $param = 'upload_file';
        }
      } 
      
      my @ids;
      if ($param eq 'url') {
        $data = get_url_content($object->param('url'));
      } else {
        my $file = EnsEMBL::Web::TmpFile::Text->new(
          tmp_filename => $object->[1]->{'_input'}->tmpFileName($object->param('file')),
          prefix       => 'hv',
          filename     => $fh,
        );
        $data = $file->retrieve;  
      }
      
      my @ids = split(/\s+/, $data);
      my $size = @ids;
      
      if ($size >= $max_ids) {
        $error = $e[1];
      } else {
        
        my $species = $object->param('species');
        my $reg = "Bio::EnsEMBL::Registry"; 
        my $aa = $reg->get_adaptor($species, 'core', 'ArchiveStableId');
        my (@trees, @none);
        
        foreach my $id (@ids) {
          $id =~ s/\.\d+//;
          $id =~ s/\W//;

          my $archive_id = $aa->fetch_by_stable_id($id);
          
          if ($archive_id) { 
            push @trees, $archive_id;
          } else {
            push @none, $id;
          }  
        }

        unless ($error) {
          if ($object->param('output') eq 'html' ) { 
            
            my $params = \@trees;
            
            if (scalar(@trees)) {
              my $history_panel = $self->new_panel('SpreadSheet',
                  'code'    => "info$self->{flag}",
                  'caption' => 'ID History Report',
                  'params'  => $params,
              );

              $history_panel->add_components(qw(
                  history   EnsEMBL::Web::Component::History::historypanel
              ));
              $self->{page}->content->add_panel( $history_panel );

              my $info_panel = $self->new_panel('',
                  'code'    => "info$self->{flag}",
                  'caption' => 'Information',
                  'params'  => $params,
              );

              $info_panel->add_components(qw(
                  history_info   EnsEMBL::Web::Component::History::history_info
              ));
              $self->{page}->content->add_panel( $info_panel );
            }

            if (scalar(@none)) {
              my $params = \@none;
              my $no_history_panel = $self->new_panel('',
                  'code'    => "info$self->{flag}",
                  'caption' => 'No ID history found',
                  'params'  => $params,
              );

              $no_history_panel->add_components(qw(
                  none    EnsEMBL::Web::Component::History::nohistory
              ));
              $self->{page}->content->add_panel( $no_history_panel );
            }
            
            return;
          }						 
        }
      }
    } else {
      $error = $e[0]; 
    }  
  }
  
  ## Display the form...
  my $params;
  if ($error) {
    $params = {'error' => $error};
  }
  
  my $panel1 = $self->new_panel( '',
      'code'    => 'stage1_form',
      'caption' => qq(Upload your list of stable IDs),
      'params'  => $params
  );

  $self->add_form($panel1, qw(
    stage1_form   EnsEMBL::Web::Component::History::stage1_form
  ));
  $panel1->add_components(qw(
    stage1  EnsEMBL::Web::Component::History::stage1
  ));
  
  $self->add_panel($panel1);
}

#---------------------------------------------------------------------------

# Simple context menu specifically for HistoryView

sub context_historyview {
  my $self = shift;
  
  my $species = $self->{object}->species;
  my $flag = "";
  
  $self->{page}->menu->add_block( $flag, 'bulleted', "Display your data" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Input new data",
                                  'href' => "/idhistory.html" );
}


sub context_menu {
  my $self = shift;
  
  my $obj = $self->{'object'};
  my $species = $obj->species;
  my $flag = "feat";
  
  $self->{page}->menu->add_block( $flag, 'bulleted', "Stable ID Mapping" );
  
  $self->add_entry(
      $flag,
      'text' => "Batch mapping for old identifiers",
      'href' => "/$species/historyview"
  );
}


1;

