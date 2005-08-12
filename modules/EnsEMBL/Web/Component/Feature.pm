package EnsEMBL::Web::Component::Feature;

# outputs chunks of XHTML for feature-based displays

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Chromosome;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub error {
  my( $panel, $feature ) = @_;
  my $T = undef;
  $panel->add_row( "T", $T->X() );
  return 1;
}

#---------------------------------------------------------------------------

sub select_feature {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'select_feature' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}


sub select_feature_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'select_feature', "/@{[$object->species]}/featureview", 'get' );

  $form->add_element(
    'type' => 'SubHeader',
    'value' => 'Select a Feature'
    );

  my @types = (
    { 'value' => 'Gene',                'name' => 'Gene' },
    { 'value' => 'AffyProbe',           'name' => 'AffyProbe' },
    { 'value' => 'DnaAlignFeature',     'name' => 'Sequence Feature' },
    { 'value' => 'ProteinAlignFeature', 'name' => 'Protein Feature' },
  );
  unshift @types, { 'value' => 'Disease', 'name' => 'OMIM Disease' }
    if $object->species_defs->databases->{'ENSEMBL_DISEASE'};

  $form->add_element(
    'type' => 'Information',
    'value' => 'Hint: to display multiple features, enter them as a space-delimited list'
    );

  $form->add_element(
    'type'   => 'DropDownAndString',
    'select' => 'select',
    'name'   => 'type',
    'label'  => 'Feature type:',
    'values' => \@types,
    'value'  => $object->param( 'type' ) || 'Gene',
    'string_name'   => 'id',
    'string_label'  => 'ID',
    'string_value' => $object->param( 'id' ),
    'required' => 'yes'
  );

  $form->add_element(
    'type' => 'SubHeader',
    'value' => 'Configure Display Options'
    );
  
  # use image config widgets from Chromosome module
  &EnsEMBL::Web::Component::Chromosome::config_hilites($form, $object);
  &EnsEMBL::Web::Component::Chromosome::config_karyotype($form, $object);

  $form->add_element( 'type' => 'Submit', 'value' => 'Go');

  return $form;
}

#-----------------------------------------------------------------------------

sub spreadsheet_featureTable {
  my( $panel, $object ) = @_;

  # get feature data
  my( $data, $extra_columns, $initial_columns, $options ) = $object->retrieve_features;
  my @data = [];
  my $data_type = $object->param('type') eq 'Gene' || $object->param('type') eq 'Disease' ? 'gene' : 'feature';

  # spreadsheet headers
  # columns common to all features
  $panel->add_option( 'triangular', 1 );
  my $C = 0;
  for( @{$initial_columns||[]} ) {
    $panel->add_columns( {'key' => "initial$C", 'title' => $_, 'width' => '10%', 'align' => 'center' } );
    $C++;
  }

  $panel->add_columns(
    {'key' => 'loc', 'title' => 'Location', 'width' => '25%', 'align' => 'center' },
  );
  if ($data_type eq 'gene') {
    $panel->add_columns(
      {'key' => 'extname', 'title' => 'External names', 'width' => '25%', 'align' => 'center' },
    );
  } else {
    $panel->add_columns(
      {'key' => 'length', 'title' => 'Length', 'width' => '10%', 'align' => 'center' },
    );
  }
  $panel->add_columns(
    {'key' => 'names', 'title' => 'Name(s)', 'width' => '25%', 'align' => 'center' },
  );
  # add extra columns
  $C = 0;
  for( @{$extra_columns||[]} ) {
    $panel->add_columns( {'key' => "extra$C", 'title' => $_, 'width' => '10%', 'align' => 'center' } );
    $C++;
  }

  # spreadsheet rows
  my ($desc, $extname, $length, $data_row);

  if( $options->{'sorted'} ne 'yes' ) {
    @$data = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
      map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'}, $_->{'start'}] }
      @$data
  }
  foreach my $row ( @$data ) {
    my $contig_link = 'Unmapped';
    my $names       = '';
    $contig_link = sprintf('<a href="/%s/contigview?c=%s:%d&w=%d&h=%s">%s:%d-%d(%d)',
      $object->species, $row->{'region'}, int( ($row->{'start'} + $row->{'end'} )/2 ), 
      $row->{'length'} + 1000, join( '|',split(/\s+/,$row->{'label'}),$row->{'extname'}), $row->{'region'}, $row->{'start'}, $row->{'end'}, $row->{'strand'} 
    ) if $row->{'region'};
    if ($data_type eq 'gene') {
        $names = sprintf('<a href="/%s/geneview?gene=%s">%s</a>',
            $object->species, $row->{'label'}, $row->{'label'}) if $row->{'label'};
        $extname = $row->{'extname'}, 
        $desc =  $row->{'extra'}[0];
        $data_row = { 'loc' => $contig_link, 'extname' => $extname, 'names' => $names, };
    } else {
      $names = $row->{'label'} if $row->{'label'};
      $length = $row->{'length'},
      $data_row = { 'loc'  => $contig_link, 'length' => $length, 'names' => $names, };
    }
    $C=0;
    for( @{$row->{'extra'}||[]} ) {
      $data_row->{"extra$C"} = $_;
      $C++;
    }
    $C=0; # warn @{$row->{'initial'}||[]};
    for( @{$row->{'initial'}||[]} ) {
      $data_row->{"initial$C"} = $_;
      $C++;
    }
    $panel->add_row( $data_row );
  } # end of foreach loop

  return 1;

}

#-----------------------------------------------------------------------------

sub show_karyotype {
  my( $panel, $object ) = @_;
  # sanity check - does this species have chromosomes?
  my $SD = EnsEMBL::Web::SpeciesDefs->new();
  my @chr = @{ $SD->get_config($object->species, 'ENSEMBL_CHROMOSOMES') || [] };
  if (@chr) { 
    my $karyotype = create_karyotype($panel, $object);
    $panel->print($karyotype->render);
  }
  return 1;
}

sub create_karyotype {
  my( $panel, $object ) = @_;

  # CREATE IMAGE OBJECT
  my $species = $object->species;
    
  my $wuc = $object->get_userconfig( 'Vkaryotype' );
  my $image    = $object->new_karyotype_image();
  $image->cacheable  = 'no';
  $image->image_name = "feature-$species";
  $image->imagemap = 'yes';
    
  # configure the JS popup menus (aka 'zmenus')
  my $zmenu = $object->param('zmenu') || 'on';
  my $zmenu_config;
  my $data_type = $object->param('type') eq 'Gene' ? 'gene' : 'feature';
  if ($zmenu eq 'on') {
    # simple zmenu configuration - add_pointers (see below) now does 
    # all the messy output :)
    if ($data_type eq 'gene') {
        $zmenu_config = {
            'caption' => 'Genes',
            'entries' => ['label', 'contigview', 'geneview'],
        };
    }
    else {
        $zmenu_config = {
            'caption' => ucfirst($data_type),
            'entries' => ['label', 'contigview'],
        };
    }
  }

  # do final rendering stages
  my $pointers = $image->add_pointers($object, 'Vkaryotype', $zmenu_config);
  $image->karyotype( $object, [$pointers], 'Vkaryotype' );

  return $image;
}     

                                                 

1;


