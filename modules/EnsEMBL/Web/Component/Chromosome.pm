package EnsEMBL::Web::Component::Chromosome;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Feature;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;

use strict;
use warnings;
no warnings "uninitialized";

@EnsEMBL::Web::Component::Chromosome::ISA = qw( EnsEMBL::Web::Component);

#------------------- GENERIC FUNCTIONS ---------------------------
  
# make array of hashes for dropdown options
sub chr_list {
  my $object = shift;
  my @all_chr = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chrs;
  foreach my $next (@all_chr) {
    push @chrs, {'name'=>$next, 'value'=>$next} ;
  }
  return @chrs;
}

# dropdown values for image configuration forms

my @pointer_styles = (
        {'value' => 'box',              'name' => 'Filled box'},
        {'value' => 'filledwidebox',    'name' => 'Filled wide box'},
        {'value' => 'widebox',          'name' => 'Outline wide box'},
        {'value' => 'outbox',           'name' => 'Oversize outline box'},
        {'value' => 'wideline',         'name' => 'Line'},
        {'value' => 'lharrow',          'name' => 'Arrow left side'},
        {'value' => 'rharrow',          'name' => 'Arrow right side'},
        {'value' => 'bowtie',           'name' => 'Arrows both sides'},
        {'value' => 'text',             'name' => 'Text label (+ wide box)'}
    );
                                                                                
my @pointer_cols = (
        {'value' => 'purple',   'name'=> 'Purple'},
        {'value' => 'magenta',  'name'=> 'Magenta'},
        {'value' => 'red',      'name' =>'Red'},
        {'value' => 'orange',   'name' => 'Orange'},
        {'value' => 'brown',    'name'=> 'Brown'},
        {'value' => 'green',    'name'=> 'Green'},
        {'value' => 'darkgreen','name'=> 'Dark Green'},
        {'value' => 'blue',     'name'=> 'Blue'},
        {'value' => 'darkblue', 'name'=> 'Dark Blue'},
        {'value' => 'violet',   'name'=> 'Violet'},
        {'value' => 'grey',     'name'=> 'Grey'},
        {'value' => 'darkgrey', 'name'=> 'Dark Grey'}
    );

my @zmenus = (
        {'name'=>'on',  'value'=>'on'},
        {'name'=>'off',  'value'=>'off'}
    );
                                                                                
my @rows = (
        {'name'=>'1',  'value'=>'1'},
        {'name'=>'2',  'value'=>'2'},
        {'name'=>'3',  'value'=>'3'},
        {'name'=>'4',  'value'=>'4'}
    );


# widget blocks for image configuration forms

sub config_hilites {
                                                                                
  my ($form, $object, $sets) = @_;
  $sets = 1 if !$sets;
  my @defaults = ( 
                ['first',   'rharrow',  'red'],
                ['second',  'lharrow',  'blue'],
                ['third',   'box',      'green'],
  );
                      
  for (my $i=0; $i<$sets; $i++) {                                                  
    $form->add_element(
        'type'   => 'DropDown',
        'select' => 'select',
        'name'   => "style_$i",
        'label'  => "Style for $defaults[$i][0] pointer set:",
        'values' => \@pointer_styles,
        'value'  => $object->param( "style_$i" ) || $defaults[$i][1],
    );
    $form->add_element(
        'type'   => 'DropDown',
        'select' => 'select',
        'name'   => "col_$i",
        'label'  => "Colour for $defaults[$i][0] pointer set:",
        'values' => \@pointer_cols,
        'value'  => $object->param( "col_$i" ) || $defaults[$i][2],
    );
  }
  $form->add_element(
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'zmenu',
    'label'  => 'Display mouseovers on menus:',
    'values' => \@zmenus,
    'value'  => $object->param( 'zmenu' ) || 'on',
  );
                                                                                
}

sub config_tracks {

  my ($form, $object) = @_;

  my @trackboxes = (
        {'name'=>'Show max/min lines',          'value'=>'maxmin'},
        {'name'=>'Show GC content frequency',   'value'=>'track_Vpercents'},
        {'name'=>'Show SNP frequency',          'value'=>'track_Vsnps'},
        {'name'=>'Show gene frequency',         'value'=>'track_Vgenes'}
    );
  foreach my $box (@trackboxes) {
    $form->add_element(
        'type'   => 'CheckBox',
        'label'  => $box->{'name'},
        'name'   => $box->{'value'},
        'id'     => $box->{'value'},
        'value'  => 'on',
    );
  }
  $form->add_element(
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'col',
    'label'  => 'Track colour:',
    'values' => \@pointer_cols,
    'value'  => $object->param( 'col' ) || 'purple',
  );
}

sub config_karyotype {
                                                                                
  my ($form, $object) = @_;
                                                                                
  $form->add_element(
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'rows',
    'label'  => 'Number of rows of chromosomes:',
    'values' => \@rows,
    'value'  => $object->param( 'rows' ) || '2',
  );
  $form->add_element(
    'type'   => 'PosInt',
    'name'   => 'chr_length',
    'label'  => 'Height of the longest chromosome (pixels):',
    'value'  => $object->param( 'chr_length' ) || '200',
    'size'   => '4'
  );
  $form->add_element(
    'type'   => 'Int',
    'name'   => 'h_padding',
    'label'  => 'Padding around chromosomes (pixels):',
    'value'  => $object->param( 'h_padding' ) || '4',
    'size'   => '4'
  );
  $form->add_element(
    'type'   => 'Int',
    'name'   => 'h_spacing',
    'label'  => 'Spacing between chromosomes (pixels):',
    'value'  => $object->param( 'h_spacing' ) || '6',
    'size'   => '4'
  );

  $form->add_element(
    'type'   => 'Int',
    'name'   => 'v_padding',
    'label'  => 'Spacing between rows (pixels):',
    'value'  => $object->param( 'v_padding' ) || '50',
    'size'   => '4'
  );
                                                                                
}

sub config_data {

  my ($form, $object) = @_;

  $form->add_element(
    'type'   => 'Information',
    'value'  => qq(Accepted <a href="javascript:window.open('/Homo_sapiens/helpview?se=1;kw=karyoview#FileFormats', 'helpview', 'width=400,height=500,resizable,scrollbars'); void(0);">file formats</a>),
  );
  $form->add_element(
    'type'   => 'Text',
    'name'   => 'paste_file',
    'label'  => 'Paste file:',
    'value'  => '',
  );
  $form->add_element(
    'type'   => 'File',
    'name'   => 'upload_file',
    'label'  => 'Upload file:',
    'value'  => '',
  );
  $form->add_element(
    'type'   => 'String',
    'name'   => 'url_file',
    'label'  => 'File URL:',
    'value'  => '',
  );
                                                                                
}

#-----------------------------------------------------------------
# MAPVIEW COMPONENTS    
#-----------------------------------------------------------------

## Creates a clickable imagemap of a single chromosome, 
## with extra tracks - GC, SNPs and genes

sub chr_map {
  my( $panel, $object ) = @_;
  my $config_name = 'Vmapview';
  my $species   = $object->species;
  my $chr_name  = $object->chr_name;

  my $config = $object->get_userconfig($config_name);
  my $ideo_height = $config->{'_image_height'}; 
  my $top_margin  = $config->{'_top_margin'};
  my $hidden = {
            'seq_region_name'   => $chr_name,
            'seq_region_width'  => '100000',
            'seq_region_left'   => '1',
            'seq_region_right'  => $object->length,
            'click_right'       => $ideo_height+$top_margin,
            'click_left'        => $top_margin,
    };
  # make a drawable container
  my $image    = $object->new_karyotype_image();
  $image->imagemap           = 'no';
  $image->cacheable          = 'yes';
  $image->image_name         = 'mapview-'.$species.'-'.$chr_name;
  $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/contigview", 'hidden'=> $hidden);
  $image->add_tracks($object, $config_name);
  $image->karyotype($object, '', $config_name);
  warn ">>";
  $image->caption = 'Click on the image above to zoom into that point';
  warn ">>";
  $panel->add_image( $image->render, $image->{'width'} );
  return 1;
}


#--------------------------------------------------------------------------

sub stats {
  my( $panel, $chr ) = @_;
   
  my $species = $chr->species;

  my $chr_name = $chr->chr_name;
  my $label = "Chromosome $chr_name";
 
  my @orderlist = (    
           'Length',
           'known protein_coding Gene Count',
           'novel protein_coding Gene Count',
           'pseudogene Gene Count',
           'miRNA Gene Count',
           'ncRNA Gene Count',
           'rRNA Gene Count',
           'snRNA Gene Count',
           'snoRNA Gene Count',
           'tRNA Gene Count',
           'misc_RNA Gene Count',
           'SNP Count');
  my $html = qq(<br /><table cellpadding="4">);
  my $stats;
  my %chr_stats;
  foreach my $attrib (@{$chr->Obj->get_all_Attributes()}) {
    my $name = $attrib->name();
    my $value = $attrib->value();
    $chr_stats{$attrib->name()} = $attrib->value();
  }

  $chr_stats{'Length'} = ($chr->chr_name eq 'ALL') ? $chr->max_chr_length : $chr->length ;

  for my $stat (@orderlist){
    my $value = $chr->thousandify( $chr_stats{$stat} );
    next if !$value;
    my $bps_label = ($stat eq "Length") ? 'bps' : '&nbsp;';
    $stat =~ s/protein_coding/Protein-coding/; 
    $stat =~ s/_/ /g; 
    $stat =~ s/ Count$/s/;
    $stat = ucfirst($stat) unless $stat =~ /^[a-z]+RNA/;
    $html .= qq(<tr><td><strong>$stat:</strong></td>
                        <td style="text-align:right">$value</td>
                        <td>$bps_label</td>
                    </tr>);
    $stats = 1 ;
  }
  unless ($stats) {
    $html .= qq(<tr><td><strong>Could not load chromosome stats</strong><td></tr>);
  }          
  $html .= qq(  </table>
  <p>For more information on gene statistics, see the <a href="/$species/helpview">Help</a> page</p>  );

  $panel->add_row( $label, $html );
  return 1;
}

#--------------------------------------------------------------------------

sub change_chr {
  my ( $panel, $object ) = @_;
  my $label = 'Change Chromosome';
  my $html = qq(
   <div>
     @{[ $panel->form( 'change_chr' )->render() ]}
  </div>);

  $panel->add_row( $label, $html );
  return 1;
}

sub change_chr_form {

  my( $panel, $object ) = @_;
  my $script = $object->script;

  my $form = EnsEMBL::Web::Form->new( 'change_chr', "/@{[$object->species]}/$script", 'get' );

  my @chrs = chr_list($object);
  my $chr_name = $object->chr_name;

  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'on_change' => 'submit',
    'name'     => 'chr',
    'label'    => 'Chromosome',
    'values'   => \@chrs,
    'value'    => $chr_name,
    'button_value' => 'Go'
  );
  return $form;
}

#--------------------------------------------------------------------------

sub jump_to_contig {
  my ( $panel, $object ) = @_;

  my $label = 'Jump to ContigView';
  my $html = qq(
   <div>
     @{[ $panel->form( 'jump_to_contig' )->render() ]}
  </div>);

  $panel->add_row( $label, $html );
  return 1;
}

sub jump_to_contig_form {
  my( $panel, $object ) = @_;

  my @errors = ('', 
    qq(Sorry, there was a problem locating the requested DNA sequence. Please check your choices - including chromosome name - and try again.),
    qq(Sorry, your chosen anchor points appear to be on different sequence regions. Please check your choices and try again.)
    );

  my $form = EnsEMBL::Web::Form->new( 'jump_to_contig', "/@{[$object->species]}/anchorview", 'post' );
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)); 
  $form->add_element(
        'type' => 'Information',
        'value' => qq(<p>
      Choose two features from this
      chromosome as anchor points and display the region between them.
      Both features must be mapped to the current $sitetype golden
      tiling path.  If you select "None" for the second feature,
      the display will be based around the first feature.
    </p>
    <p>
      <em>Please note that if you select widely spaced features there
      may be an significant delay while $sitetype builds the DNA display</em>.
    </p>));

  if ($object->param('error')) {
    my $error_text = $errors[$object->param('error')];
    $form->add_element('type' => 'Information',
        'value' => '<p class="error">'.$error_text.' If you continue to have a problem, please contact <a href="mailto:helpdesk@ensembl.org">helpdesk@ensembl.org</a>.</strong></p>'
        );
  }

  $form->add_element('type' => 'Hidden', 'name' => 'chr', 'id' => 'chr', 'value' => $object->chr_name);

  $form->add_element('type' => 'SubHeader', 'value' => 'Region');

  my @types = (
        {'value'=>'band', 'name'=>'Band'},
        {'value'=>'region', 'name'=>'Region'},
        {'value'=>'marker', 'name'=>'Marker'},
        {'value'=>'bp', 'name'=>'Base pair'},
        {'value'=>'gene', 'name'=>'Gene'},
        {'value'=>'peptide', 'name'=>'Peptide'},
    );
  my @types_1 = @types;
  $form->add_element(
    'type'   => 'DropDownAndString',
    'select' => 'select',
    'name'   => 'type1',
    'label'  => 'From (type):',
    'values' => \@types_1,
    'value'  => $object->param( 'type1' ) || 'region',
    'string_name'  => 'anchor1',
    'string_label' => 'From (value)',
    'string_value' => $object->param( 'anchor1' ),
    'style'  => 'medium',
    'required' => 'yes'
  );
  unshift (@types,  {'value'=>'none', 'name'=>'None'});
  $form->add_element(
    'type'   => 'DropDownAndString',
    'select' => 'select',
    'name'   => 'type2',
    'label'  => 'To (type):',
    'values' => \@types,
    'value'  => $object->param('type2') || 'region',
    'string_name' => 'anchor2',
    'string_label' => 'To (value)',
    'style'  => 'medium',
    'string_value' => $object->param( 'anchor2' )
  );
  $form->add_element('type' => 'SubHeader', 'value' => 'Context');
  $form->add_element(
    'type'     => 'String',
    'required' => 'no',
    'value'    => '',
    'style'    => 'short',
    'name'     => 'downstream',
    'label'    => 'Bp downstream'
  );
  $form->add_element(
    'type'     => 'String',
    'style'    => 'short',
    'required' => 'no',
    'value'    => '', 
    'name'     => 'upstream',
    'label'    => 'Bp upstream'
  );

  $form->add_element( 'type' => 'Submit', 'value' => 'Go', 'spanning' => 'center' );
  return $form ;
}

#----------------------------------------------------------------------------
# SYNTENYVIEW COMPONENTS  
#-----------------------------------------------------------------

sub synteny_map {

    my( $panel, $object ) = @_;
    my $species = $object->species;
    
    my $loc = $object->param('loc') ? $object->evaluate_bp($object->param('loc')) : undef ;
    
    my $other = $object->param('otherspecies')||$object->param('species') || ($species eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
    my %synteny = $object->species_defs->multi('SYNTENY');
    my $chr = $object->chr_name;
    my %chr_1  =  map { ($_,1) } @{$object->all_chromosomes};
    my $chr_2 = scalar  @{$object->species_defs->other_species( $other , 'ENSEMBL_CHROMOSOMES' ) };
        
    unless ($synteny{ $other }){
        $panel->problem('fatal', "Can't display synteny",  "There is no synteny data for these two species ($species and $other)") ;
        return undef;
    }
    unless ( $chr_1{$chr} && $chr_2>0){
        $panel->problem( 'fatal', "Unable to display", "SyntenyView only displays synteny between real chromosomes - not fragments") ;
        return undef;
    }

    #my $databases = $object->DBConnection->get_databases('core','compara' );
    #my $databases2 = $object->DBConnection->get_databases_species( $other,'core' );

    my $ka  = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
    my $ka2 = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
    my $sa  = $object->get_adaptor('get_syntenyAdaptor', 'compara');

    $sa->setSpecies( $object->species_defs->multidb->{'ENSEMBL_COMPARA'}{'NAME'}, $species , $other );
    my $raw_data = $sa->get_synteny_for_chromosome( $chr );
    
    ## checks done ## 
    my $chr_length = $object->length;
    my @localgenes = @{$object->get_synteny_local_genes};
    $loc = ( @localgenes ?
         $localgenes[0]->start : 1 ); # Jump loc to the location of the genes
        
    my $Config = $object->get_userconfig( 'Vsynteny' );
    $Config->{'other_species_installed'} = $synteny{ $other };
    $Config->container_width( $chr_length );

    my $image = $object->new_vimage(
        {   'chr'           => $chr,
            'ka_main'       => $ka,
            'sa_main'       => $object->get_adaptor('get_SliceAdaptor'),
            'ka_secondary'  => $ka2,
            'sa_secondary'  => $object->get_adaptor('get_SliceAdaptor', 'core', $other),
            'synteny'       => $raw_data,
            'other_species' => $other,
            'line'          => $loc
        }, 
        $Config
    );
    $image->imagemap           = 'yes';
    $image->cacheable          = 'yes';
    $image->image_name         = 'syntenyview-'.$species.'-'.$chr.'-'.$other;

    $panel->add_image( $image->render, $image->{'width'} );
    return 1;

}

sub syn_matches {

    my( $panel, $object ) = @_;
    my $species = $object->species;
    (my $sp_tidy = $species) =~ s/_/ /; 
    my $other = $object->param('otherspecies')||$object->param('species') || ($species eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
    (my $other_tidy = $other) =~ s/_/ /; 

    my $table = EnsEMBL::Web::Document::SpreadSheet->new(); 

    $table->add_columns(
        {'key' => 'genes', 'title' => "<i>$sp_tidy</i> Genes", 'width' => '40%', 'align' => 'left' },
        {'key' => 'arrow', 'title' => "&nbsp;", 'width' => '20%', 'align' => 'center' },
        {'key' => 'homologues', 'title' => "<i>$other_tidy</i> Homologues", 'width' => '40%', 'align' => 'left' },
        );
    my $data = $object->get_synteny_matches;
    my ($sp_links, $arrow, $other_links, $data_row);
    foreach my $row ( @$data ) {

        my $sp_stable_id        = $$row{'sp_stable_id'};
        my $sp_synonym          = $$row{'sp_synonym'};
        my $sp_length           = $$row{'sp_length'};
        my $other_stable_id     = $$row{'other_stable_id'};
        my $other_synonym       = $$row{'other_synonym'};
        my $other_length        = $$row{'other_length'};
        my $other_chr           = $$row{'other_chr'};
        my $homologue_no        = $$row{'homologue_no'};

        $arrow = $homologue_no ? '-&gt;' : '';

        $sp_links = qq(<a href="/$species/geneview?gene=$sp_stable_id"><strong>$sp_synonym</strong></a> \($sp_length\)<br />[<a href="/$species/contigview?gene=$sp_stable_id">ContigView</a>]);
        $other_links = qq(<a href="/$other/geneview?gene=$other_stable_id"><strong>$other_synonym</strong></a><br />[<a href="/$other/contigview?gene=$other_stable_id" title="Chr $other_chr: $other_length">ContigView</a>] [<a href="/$species/multicontigview?gene=$sp_stable_id;s1=$other;g1=$other_stable_id">MultiContigView</a>]);
        $data_row = { 'genes'  => $sp_links, 'arrow' => $arrow, 'homologues' => $other_links };
        $table->add_row( $data_row );
    }
    $panel->add_row('Homology Matches', $table->render);
    return 1;

}

sub nav_homology {
    
    my ($panel, $object) = @_;
    my $chr = $object->chr_name;

    my $species = $object->species;
    my $other = $object->param('otherspecies') || $object->param('species') || ($species eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');

    my $label = 'Navigate Homology';

    my @data = @{$object->get_synteny_nav};

    my $html = qq(<p class="center">
<a href= "/$species/syntenyview?otherspecies=$other;chr=$chr;loc=).$data[0].';pre=1">Upstream</a> (&lt;'.$data[2].') &nbsp;&nbsp; '.
qq(<a href="/$species/syntenyview?otherspecies=$other;chr=$chr;loc=).$data[1].'">Downstream</a> (&gt;'.$data[3].')</p>';
    $panel->add_row( $label, $html );
    return 1;
}


#----------------------------------------------------------------------------
# KARYOVIEW COMPONENTS  
#-----------------------------------------------------------------

sub image_choice {

  my ($panel, $object) = @_;

  my $chr_name = $object->param('chr');
  my $species = $object->species;

  my $html = qq(<h2>Karyoview</h2>
    <p>This page enables you to display your own data on a customisable karyotype image.</p>
    <p>Click on one of the images below to select a display type:</p>
    <table cellspacing="20" style="width:100%">
    <tr>
    <th class="center"><a href="/$species/karyoview?display=location;chr=$chr_name">Show location of features</a></th>
    <th class="center"><a href="/$species/karyoview?display=density;chr=$chr_name">Show density of features</a></th>
    </tr>
    <tr>
    <td class="center"><a href="/$species/karyoview?display=location;chr=$chr_name"><img src="/img/misc/display_location.png" alt="Chromosome with location pointers" width="332" height="495" /></a></td>
    <td class="center"><a href="/$species/karyoview?display=density;chr=$chr_name"><img src="/img/misc/display_density.png" alt="Chromosome with density tracks" width="388" height="500" /></a></td>
    </tr>
    </table>);
  
  $panel->{'raw'} = $html;
  return 1;
}

#--------------------------------------------------------------------------

sub image_config {
  my ( $panel, $object ) = @_;

  my $html = qq(
   <div class="formpanel" style="width:95%">
     @{[ $panel->form( 'image_config' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}

sub image_config_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'image_config', "/@{[$object->species]}/karyoview", 'post' );

  $form->add_element('type' => 'SubHeader', 'value' => 'Chromosome(s) to display');
  my @chrs = chr_list($object);
  push @chrs, {'name'=>'ALL', 'value'=>'ALL'} ;
  my $chr_name = $object->param('chr') || 'ALL';
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'chr',
    'label'    => 'Chromosome',
    'values'   => \@chrs,
    'value'    => $chr_name,
  );

  $form->add_element('type' => 'SubHeader', 'value' => 'Configure Display Options');
  if ($object->param('display') eq 'location') {
    config_hilites($form, $object);   
  }
  else {
    config_tracks($form, $object);
  }
  config_karyotype($form, $object);   

  $form->add_element('type' => 'SubHeader', 'value' => 'Upload data set');
  config_data($form, $object);   
  $form->add_element('type' => 'Hidden', 'name' => 'display', 'value' => $object->param('display'));

  $form->add_element( 'type' => 'Submit', 'value' => 'Go', 'spanning'=>'inline' );
  return $form ;
}

#----------------------------------------------------------------------------

sub show_karyotype {

    my( $panel, $object ) = @_;
  
    # CONFIGURATION
    my ($config_name, $max_length);
    my $chr = $object->chr_name;
    if ($chr eq 'ALL') {
        $config_name = 'Vkar2view';
        $max_length = $object->max_chr_length;
    }
    else {
        $config_name = 'Vmap2view';
        $max_length = $object->length;
    }
    my $config = $object->user_config_hash($config_name);
    # PARSE DATA
    my $parser;
    if ($object->param('display') eq 'density') {
        $parser = Data::Bio::Text::DensityFeatureParser->new();
        $parser->set_filter($chr);  # filter chromosomes that aren't used
        $parser->current_key($object->param('defaultlabel') || 'default'); #add in default label
        my $bins   = 150;
        $parser->no_of_bins($bins);
        $parser->bin_size(int($max_length/$bins));
    }
    else {
        $parser = Data::Bio::Text::FeatureParser->new();
    }
    $object->parse_user_data($parser);

    # CREATE IMAGE OBJECT
    my $image    = $object->new_karyotype_image();
    $image->imagemap           = 'no';
    $image->cacheable          = 'no';
    $image->image_name         = 'karyoview-'.$object->species.'-'.$object->chr_name;
    # Add features
    my $pointers;
    if ($object->param('display') eq 'density') {
        $image->add_tracks($object, $config_name, $parser);
    }
    else {
        $pointers = $image->add_pointers($object, {'config_name'=>$config_name, 'parser'=>$parser, 'color' => $object->param("col_0"), 'style' => $object->param("style_0")});
    }
    # create image file and render HTML
    $image->karyotype($object, [$pointers], $config_name);
    $panel->print($image->render);
    return 1;

}

1;
