package EnsEMBL::Web::Configuration::ArchiveStableId;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;
use Bio::EnsEMBL::DBSQL::ArchiveStableIdAdaptor;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub idhistoryview {
  my $self   = shift;
  my $obj    = $self->{'object'}; 

  # Description : prints a two col table with info
  if (my $info_panel = $self->new_panel('Information',
    'code'    => "info$self->{flag}",
    'caption' => 'ID History Report',
				       )) {

    $info_panel->add_components(qw(
    name       EnsEMBL::Web::Component::ArchiveStableId::name
    db_name    EnsEMBL::Web::Component::ArchiveStableId::status
    remapped   EnsEMBL::Web::Component::ArchiveStableId::remapped
    archive    EnsEMBL::Web::Component::ArchiveStableId::archive
    associated_ids EnsEMBL::Web::Component::ArchiveStableId::associated_ids

     ));
    $self->{page}->content->add_panel( $info_panel );
  }

  if (my $panel1 = $self->new_panel('SpreadSheet',
    'code'    => "info$self->{flag}",
    'caption' => 'ID Mapping History',
    'null_data' => "<p>".$obj->stable_id. " has no successors or predecessors.</p>",
				   )) {
    $panel1->add_components(qw(
      history    EnsEMBL::Web::Component::ArchiveStableId::history
			     ));
   $self->{page}->content->add_panel( $panel1 );
 }

  if (my $panel1b = $self->new_panel('',
    'code'    => "info$self->{flag}",
    'caption' => 'ID Mapping History',
    'null_data' => "<p>".$obj->stable_id. " has no successors or predecessors.</p>",
         
                               )) {
    $self->initialize_zmenu_javascript;
    $self->initialize_ddmenu_javascript;
    $panel1b->add_components(qw(
      menu  EnsEMBL::Web::Component::ArchiveStableId::id_history_tree_menu
      tree    EnsEMBL::Web::Component::ArchiveStableId::tree
                             ));
   $self->{page}->content->add_panel( $panel1b );
 }

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
  my @e = (qq(You did not upload any data, please try again.), 
           qq(You may only upload a maximum of 30 stable IDs), 
           qq(You have selected two different types of data source. Please either paste your data into the box OR upload a file OR enter a URL.),
           qq(There was a problem with uploading your file, please tey again.)
  );
  my $error;
  ## Check If we have data added by user:
  if ($object->param('output')){	 
   if ($object ->param('paste_file') | $object->param('upload_file') | $object->param('url_file')){
	 my $fh;
	 if ($object->param('paste_file')){
		if ($object->param('upload_file') | $object->param('url_file')){ $error = $e[2]; }
		else {
			
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
	      # my $fh = $object->param('url_file'); 
        }
	}  
     my $infh = ('<', $fh);
     my @ids;
     while (my $line = <$infh>) {
	    chomp $line; 
	    my @temp = split(/\s+/, $line);
	    foreach my $t (@temp){
		   push (@ids, $t); 
	    }  
     }
     my $size = @ids;
     if ($size >= 31) {$error = $e[1];}
     else {
	    my $species = $object->param('species');
	    my $reg = "Bio::EnsEMBL::Registry"; 
	    my $aa = $reg->get_adaptor($species, 'Core', 'ArchiveStableId');
	    my @trees;
	 #   foreach my $id (@ids){
	  #    my $archive_id = $aa->fetch_by_stable_id($id);
	   #   my $historytree = $archive_id->get_history_tree;
#	      warn $historytree; 
#	      push (@trees, $historytree);
 #       }
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
