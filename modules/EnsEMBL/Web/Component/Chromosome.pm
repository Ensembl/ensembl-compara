package EnsEMBL::Web::Component::Chromosome;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Feature;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;

use strict;
use warnings;
no warnings "uninitialized";

@EnsEMBL::Web::Component::Chromosome::ISA = qw( EnsEMBL::Web::Component);


#-----------------------------------------------------------------
# MAPVIEW COMPONENTS    
#-----------------------------------------------------------------

## Creates a clickable imagemap of a single chromosome, 
## with extra tracks - GC, SNPs and genes

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
  my $script = $object->species_defs->NO_SEQUENCE ? 'cytoview' : 'contigview';
  $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/$script", 'hidden'=> $hidden);
  $image->add_tracks($object, $config_name);
  $image->karyotype($object, '', $config_name);
  $image->caption = 'Click on the image above to zoom into that point';
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
    'SNP Count',
    'Number of fingerprint contigs',
    'Number of clones selected for sequencing',
    'Number of clones sent for sequencing',
    'Number of accessioned sequence clones',
    'Number of finished sequence clones',
    'Total number of sequencing clones',
    'Raw percentage of map covered by sequence clones',
  );
  my $html = qq(<br /><table cellpadding="4">);
  my $stats;
  my %chr_stats;
  foreach my $attrib (@{$chr->Obj->get_all_Attributes()}) {
    my $name = $attrib->name();
    my $value = $attrib->value();
    $chr_stats{$attrib->name()} += $attrib->value();
  }

  $chr_stats{'Length'} = ($chr->chr_name eq 'ALL') ? $chr->max_chr_length : $chr->length ;

  for my $stat (@orderlist){
    my $value = $chr->thousandify( $chr_stats{$stat} );
    next if !$value;
    my $bps_label = ($stat eq "Length") ? 'bps' : '&nbsp;';
       $bps_label = '%' if $stat =~ /percentage/;
    $stat = 'Estimated length' if $stat eq 'Length' && $chr->species_defs->NO_SEQUENCE;
    $stat =~ s/Raw p/P/;
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
  <p>For more information on gene statistics, see the <a href="javascript:void(window.open('/$species/helpview?kw=mapview;se=1','helpview','width=700,height=550,resizable,scrollbars'))">MapView help</a> page</p>  );

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

  my $label = $object->species_defs->NO_SEQUENCE ? 'Jump to CytoView' : 'Jump to ContigView';
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

  my $form = EnsEMBL::Web::Form->new( 'jump_to_contig', "/@{[$object->species]}/jump_to_contig", 'post' );
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)); 
  $form->add_element(
        'type' => 'Information',
        'value' => qq(<p>
      Choose two features from this chromosome as anchor points and display the region between them.
      Both features must be mapped to the current $sitetype assembly.  If you select "None" for the second feature,
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

  my @types = @{$object->find_available_anchor_points};
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

    my $ka  = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
    my $ka2 = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
    my $raw_data = $object->Obj->get_all_compara_Syntenies($other);   

 
    ## checks done ## 
    my $chr_length = $object->length;
    my ($localgenes,$offset) = $object->get_synteny_local_genes;
    $loc = ( @$localgenes ? $localgenes->[0]->start+$offset : 1 ); # Jump loc to the location of the genes
        
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
    # $image->cacheable          = 'yes';
    $image->image_name         = 'syntenyview-'.$species.'-'.$chr.'-'.$other;

    $panel->add_image( $image->render, $image->{'width'} );
    foreach my $o (@$raw_data) { ## prevents memory leak!
      $o->release_tree;
    }
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
        if( $other_stable_id ) {
          $other_links = qq(<a href="/$other/geneview?gene=$other_stable_id"><strong>$other_synonym</strong></a><br />);
          $other_links .= "($other_length)<br />";
          $other_links .= qq([<a href="/$other/contigview?gene=$other_stable_id" title="Chr $other_chr: $other_length">ContigView</a>] [<a href="/$species/multicontigview?gene=$sp_stable_id;s1=$other;g1=$other_stable_id">MultiContigView</a>]);
        } else {
          $other_links = 'No homologues';
        }
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

sub kv_add        { _wrap_form($_[0], $_[1], 'kv_add'); }
sub kv_datacheck  { _wrap_form($_[0], $_[1], 'kv_datacheck'); }
sub kv_tracks     { _wrap_form($_[0], $_[1], 'kv_tracks'); }
sub kv_layout     { _wrap_form($_[0], $_[1], 'kv_layout'); }

sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub kv_display {

  my( $panel, $object, $node ) = @_;
  
## IMAGE
  ## Configuration
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
  my $group = 1;

  ## Create image object
  my $image    = $object->new_karyotype_image();
  $image->imagemap    = 'yes';
  $image->cacheable   = 'no';
  $image->image_name  = 'karyoview-'.$object->species.'-'.$object->chr_name;
  ## Add features
  my @params = $object->param;
  my $tracks = 0;
  foreach my $param (@params) {
    $tracks++ if $param =~ /^cache_file_/;
    ## make sure extra Ensembl tracks get grouped with chromosome
    $group++ if $param =~ /^track_V/;
  }

  my $all_pointers;
  if ($tracks) {
    for (my $i = 0; $i < $tracks; $i++) {
      my $pointers = [];
      my $track_id = $i+1;
      my $parser;

      if ($object->param("style_$track_id") =~ /line|bar|outline/) {
        ## parse data
        $parser = Data::Bio::Text::DensityFeatureParser->new();
        $parser->set_filter($chr);  # filter chromosomes that aren't used
        $parser->current_key($object->param('defaultlabel') || 'default'); #add in default label
        my $bins   = 150;
        $parser->no_of_bins($bins);
        $parser->bin_size(int($max_length/$bins));
        $object->parse_user_data($parser, $track_id);
        if (ref($parser->counts) eq 'HASH') {
          $group += scalar(keys %{$parser->counts});
        }
  
        ## create image with parsed data
        $image->add_tracks($object, $config_name, $parser, $track_id);
      }
      else {
        ## parse data
        $parser = Data::Bio::Text::FeatureParser->new();
        $object->parse_user_data($parser, $track_id);

        my $zmenu_config = {
          'caption' => 'features',
          'entries' => ['userdata'],
        };

        ## create image with parsed data
        $pointers = $image->add_pointers(
          $object, 
          {
          'config_name'=>$config_name, 
          'zmenu_config' => $zmenu_config,
          'parser'=>$parser, 
          'color' => $object->param("col_$track_id"), 
          'style' => $object->param("style_$track_id")
          }
        );
        push @$all_pointers, $pointers;
      }
    }
  }
  else {
    if ($object->chr_name eq 'ALL') {
      $image->do_chr_layout($object, $config_name);
    }
  }
  ## add extra formats if selected
  if ($object->param('format_pdf')) {
    push(@{$image->{'image_formats'}}, 'pdf');  
  }
  if ($object->param('format_svg')) {
    push(@{$image->{'image_formats'}}, 'svg');  
  }
  if ($object->param('format_eps')) {
    push(@{$image->{'image_formats'}}, 'postscript');  
  }

  ## set this just before rendering, to make sure we group all user tracks together
  $config->{'_group_size'} = $group; 

  $image->karyotype($object, $all_pointers, $config_name);
  # create image file and render HTML
  $panel->print($image->render);

## Hidden form
  my $html = $panel->form('kv_display')->render();

## Blank form going back to first node (passing no parameters)
  my $species = $object->species;
  my $script  = $object->script;
  $html .= qq(<form action="/$species/$script" method="get">
<p><input type="submit" name="submit_kv_add" value="Start again with new data" class="red-button" /></p>
</form>);

  $panel->print($html);

  return 1;
}


1;
