package EnsEMBL::Web::Component::History;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Species;

our @ISA = qw(EnsEMBL::Web::Component);

sub stage1 {
  my ($panel, $object) = @_;
  
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form('stage1_form')->render();
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub stage1_form {
  my ($panel, $object) = @_;
  
  my $form = EnsEMBL::Web::Form->new('stage1_form',
    "/@{[$object->species]}/historyview", 'post' );
  
  if ($panel->params('error')) {
    my $error_text = $panel->params->{'error'};
    my $helpdesk = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;
    $form->add_element('type' => 'Information',
      'value' => '<p class="error">'.$error_text.' If you continue to have a problem, please contact <a href="mailto:'.$helpdesk.'">'.$helpdesk.'</a>.</strong></p>'
    );
  }

  $form->add_element(
      'type' => 'Information',
      'value' => qq(<p>Please enter or upload a list of up to 30 stable IDs to retrieve the stable ID history for. Input should be in plain text format, one stable ID per line (versions are optional and will be stripped automatically).</p>)
  );

  my @species = EnsEMBL::Web::Data::Species->search(
    {
      'releases.release_id'    => $SiteDefs::ENSEMBL_VERSION,
      'releases.assembly_code' => {'!=' => ''},
    },
    {
      order_by => 'name',
    }
  );
  my @spp = map +{ 'value' => $_->name, 'name' => $_->name } @species;
  
  $form->add_element( 
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'species',
    'label'  => 'Select species to retrieve IDs for ',
    'values' => \@spp,
    'value'  => $object->species,
  );
  
  $form->add_element(
    'type'  => 'Text',
    'name'  => 'paste_file',
    'label' => 'Paste file content',
    'rows'  => 10,
    'cols'  => '',
    'value' => '',
    'form'  => 1,
  ); 
  
  $form->add_element(
    'type'  => 'File',
    'name'  => 'upload_file',
    'value' => '',
    'label' => 'or upload file'
  );

# $form->add_element(
#    'type'  => 'String',
#    'name'  => 'url_file',
#    'label' => 'or use file URL',
#    'value' => ''
# );

  my @optout = (
	['html' => 'HTML'],
);	
#	['text' => 'Text'] 
# );
 
  my %checked = ('html' => 'yes'); 
  $form->add_element(
    'type'   => 'RadioGroup',
    'class'  => 'radiocheck',
    'name'   => 'output',
    'label'  => 'Select output format',
    'values' => [ map {{ 'value' => $_->[0], 'name' => $_->[1], 'checked' => $checked{$_->[0]} }} @optout ]
  );

  $form->add_element(
    'type'  => 'Submit',
    'value' => 'Submit >>',
    'name'  => 'submit',
    'class' => 'red-button'
  );
  
  return $form;
}


sub historypanel {
  my ($panel, $object) = @_;

  # Create a new StableIdHistoryTree object. All individual trees will be merged
  # into this single new tree.
  my $super_tree = Bio::EnsEMBL::StableIdHistoryTree->new;

  # hash to store history for each requested stable ID
  my %stable_ids = ();

  foreach my $arch_id (@{ $panel->params }) {
    my $history = $arch_id->get_history_tree;
    $super_tree->add_StableIdEvents(@{ $history->get_all_StableIdEvents });
    $stable_ids{$arch_id->stable_id} = [$arch_id->type, $history];
  }

  # consolidate tree and calculate grid coordinates
  $super_tree->consolidate_tree;
  $super_tree->add_ArchiveStableIds_for_events;
  $super_tree->calculate_coords;

  # print spreadsheet table header
  $panel->add_option('triangular',1); 	
  $panel->add_columns(
      { 'key' => 'request', 'align'=>'left', 'title' => 'Requested ID'},
      { 'key' => 'match', 'align'=>'left', 'title' => 'Matched ID(s)' },
      { 'key' => 'rel', 'align'=>'left', 'title' => 'Releases:' },
  );

  my @releases = @{ $super_tree->get_release_display_names };
  foreach my $release (@releases) {
    $panel->add_columns(
        { 'key' => $release, 'align' => 'left', 'title' => $release },
    );
  }

  # now add the data rows
  foreach my $req_id (sort keys %stable_ids) {
    
    my $matches = {};
    
    # build grid matrix
    foreach my $a_id (@{ $stable_ids{$req_id}->[1]->get_all_ArchiveStableIds }) {
      # we only need x coordinate
      my ($x) = @{ $super_tree->coords_by_ArchiveStableId($a_id) };
      $matches->{$a_id->stable_id}->{$releases[$x]} = $a_id->version;
    }

    # self matches
    $panel->add_row({
        'request' => _idhistoryview_link($stable_ids{$req_id}->[0], $req_id),
        'match'   => $req_id,
        'rel'     => '',
        %{ $matches->{$req_id} },
    });

    # other matches
    foreach my $a_id (sort keys %$matches) {
      next if ($a_id eq $req_id);

      $panel->add_row({
          'request' => '',
          'match'   => $a_id,
          'rel'     => '',
          %{ $matches->{$a_id} },
      });
    }

  }

  return 1;
}


sub nohistory {
  my ($panel, $object) = @_;

  $panel->print(qq(<p>No ID history was found for the following identifiers:</p><p>));
  
  foreach my $id (@{ $panel->params }){
    $panel->print(qq(<br>$id));	
  }
  
  $panel->print(qq(</p>));

  return 1;
}


sub history_info {
  my ($panel, $object) = @_;

  $panel->print(qq(
    <p>The numbers in the above table indicate the version of a stable ID present in a particular release.</p>
  ));

 return 1;
}


sub _idhistoryview_link {
  my ($type, $stable_id) = @_;
  return undef unless ($stable_id);

  $type = lc($type);
  $type = 'peptide' if ($type eq 'translation');
  
  my $fmt = qq(<a href="idhistoryview?%s=%s">%s</a>);
  return sprintf($fmt, $type, $stable_id, $stable_id);
}


1;

