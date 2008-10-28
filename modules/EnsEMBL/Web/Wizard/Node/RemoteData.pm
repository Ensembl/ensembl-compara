package EnsEMBL::Web::Wizard::Node::RemoteData;

### Contains methods to create nodes for DAS and remote URL wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DASConfig;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(@GENE_COORDS @PROT_COORDS);
use base qw(EnsEMBL::Web::Wizard::Node);

my $DAS_DESC_WIDTH = 120;


sub select_server {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  $self->title('Select a DAS server or data file');

  my @preconf_das = $self->object->get_das_servers;

  # DAS server section
  $self->add_element('type'   => 'DropDown',
                     'name'   => 'preconf_das',
                     'select' => 'select',
                     'label'  => "$sitename DAS sources",
                     'values' => \@preconf_das,
                     'value'  => $object->param('preconf_das'));
  $self->add_element('type'   => 'String',
                     'name'   => 'other_das',
                     'label'  => 'or other DAS server',
                     'value'  => $object->param('other_das'),
                     'notes'  => '( e.g. http://www.example.com/MyProject/das )');
  $self->add_element('type'   => 'String',
                     'name'   => 'das_name_filter',
                     'label'  => 'Filter sources',
                     'value'  => $object->param('das_name_filter'),
                     'notes'  => 'by name, description or URL');
  
}

sub select_das {
### Displays sources for the chosen server as a series of checkboxes 
### (or an error message if no dsns found)
  my $self = shift;

  $self->title('Select a DAS source');
  
  # Get a list of DAS sources (filtered if specified)
  my $sources = $self->object->get_das_server_dsns();
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  
  # Otherwise add a checkbox element for each DAS source
  else {
    for my $source (@{ $sources }) {
      
      # If the description is long, shorten it and pretty it up
      my $desc  = $source->description;
      if (length $desc > $DAS_DESC_WIDTH) {
        $desc = substr $desc, 0, $DAS_DESC_WIDTH;
        $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./; # replace final space with " ..."
      }
      
      $self->add_element( 'type'  => 'CheckBox',
                          'name'  => 'dsns',
                          'value' => $source->logic_name,
                          'label' => $source->label,
                          'notes' => $desc );
    } # end DAS source loop
=pod
    $self->add_element( 'type'    => 'MultiCheckTable',
                        'name'    => 'dsns',
                        'values'  => \@checkboxes,
                      );
=cut
  } # end if-else
  
}

# Page method for attaching from URL
sub select_url {
  my $self = shift;
  my $object = $self->object;

  my $current_species = $ENV{'ENSEMBL_SPECIES'};
  if (!$current_species || $current_species eq 'common') {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  # URL-based section
  $self->notes({'heading'=>'Tip', 'text'=>qq(Accessing data via a URL can be slow if the file is large, but it has the advantage of ensuring that the data you see is always the same as the file on your server. For faster access, you can <a href="/$current_species/UserData/Upload">upload files to Ensembl</a> (only suitable for small, single-species datasets).)});

  $self->add_element('type'  => 'String',
                     'name'  => 'url',
                     'label' => 'File URL',
                     'value' => $object->param('url'),
                     'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->add_element('type'    => 'CheckBox',
                       'name'    => 'save',
                       'label'   => 'Save URL to my account',
                       'notes'   => 'N.B. Only the file address will be saved, not the data itself',
                       'checked' => 'checked');
  }
}

sub attach_url {
  my $self = shift;

  my $url = $self->object->param('url');
}

# Logic method, used for checking a DAS source before adding it
sub validate_das {
  my $self      = shift;
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsns') );
  warn "SOURCES $sources";
  
  # Process any errors
  if (!ref $sources) {
    $self->parameter('error_message', $sources);
    $self->parameter('wizard_next', 'select_das');
  }
  elsif (!scalar @{ $sources }) {
    $self->parameter('error_message', 'No sources selected');
    $self->parameter('wizard_next', 'select_das');
  }
  
  for my $source (@{ $sources }) {
    # If one or more source has missing details, need to fill them in and resubmit
    unless (@{ $source->coord_systems } || $self->object->param('coords')) {
      if ($self->object->param('has_species')) {
        $self->parameter('wizard_next', 'select_das_coords');
      }
      $self->parameter('wizard_next', 'select_das_species');
    }
  }
  
  $self->parameter('wizard_next', 'attach_das');
}

# Page method for filling in missing DAS source details
sub select_das_species {
  my $self = shift;
  
  $self->title('Choose a species');
  
  $self->add_element( 'type' => 'Information', 'value' => "Which species' do the DAS sources below have data for? If they contain data for all species' (e.g. gene or protein-based sources) choose 'all'. If the DAS sources do not use the same coordinate system, go back and add them individually." );
  $self->add_element( 'type' => 'SubHeader',   'value' => 'Species' );
  
  $self->add_element('name'   => 'has_species',
                     'type'   => 'RadioButton',
                     'label'  => "Species-specific (e.g. genomic sources)",
                     'checked'=> 1,
                     'value'  => 'yes');
  my @values = map {
    { 'name' => $_, 'value' => $_, }
  } @{ $self->object->species_defs->ENSEMBL_SPECIES };
  $self->add_element('name'   => 'species',
                     'type'   => 'MultiSelect',
                     'select' => 1,
                     'value'  => [$self->object->species_defs->ENSEMBL_PRIMARY_SPECIES], # default species
                     'values' => \@values);
  
  $self->add_element('name'   => 'has_species',
                     'type'   => 'RadioButton',
                     'label'  => "All species' (e.g. protein-based sources)",
                     'value'  => 'no');
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsns') );
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  else {
    $self->add_element( 'type' => 'Header',   'value' => 'DAS Sources' );
    
    for my $source (@{ $sources }) {
      # Need to fill in missing coordinate systems and resubmit
      $self->add_element( 'type' => 'Information', 'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                              $source->label,
                                                              $source->description,
                                                              $source->homepage );
    }
  }
}

sub select_das_coords {
  my $self = shift;
  my @species = $self->object->param('has_species') eq 'yes' ? $self->object->param('species') : ();
  
  $self->title('Choose a coordinate system');
  $self->add_element( 'type' => 'Header', 'value' => 'Coordinate Systems' );
  
  for my $species (@species) {
    $self->add_element( 'type' => 'SubHeader', 'value' => "Genomic ($species)" );
    
    my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");
    my @coords = sort {
      $a->rank <=> $b->rank
    } grep {
      ! $_->is_top_level
    } @{ $csa->fetch_all };
    for my $cs (@coords) {
      $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_hashref($cs);
      $self->add_element( 'type'    => 'CheckBox',
                          'name'    => 'coords',
                          'value'   => $cs->to_string,
                          'label'   => $cs->label );
    }
  }
  
  $self->add_element( 'type' => 'SubHeader', 'value' => "Gene" );
  for my $cs (@GENE_COORDS) {
    $self->add_element( 'type'    => 'CheckBox',
                        'name'    => 'coords',
                        'value'   => $cs->to_string,
                        'label'   => $cs->label );
  }
  
  $self->add_element( 'type' => 'SubHeader', 'value' => "Protein" );
  for my $cs (@PROT_COORDS) {
    $self->add_element( 'type'    => 'CheckBox',
                        'name'    => 'coords',
                        'value'   => $cs->to_string,
                        'label'   => $cs->label );
  }
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsns') );
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  else {
    $self->add_element( 'type' => 'Header',   'value' => 'DAS Sources' );
    
    for my $source (@{ $sources }) {
      # Need to fill in missing coordinate systems and resubmit
      $self->add_element( 'type' => 'Information', 'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                              $source->label,
                                                              $source->description,
                                                              $source->homepage );
    }
  }
}

# Page method for attaching a DAS source (saving to the session)
sub attach_das {
  my $self = shift;
  
  my @expand_coords = grep { $_ } $self->object->param('coords');
  if (scalar @expand_coords) {
    @expand_coords = map {
      Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_)
    } @expand_coords;
  }
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsns') );
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  else {
    $self->title('Attached DAS sources');
    
    my @success = ();
    my @skipped = ();
    
    for my $source (@{ $sources }) {
      
      $source = EnsEMBL::Web::DASConfig->new_from_hashref( $source );
      
      # Fill in missing coordinate systems
      if (!scalar @{ $source->coord_systems }) {
        if ( !scalar @expand_coords ) {
          die sprintf "Source %s has no coordinate systems and none were selected";
        }
        $source->coord_systems(\@expand_coords);
      }
      
      if ($self->object->get_session->add_das($source)) {
        push @success, $source;
      } else {
        push @skipped, $source;
      }

    }
    $self->object->get_session->save_das;
    
    if (scalar @success) {
      $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources have now been attached:' );
      for my $source (@success) {
        $self->add_element( 'type' => 'Information', 'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                                $source->label,
                                                                $source->description,
                                                                $source->homepage );
      }
    }
    
    if (scalar @skipped) {
      $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources were already attached:' );
      for my $source (@skipped) {
        $self->add_element( 'type' => 'Information', 'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                                $source->label,
                                                                $source->description,
                                                                $source->homepage );
      }
    }
  }
}


sub show_tempdas {
  my $self = shift;
  $self->title('Attach Data to Your Account');

  my $das = $self->object->get_session->get_all_das;
  if ($das && keys %$das) {
    $self->add_element('type'=>'Information', 'value' => "You have the following DAS sources configured:", 'style' => 'spaced');
    my @values;
    foreach my $source (sort values %$das) {
      my $info  = 'Source: '.$source->label.' ('.$source->description.')';
      push @values, {'value' => $source->logic_name, 'name' => $info};
    }
    $self->add_element('type' => 'MultiSelect', 'name' => 'source', 'values' => \@values);
  }
  else {
    $self->add_element('type'=>'Information', 'value' => "You have no DAS sources configured. Click on 'Attach DAS' in the left-hand menu to add sources.");
  }
}

sub save_tempdas {
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @sources = $self->object->param('source');
  if ($user && @sources) {
    my $das = $self->object->get_session->get_all_das;
    foreach my $source  (@sources) {
      my $record = $das->{$source};
      if ($record && ref($record) && ref($record) =~ 'DASConfig') { ## Sanity check
        $record->category('user');
        my $record_id = $user->add_to_dases($record);
        if ($record_id) {
          $record->mark_altered;
          $self->object->get_session->save_das;
        }
      }
    }
    $self->parameter('wizard_next', 'ok_tempdas');
  }
  else {
    $self->parameter('wizard_next', 'show_tempdas');
    $self->parameter('error_message', 'Unable to save DAS information to user account');
  }
}

sub ok_tempdas {
  my $self = shift;
  $self->title('DAS Source Saved');
  $self->add_element('type'=>'Information', 'value' => 'The DAS source details were saved to your user account.');
}



1;


