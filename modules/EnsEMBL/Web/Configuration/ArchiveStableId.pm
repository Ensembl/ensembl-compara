package EnsEMBL::Web::Configuration::ArchiveStableId;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Tools::Ajax;
use EnsEMBL::Web::RegObj;
use Bio::EnsEMBL::DBSQL::ArchiveStableIdAdaptor;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub idhistoryview {
  my $self   = shift;
  my $obj    = $self->{'object'}; 
  $self->initialize_zmenu_javascript;
  $self->initialize_ddmenu_javascript;
  $self->{page}->add_body_attr( 'onload' => 'populate_trees(); ');
  $self->{page}->javascript->add_source("/js/ajax_fragment.js");
  $self->update_configs_from_parameter('idhistoryview');
  
  my $params = { $obj->type => $obj->stable_id, 'db' => 'core'  }; 
  
 
  # Description : prints a two col table with info
  if (my $info_panel = $self->new_panel('Information',
    'code'    => "info$self->{flag}",
    'caption' => 'ID History Report',
    'params'  => $params,
    'status'  => 'panel_tree'
				       )) {

    $info_panel->add_components(qw(
    name       EnsEMBL::Web::Component::ArchiveStableId::name
    db_name    EnsEMBL::Web::Component::ArchiveStableId::status
    remapped   EnsEMBL::Web::Component::ArchiveStableId::remapped
    archive    EnsEMBL::Web::Component::ArchiveStableId::archive
    associated_ids EnsEMBL::Web::Component::ArchiveStableId::associated_ids
    tree       EnsEMBL::Web::Component::ArchiveStableId::tree
    ));
  #  if (EnsEMBL::Web::Tools::Ajax::is_enabled()) {
   #   $info_panel->load_asynchronously('tree');
    #}
   $self->add_panel( $info_panel );
 }

#  if (my $panel1 = $self->new_panel('SpreadSheet',
#    'code'    => "info$self->{flag}",
#    'caption' => 'ID History Map',
#    'null_data' => "<p>".$obj->stable_id. " has no successors or predecessors.</p>",
#				   )) {
#    $panel1->add_components(qw(
#      history    EnsEMBL::Web::Component::ArchiveStableId::history
#			     ));
#   $self->{page}->content->add_panel( $panel1 );
#}


 # if (my $panel1b = $self->new_panel('Fragment',
 #   'code'      => "component_0",
 #   'caption'   => 'ID History Tree',
 #   'null_data' => "<p>".$obj->stable_id. " has no successors or predecessors.</p>",
 #   'status'    => 'panel_tree',
 #   'display'   => 'on',
 #   'loading'   => 'yes', 
 #                 @common  )) {

#    $panel1b->add_components(qw(
#      menu  EnsEMBL::Web::Component::ArchiveStableId::id_history_tree_menu
#      tree    EnsEMBL::Web::Component::ArchiveStableId::tree
#    ));

#    $panel1b->add_components(qw(
#      tree    EnsEMBL::Web::Component::ArchiveStableId::tree
#    ));
 
#  if (EnsEMBL::Web::Tools::Ajax::is_enabled()) {
#    $panel1b->asynchronously_load('tree');
#  }
#   $self->add_panel( $panel1b );
# }

if (my $panel2 = $self->new_panel('',
    'code'    => "info$self->{flag}",
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
  my $max_ids = 31;
  my @e = (qq(You did not upload any data, please try again.), 
           qq(You may only upload a maximum of 30 stable ID's. If you require information for a large number of sequence please email the helpdek with your request.), 
           qq(You have selected two different types of data source. Please either paste your data into the box OR upload a file OR enter a URL.),
           qq(There was a problem with uploading your file, please try again.)
  );
  my $error;
  ## Check If we have data added by user:
  if ($object->param('output')){	 
   if ($object ->param('paste_file') | $object->param('upload_file') | $object->param('url_file')){
	 my ($fh, $data);
	 if ($object->param('paste_file')){
		if ($object->param('upload_file') | $object->param('url_file')){ $error = $e[2]; }
		else {
		  $data = $object->param('paste_file');
                  	
		}
	 } 
	elsif ($object->param('upload_file')) {
		if ($object->param('paste_file') | $object->param('url_file')){ $error = $e[2]; }
		else {
			$fh = $object->param('upload_file');
		}
	}
	else {
		if ($object->param('paste_file') | $object->param('upload_file')){ $error = $e[2]; }
                else {
	            $fh = $object->param('url_file');
                    chomp $fh; 
                }
	} 
     my @ids;
     if ( $fh ){ 
        unless ( open (INFH, '>$fh') ) { $error = $e[3]; return; }
        
        while (my $line = <INFH>) {
            warn $line; 
	    chomp $line; 
	    my @temp = split(/\s+/, $line);
	    foreach my $t (@temp){
		    push (@ids, $t);
  	    }  
        } close (INFH);
     } elsif( $data) {
        my @temp = split(/\s+/, $data);
             foreach my $t (@temp){
                    push (@ids, $t);
            }
     }
     my $size = @ids;
     if ($size >= $max_ids) {$error = $e[1];}
     else {
	    my $species = $object->param('species');
	    my $reg = "Bio::EnsEMBL::Registry"; 
	    my $aa = $reg->get_adaptor($species, 'Core', 'ArchiveStableId');
	    my @trees;
	    foreach my $id (@ids){
		  if ($id=~/\.\d*/){ $id=~s/\.\d+//;}
		  if ($id!~/ENS\w*\d*/){ $error = "There was a problem with your uploaded data: <B>" . $id . "</B> Is not a valid Ensembl Identifier. Please remove it and try again. ";}
	 	  else {
 		    $id =~s/\W//;
                    warn $id;  
	            my $archive_id = $aa->fetch_by_stable_id($id);
	            if ($archive_id){ 
	             my  $historytree = $archive_id->get_history_tree;
                     push (@trees, $historytree);
                    }  
                 }
            }
     }
   }
   else {
	 $error = $e[0]; 
    }  
  }
  ## Display the form...
  my $params;
  if ($error=~/^\w/){$params = {'error' => $error}; }
  my $panel1 = $self->new_panel( '',
    'code'    => 'stage1_form',
    'caption' => qq(Upload your list of stable IDs),
    'params'  => $params
  );
  
  $self->add_form( $panel1, qw(stage1_form EnsEMBL::Web::Component::History::stage1_form) );
  $panel1->add_components( qw(stage1 EnsEMBL::Web::Component::History::stage1) );
  $self->add_panel( $panel1 );
}

#---------------------------------------------------------------------------

# Simple context menu specifically for HistoryView

sub context_historyview {

  my $self = shift;
  my $species  = $self->{object}->species;
  
  my $flag     = "";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Display your data" );


  $self->{page}->menu->add_entry( $flag, 'text' => "Input new data",
                                  'href' => "/idhistory.html" );


}

sub context_menu {
  my $self = shift;
  my $obj  = $self->{'object'};
  my $species = $obj->species;
  my $flag         = "feat";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Stable ID Mapping" );
  $self->add_entry( $flag, 'text' => "Find Current Stable ID for older identifiers",
                           'href' => "/$species/historyview");


  my @genes ;#= @{ $obj->get_genes };
  foreach my $gene (@genes) {
    $self->add_entry(
        "snp$self->{flag}", 
        'code' => 'gene_snp_info',
        'text' => "Gene SNP info",
	"title" => "GeneSNPView - SNPs and their coding consequences",
	'href' => "/$species/genesnpview?gene=".$gene->stable_id
    );
  }
}


1;
