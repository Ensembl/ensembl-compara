package EnsEMBL::Web::Component::Gene;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Component::Slice;
#use EnsEMBL::Web::Component::Transcript qw(_sort_similarity_links);

use Data::Dumper;
use Bio::AlignIO;
use IO::String;


sub sequence {
  my( $panel, $object ) = @_;
  return EnsEMBL::Web::Component::Slice::sequence_display(
    $panel, $object->get_slice_object()
  );
}
sub markup_options {
  my( $panel, $object ) =@_;
  $panel->add_row( 'Markup options', "<div>@{[ $panel->form( 'markup_options' )->render ]}</div>" );
  return 1;
}

sub markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'markup_options', "/@{[$object->species]}/geneseqview", 'get' );

  # make array of hashes for dropdown options
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',   'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'gene', 'value' => $object->stable_id );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
    'value' => $object->param('flank5_display')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
    'value' => $object->param('flank3_display')
  );

  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) ||
    'Ensembl';
  my $exon_display = [
    { 'value' => 'core'       , 'name' => "$sitetype exons" },
    $object->species_defs->databases->{'ENSEMBL_VEGA'} ? { 'value' => 'vega'           , 'name' => 'Vega exons' } : (),
    $object->species_defs->databases->{'ENSEMBL_OTHEFEATURES'}  ? { 'value' => 'otherfeatures'  , 'name' => 'EST-gene exons' } : (),
    { 'value' => 'prediction' , 'name' => 'Ab-initio exons' },
    { 'value' => 'off'        , 'name' => 'No exon markup' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_display',
    'label'    => 'Exons to display',
    'values'   => $exon_display,
    'value'    => $object->param('exon_display')
  );
  my $exon_ori = [
    { 'value' =>'fwd' , 'name' => 'Forward only' },
    { 'value' =>'rev' , 'name' => 'Reverse only' },
    { 'value' =>'all' , 'name' => 'Both orientations' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => 'Exons on strand',
    'values'   => $exon_ori,
    'value'    => $object->param('exon_ori')
  );
  if( $object->species_defs->databases->{'ENSEMBL_GLOVAR'} || $object->species_defs->databases->{'ENSEMBL_VARIATION'} ) {
    my $snp_display = [
      { 'value' =>'snp' , 'name' => 'All Variations' },
      { 'value' =>'off' , 'name' => 'Do not show Variations' },
    ];
    $form->add_element(
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => $snp_display,
      'value'    => $object->param('snp_display')
    );
  }
  my $line_numbering = [
    { 'value' =>'sequence' , 'name' => 'Relative to sequence' },
    { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
    { 'value' =>'off'      , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'line_numbering',
    'label'    => 'Line numbering',
    'values'   => $line_numbering,
    'value'    => $object->param('line_numbering')
  );
  $form->add_element(
    'type'  => 'Submit', 'value' => 'Update'
  );
  return $form;
}


sub align_sequence {
  my( $panel, $object ) = @_;
  return EnsEMBL::Web::Component::Slice::align_sequence_display(
    $panel, $object
  );
}

sub align_markup_options {
  my( $panel, $object ) =@_;
  $panel->add_row( 'Markup options', "<div>@{[ $panel->form( 'align_markup_options' )->render ]}</div>" );
  return 1;
}

sub markup_options {
  my( $panel, $object ) =@_;
  $panel->add_row( 'Markup options', "<div>@{[ $panel->form( 'markup_options' )->render ]}</div>" );
  return 1;
}

sub align_markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'align_markup_options', "/@{[$object->species]}/geneseqalignview", 'post' );

  # make array of hashes for dropdown options
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',   'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'gene', 'value' => $object->stable_id );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
    'value' => $object->param('flank5_display')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
    'value' => $object->param('flank3_display')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "Alignment width",  'name' => 'display_width',
    'value' => $object->param('display_width'),
    'notes' => 'Number of bp per line in alignments'
  );

  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) ||
    'Ensembl';
  my $exon_display = [
    { 'value' => 'core'       , 'name' => "$sitetype exons" },
    $object->species_defs->databases->{'ENSEMBL_VEGA'} ? { 'value' => 'vega'       ,   'name' => 'Vega exons' } : (),
    $object->species_defs->databases->{'ENSEMBL_OTHERFEATURES'}  ? { 'value' => 'otherfeatures', 'name' => 'EST-gene exons' } : (),
    { 'value' => 'prediction' , 'name' => 'Ab-initio exons' },
    { 'value' => 'off'        , 'name' => 'No exon markup' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_display',
    'label'    => 'Exons to display',
    'values'   => $exon_display,
    'value'    => $object->param('exon_display')
  );
  my $exon_ori = [
    { 'value' =>'fwd' , 'name' => 'Forward only' },
    { 'value' =>'rev' , 'name' => 'Reverse only' },
    { 'value' =>'all' , 'name' => 'Both orientations' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => 'Exons on strand',
    'values'   => $exon_ori,
    'value'    => $object->param('exon_ori')
  );
  if( $object->species_defs->databases->{'ENSEMBL_GLOVAR'} || $object->species_defs->databases->{'ENSEMBL_VARIATION'} ) {
    my $snp_display = [
      { 'value' =>'snp' , 'name' => 'All Variations' },
      { 'value' =>'off' , 'name' => 'Do not show Variations' },
    ];
    $form->add_element(
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => $snp_display,
      'value'    => $object->param('snp_display')
    );
  }
  my $line_numbering = [
    { 'value' =>'sequence' , 'name' => 'Relative to sequence' },
    { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
    { 'value' =>'off'      , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'line_numbering',
    'label'    => 'Line numbering',
    'values'   => $line_numbering,
    'value'    => $object->param('line_numbering')
  );

#    { 'value' =>'exon', 'name' => 'Conserved regions within exons' },
  my $conservation = [
    { 'value' =>'all' , 'name' => 'All conserved regions' },

    { 'value' =>'off' , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'conservation',
    'label'    => 'Conservation regions',
    'values'   => $conservation,
    'value'    => $object->param('conservation')
  );

  my $codons_display = [
    { 'value' =>'all' , 'name' => 'START/STOP codons' },

    { 'value' =>'off' , 'name' => "Do not show codons" },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'codons_display',
    'label'    => 'Codons',
    'values'   => $codons_display,
    'value'    => $object->param('codons_display')
  );

  my $title_display = [
    { 'value' =>'all' , 'name' => 'Include `title` tags' },

    { 'value' =>'off' , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'title_display',
    'label'    => 'Title display',
    'values'   => $title_display,
    'value'    => $object->param('title_display'),
    'notes'    => "On mouse over displays exon IDs, length of insertions and SNP\'s allele"
  );

  my $aselect = $object->param("RGselect") || "NONE";

  my %alignments = $object->species_defs->multiX('ALIGNMENTS');

# From release to release the alignment ids change so we need to 
# check that the passed id is still valid.

  if (! exists ($alignments{$aselect})) {
      $aselect = 'NONE';
      $object->param("RGselect", "NONE");
  }

  $form->add_element('type' => 'RadioGroup',
         'name' => 'RGselect',
         'values' =>[{name=> "<b>No alignments</b>", value => "NONE", checked => $aselect eq "NONE" ? "yes" : undef}],
         'label' => 'View in alignment with',
         'noescape' => 'yes',
         );
  my @align_select;

  foreach my $id (
      sort { 10 * ($alignments{$b}->{'type'} cmp $alignments{$a}->{'type'}) + ($a <=> $b) }
      grep { $alignments{$_}->{'species'}->{$object->species} } 
      keys (%alignments)) {

      my $label = $alignments{$id}->{'name'};
      my @species = grep {$_ ne $object->species} sort keys %{$alignments{$id}->{'species'}};

      my @multi_species;
      if ( scalar(@species) > 1) {
    my %selected_species = map { $_ => 1} $object->param("ms_$id");

    foreach my $v (@species) {
        (my $name = $v) =~ s/_/ /g;
        if ($selected_species{$v}) {
      push @multi_species, {"value"=>$v, "name"=>$name, "checked"=>"yes"};
        } else {
      push @multi_species, {"value"=>$v, "name"=>$name};
        }
    }
    $label = "<b>$label</b> (click on checkboxes to select species)";

      } else {
    ($label = "<b>$species[0]</b>") =~ s/_/ /g;
      }

      $form->add_element('type' => 'RadioGroup',
       'name' => 'RGselect',
       'values' =>  [{name=> $label, 'value' => $id, checked=>$aselect eq "$id" ? "yes" : undef}],
       'label' => '     ',
       'class' => 'radiocheck1col',
       'noescape' => 'yes'
         );


      if (@multi_species) {
    $form->add_element(
           'type' => 'MultiSelect',
           'name'=> "ms_$id",
#           'label'=> ' ',
           'values' => \@multi_species,
           'value' => $object->param("ms_$id")
           );
      }


  }
  
  $form->add_element(
    'type'  => 'Submit', 'value' => 'Update' 
  );

  return $form;
}

sub name {
  my( $panel, $object ) = @_;
  
  my $page_type= $object->[0];
  my @vega_info=();
  
  if($page_type eq 'Transcript'){
    my $trans= $object->transcript;


    my @similarity_links= @{$object->get_similarity_hash($trans)};
  
    my @vega_links= grep {$_->{db_display_name} eq 'Havana transcripts'} @similarity_links;
    my $urls= $object->ExtURL;
  
    foreach my $link(@vega_links){

      my $id= $link->{display_id};
      my $href= $urls->get_url('Vega_transcript', $id);
      push @vega_info, [$id, $href];


    }
  }
  my( $display_name, $dbname, $ext_id, $dbname_disp, $info_text ) = $object->display_xref();
  return 1 unless defined $display_name;
  my $label = $object->type_name();
  my $lc_type = lc($label);
  # link to external database
  my $linked_display_name = $display_name;
  if( $ext_id ) {
    $linked_display_name = $object->get_ExtURL_link( $display_name, $dbname, $ext_id );
  }
  my $site_type = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));

  # If gene ID projected from other spp, put link on other spp geneID
  if ($dbname_disp =~/^Projected/) {
    $linked_display_name = $display_name; # i.e. don't link it
    if ($info_text) {
      $info_text =~ /from (.+) gene (.+)/;
      my ($species, $gene) = ($1, $2);
      $info_text =~ s|$species|<i>$species</i>| if $species =~ /\w+ \w+/;
      $species =~ s/ /_/;
      $info_text =~s|($gene)|<a href="/$species/geneview?gene=$gene">$gene</a> |;
    }
  }

  my $html = qq(
  <p>
    <strong>$linked_display_name</strong> $info_text<span class="small">($dbname_disp ID)</span>
    <span class="small">. To view all $site_type genes linked to the name <a href="/@{[$object->species]}/featureview?type=Gene;id=$display_name">click here</a>.</span>
  </p>);
  if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
    my %T = map { $_->primary_id,1 } @CCDS;
    @CCDS = sort keys %T;
    $html .= qq(
  <p>
    This $lc_type is a member of the human CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }
  </p>);
  }

  if(@vega_info){
    foreach my $info(@vega_info){
      my $id= $$info[0];
      my $href= $$info[1];
      
      $html .= qq(
        <p>
          This transcript is identical to Vega transcript: <a href="$href">$id</a> 
       </p>
     );
    }
   } 
  
  $panel->add_row( $label, $html );
  return 1;
}

sub stable_id {
  my( $panel, $object ) = @_;
  my $db_type   = ucfirst($object->source) ;
  my $db        = $object->get_db;
  my $o_type    = $object->type_name;
  my $label     = "$db_type $o_type ID";
  my $geneid    = $object->stable_id ;
  return 1 unless $geneid;
  my $vega_link = '';
  if( $db eq 'vega' ){
    $vega_link = sprintf qq(<span class="small">[%s]</span>),
      $object->get_ExtURL_link( "View $o_type @{[$object->stable_id]} in Vega", 'VEGA_'.uc($o_type), $object->stable_id )
  }
  $panel->add_row( $label, qq(
  <p><strong>$geneid</strong> $vega_link</p>)
  );
  return 1;
}

sub location {
  my( $panel, $object ) = @_;
  my $geneid = $object->stable_id;
  my ( $contig_name, $contig, $contig_start) = $object->get_contig_location();
  my $alt_locs = $object->get_alternative_locations;
  my $label    = 'Genomic Location';
  my $html     = '';
  my $lc_type  = lc( $object->type_name );
  if( ! $object->seq_region_name ) {
    $html .=  qq(  <p>This $lc_type cannot be located on the current assembly</p>);
  } else {
    $html .= sprintf( qq(
      <p>
        This $lc_type can be found on %s at location <a href="/%s/contigview?l=%s:%s-%s">%s-%s</a>.
      </p>),
      $object->neat_sr_name( $object->coord_system, $object->seq_region_name ),
      $object->species,
      $object->seq_region_name, $object->seq_region_start, $object->seq_region_end,
      $object->thousandify( $object->seq_region_start ),
      $object->thousandify( $object->seq_region_end )
    );

    # alternative (Vega) coordinates
    my $alt_assembly = $object->species_defs->ALTERNATIVE_ASSEMBLY;
    if ($alt_assembly and lc($object->source) eq 'vega') {  
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg = "Bio::EnsEMBL::Registry";
    my $orig_group = $reg->get_DNAAdaptor($object->species, "vega")->group;
    $reg->add_DNAAdaptor($object->species, "vega", $object->species, "vega") or warn "***********help";

    # project feature slice onto Vega assembly
    my $alt_slices = $object->vega_projection($alt_assembly);

      # link to Vega if there is an ungapped mapping of whole gene
    if ((scalar(@$alt_slices) == 1) && ($alt_slices->[0]->length == $object->feature_length) ) {
      my $l = $alt_slices->[0]->seq_region_name.":".
        $alt_slices->[0]->start."-".
          $alt_slices->[0]->end;
      my $url = $object->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
      $html .= "<p>This corresponds to ";
      $html .= sprintf(qq(<a href="%s" target="external">%s-%s</a>),
                                                         $url,
               $object->thousandify($alt_slices->[0]->start),
               $object->thousandify($alt_slices->[0]->end)
              );
      $html .= " in $alt_assembly coordinates.</p>";
    } else {
      $html .= "<p>There is no ungapped mapping of this $lc_type onto the $alt_assembly assembly.</p>";
    }

      # set dnadb back to the original group
      $reg->add_DNAAdaptor($object->species, "vega", $object->species, $orig_group);
    }
    
    $html .= sprintf( qq(
      <p>
        The start of this $lc_type is located in <a href="/%s/contigview?region=%s">%s</a>.
      </p>), 
      $object->species, $contig, $contig_name
    );
  }

  # Haplotype/PAR locations
  if( @$alt_locs ) {
    $html .= qq(
      <p>Additionally this $lc_type is mapped to the following haplotypes/PARs:</p>
      <ul>);
    foreach my $loc (@$alt_locs){
      my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
      $html .= sprintf( qq(
        <li>
          <a href="/%s/contigview?l=%s:%s-%s">%s : %s-%s</a>
        </li>), $object->species, $altchr, $altstart, $altend, $altchr,
             $object->thousandify( $altstart ),
             $object->thousandify( $altend ));
  }
    $html .= "\n    </ul>";
  }
  $panel->add_row( $label, $html );
  return 1;
}

sub EC_URL {
  my($gene,$string) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $gene->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub description {
  my( $panel, $object ) = @_;
  my $description = CGI::escapeHTML( $object->gene_description() );
     $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/EC_URL($object,$1)/e;
     $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
  my($edb, $acc) = ($1, $2);

  return 1 unless $description;
  my $label = 'Description';
  my $html = sprintf qq(\n     <p>%s%s</p>), $description,
    $acc ? qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) : '' ;
  $panel->add_row( $label, $html );
  return 1;

}

sub method {
  my( $panel, $gene ) = @_;
  my $db = $gene->get_db ;
  my $label = ( ($db eq 'vega' or $gene->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
  my $text = "No $label defined in database";
  my $o = $gene->Obj;  
  eval {
  if( $o &&
      $o->can( 'analysis' ) &&
      $o->analysis &&
      $o->analysis->description ) {
    $text = $o->analysis->description;
  } elsif( $gene->can('gene') && $gene->gene->can('analysis') && $gene->gene->analysis && $gene->gene->analysis->description ) {
    $text = $gene->gene->analysis->description;
  } else {
    my $logic_name = $o->can('analysis') && $o->analysis ? $o->analysis->logic_name : '';
    if( $logic_name ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
      $text = "<strong>FROM CONFIG:</strong> ".$gene->species_defs->$confkey;
    }
    if( ! $text ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
      $text   = "<strong>FROM DEFAULT CONFIG:</strong> ".$gene->species_defs->$confkey;
    }
  }
  $panel->add_row( $label, sprintf(qq(<p>%s</p>), $text ));
  };
  return 1;
}

sub orthologues {
  my( $panel, $gene ) = @_;
  my $label = 'Orthologue Prediction';
  my $status   = 'status_gene_orthologues';
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

  my $db              = $gene->get_db() ;
  my $cache_obj = cache( $panel, $gene, 'orth', join '::', $db, $gene->species, $gene->stable_id );
  my $html;
  if( $cache_obj->exists ) {
    $html = $cache_obj->retrieve();
    return 1 unless $html;
  } else {
    my $orthologue = $gene->get_homology_matches('ENSEMBL_HOMOLOGUES', 'ortholog');
    unless( $orthologue ) {
      cache_print( $cache_obj, undef );
      return 1;
    }
    my %orthologue_list = %{$orthologue};

# Find the selected method_link_set
    my $especies = $ENV{ENSEMBL_SPECIES};

    my $FLAG = 0;
    my $as_html = qq{<br/> <b>This gene can be viewed in genomic alignment with other species</b><br/><br/>} ;

    my %alignments = $gene->species_defs->multiX('ALIGNMENTS');
    my $species = $gene->species;

    foreach my $id (
      sort { 10 *($alignments{$b}->{'type'} cmp $alignments{$a}->{'type'}) + ($a <=> $b) }
      grep { $alignments{$_}->{'species'}->{$species} }
      keys (%alignments)
    ) {

      my $label = $alignments{$id}->{'name'};
      my $KEY = "opt_align_${id}";

      my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};
      if ( scalar(@species) == 1) {
       ($label = $species[0]) =~ s/_/ /g;
      }

      $as_html .= sprintf( qq(&nbsp;&nbsp;&nbsp;<a href="/%s/alignsliceview?l=%s:%s-%s;align=%s">view genomic alignment with <b>%s</b></a> <br/>),
         $gene->species,
         $gene->seq_region_name,
         $gene->seq_region_start,
         $gene->seq_region_end,
         $KEY,
         $label);

      $FLAG = 1;
    }
    $as_html = '' unless $FLAG;
    $html = qq(
      <p>
        The following gene(s) have been identified as putative
        orthologues:
      </p>
      <table width="100%" cellpadding="4">
        <tr>
          <th>Species</th>
          <th>Type</th>
          <th>Gene identifier</th>
        </tr>);
    my %orthologue_map = qw(SEED BRH PIP RHS);

    my %SPECIES;
    my $STABLE_ID = $gene->stable_id; my $C = 1;
    my $FULL_URL  = qq(/@{[$gene->species]}/multicontigview?gene=$STABLE_ID);
    my $ALIGNVIEW = 0;
    my $matching_orthologues = 0;
    my %SP = ();
    foreach my $species (keys %orthologue_list) {
      $html .= sprintf( qq(
        <tr>
          <th rowspan="@{[scalar(keys %{$orthologue_list{$species}})]}"><em>%s</em></th>), $species );
      my $start = '';
      foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
        my $OBJ = $orthologue_list{$species}{$stable_id};
        $html .= $start;
        $start = qq(
        <tr>);
        $matching_orthologues = 1;
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $orthologue_desc = $orthologue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
     # my $orthologue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
     #    $orthologue_dnds_ratio = '&nbsp;' unless (defined $orthologue_dnds_ratio);
        my $last_col;
        if(exists( $OBJ->{'display_id'} )) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $EXTRA = qq(<span class="small">[<a href="/@{[$gene->species]}/multicontigview?gene=$STABLE_ID;s1=$spp;g1=$stable_id;context=1000">MultiContigView</a>]</span>);
          if( $orthologue_desc ne 'DWGA' ) {
            $EXTRA .= qq(&nbsp;<span class="small">[<a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID;g1=$stable_id">Align</a>]</span>);
            $ALIGNVIEW = 1;
          }
          $FULL_URL .= ";s$C=$spp;g$C=$stable_id";$C++;
          my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $last_col = qq(<a href="$link">$stable_id</a> (@{[$OBJ->{'display_id'}]}) $EXTRA<br />).
                      qq(<span class="small">$description</span>);
        } else {
          $last_col = qq($stable_id<br /><span class="small">$description</span>);
        }
        $html .= sprintf( qq(
              <td>$orthologue_desc</td>
              <td>$last_col</td>
            </tr>));
      }
    }
    $html .= qq(\n      </table>);
    if( keys %orthologue_list ) {
      # $html .= qq(\n      <p><a href="$FULL_URL">View all genes in MultiContigView</a>;);
      $html .= qq(\n      <p><a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID">View alignments of homologies</a>.</p>) if $ALIGNVIEW;
    }
    $html .= $as_html;
    cache_print( $cache_obj, \$html );
    return 1 unless($matching_orthologues);
  }
  $panel->add_row( $label, $html, "$URL=off" );
  return 1;
}

sub paralogues {
  my( $panel, $gene ) = @_;


  # make the paralogues panel a collapsable one
  my $label  = 'Paralogue Prediction';
  my $status = 'status_gene_paralogues';
  my $URL    = _flip_URL($gene, $status );
  if( $gene->param($status) eq 'off' ) {
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

## call table method here
  my $db              = $gene->get_db() ;
  my $cache_obj = cache( $panel, $gene, 'para', join '::', $db, $gene->species, $gene->stable_id );
  my $html;
  if( $cache_obj->exists ) {
    $html = $cache_obj->retrieve;
    return 1 unless $html;
  } else {
    my $paralogue = $gene->get_homology_matches('ENSEMBL_HOMOLOGUES', 'within_species_paralog');
    unless( $paralogue ) {
      cache_print( $cache_obj, undef );
      return 1;
    }
    my %paralogue_list = %{$paralogue};
    $html = qq(
      <p>
        The following gene(s) have been identified as putative paralogues (within species):
      </p>
      <table>);
    $html .= qq(
        <tr>
          <th>Taxonomy Level</th><th>Gene identifier</th>
        </tr>);
    my $STABLE_ID = $gene->stable_id; my $C = 1;
    foreach my $species (sort keys %paralogue_list){
 # foreach my $stable_id (sort keys %{$paralogue_list{$species}}){
      foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}){

        my $OBJ = $paralogue_list{$species}{$stable_id};
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $paralogue_subtype = $OBJ->{'homology_subtype'};
           $paralogue_subtype = "&nbsp;" unless (defined $paralogue_subtype);
        if($OBJ->{'display_id'}) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td><a href="$link">$stable_id</a> (@{[ $OBJ->{'display_id'} ]})<br />
              <span class="small">$description</span></td>
        </tr>);
        } else {
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td>$stable_id<br /><span class="small">$description</span></td>
        </tr>);
        }
      }
    }
    $html .= qq(</table>);
    cache_print( $cache_obj, \$html );
  }

  $panel->add_row( 'Paralogue Prediction', $html, "$URL=off" );
  return 1;
}

sub diseases {
  my( $panel, $gene ) = @_;

  my $omim_list = $gene->get_disease_matches;
  return 1 unless ref($omim_list);
  return 1 unless scalar(%$omim_list);

  my $label = 'Disease Matches';
  my $html  = qq(
      <p>
        This Ensembl entry corresponds to the following
        OMIM disease identifiers:
      </p>
      <dl>);
  for my $description (sort keys %{$omim_list}){
    $html.= sprintf( qq(
        <dt>%s</dt>
        <dd><ul>), CGI::escapeHTML($description) );
    for my $omim (sort @{$omim_list->{$description}}){
      my $omim_link = $omim;
      my $omim_URL = $gene->get_ExtURL('OMIM', $omim_link);
      if( $omim_URL ) {
        $omim_link = qq(<a href="$omim_URL" rel="external">$omim_link</a>);
      }
      $html.= sprintf( qq(
          <li>[Omim ID: %s] -
            <a href="/@{[$gene->species]}/featureview?type=Disease;id=%d">View disease information</a>
          </li>), $omim_link, $omim );
    }
    $html.= qq(
        </ul></dd>);
  }
  $html.= qq(
      </dl>);
  $panel->add_row( 'Disease Matches', $html );
  return 1;
}

sub das {
   my( $panel, $object ) = @_;
   my $status   = 'status_das_sources';
   my $URL = _flip_URL( $object, $status );
   EnsEMBL::Web::Component::format_das_panel($panel, $object, $status, $URL);
}

sub paralogues {
  my( $panel, $gene ) = @_;

  my $paralogue = $gene->get_homology_matches('ENSEMBL_HOMOLOGUES', 'within_species_paralog');
  return 1 unless $paralogue;

  # make the paralogues panel a collapsable one
  my $label  = 'Paralogue Prediction';
  my $status = 'status_gene_paralogues';
  my $URL    = _flip_URL($gene, $status );
  if( $gene->param($status) eq 'off' ) {
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

## call table method here
  my $db = $gene->get_db() ;
  my %paralogue_list = %{$paralogue};
  my $html = qq(
      <p>
        The following gene(s) have been identified as putative paralogues (within species):
      </p>
      <table>);
  $html .= qq(
        <tr>
          <th>Taxonomy Level</th><th>Gene identifier</th>
        </tr>);
  my $STABLE_ID = $gene->stable_id; my $C = 1;
  foreach my $species (sort keys %paralogue_list){
 # foreach my $stable_id (sort keys %{$paralogue_list{$species}}){
  foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}){

    my $OBJ = $paralogue_list{$species}{$stable_id};
    my $description = $OBJ->{'description'};
       $description = "No description" if $description eq "NULL";
    my $paralogue_subtype = $OBJ->{'homology_subtype'};
       $paralogue_subtype = "&nbsp;" unless (defined $paralogue_subtype);
    if($OBJ->{'display_id'}) {
      (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
      my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
      if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
        my ($edb, $acc) = ($1, $2);
        if( $acc ) {
          $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
        }
      }
      $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td><a href="$link">$stable_id</a> (@{[ $OBJ->{'display_id'} ]})<br />
              <span class="small">$description</span></td>
        </tr>);
    } else {
      $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td>$stable_id<br /><span class="small">$description</span></td>
        </tr>);
    }
  }
  }
  $html .= qq(</table>);

  $panel->add_row( 'Paralogue Prediction', $html, "$URL=off" );
  return 1;
}


sub _flip_URL {
  my( $gene, $code ) = @_;
  return sprintf '/%s/%s?gene=%s;db=%s;%s', $gene->species, $gene->script, $gene->stable_id, $gene->get_db, $code;
}

sub transcripts {
  my( $panel, $gene ) = @_;
  my $label    = 'Transcripts';
  my $gene_stable_id = $gene->stable_id;
  my $db = $gene->get_db() ;
  my $status   = 'status_gene_transcripts';
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

##----------------------------------------------------------------##
## This panel has two halves...                                   ##
## ... the top is a table of all the transcripts in the gene ...  ##
##----------------------------------------------------------------##

  my $rows = '';
  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts()};
  my $extra = @trans>17?'<p><strong>A large number of transcripts have been returned for this gene. To reduce render time for this page the protein and transcript  information will not be displayed. To view this information please follow the transview and protview links below. </strong></p>':'';
  foreach my $transcript ( @trans ) {
    my $trans_stable_id = $transcript->stable_id;
    $rows .= qq(\n  <tr>\n    <td><a href="#$trans_stable_id">$trans_stable_id</a></td>);
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= "<td>$pep_stable_id</td>";
    } else {
      $rows .= "<td>no translation</td>";
    }
    if( $transcript->display_xref ) {
      my ($trans_display_id, $db_name, $ext_id) = $transcript->display_xref();
      if( $ext_id ) {
        $trans_display_id = $gene->get_ExtURL_link( $trans_display_id, $db_name, $ext_id );
      }
      $rows .= "<td>$trans_display_id</td>";
    } else {
      $rows.= "<td>novel transcript</td>";
    }
    $rows .= sprintf '
    <td>[<a href="%s">Transcript&nbsp;info</a>]</td>', $gene->URL( 'script' => 'transview', 'db' => $db, 'transcript' => $trans_stable_id );
    $rows .= sprintf '
    <td>[<a href="%s">Exon&nbsp;info</a>]</td>', $gene->URL( 'script' => 'exonview', 'db' => $db, 'transcript' => $trans_stable_id );
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= sprintf '
    <td>[<a href="%s">Peptide&nbsp;info</a>]</td>', $gene->URL( 'script' => 'protview', 'db' => $db, 'peptide' => $pep_stable_id );
    }
    $rows .= "\n  </tr>";
  }

##----------------------------------------------------------------##
## ... and the second part is an image of the transcripts +-10k   ##
##----------------------------------------------------------------##

## Get a slice of the gene +/- 10k either side...
  my $gene_slice = $gene->Obj->feature_Slice->expand( 10e3, 10e3 );
  $gene_slice = $gene_slice->invert if $gene->seq_region_strand < 0;
## Get the web_user_config
  my $wuc        = $gene->user_config_hash( 'altsplice' ); 
## We now need to select the correct track to turn on....
  ## We need to do the turn on turn off for the checkboxes here!!
  foreach( $trans[0]->default_track_by_gene ) {
    $wuc->set( $_,'on','on');
  }
  # $wuc->{'_no_label'}   = 'true';
  $wuc->{'_add_labels'} = 'true';
  $wuc->set( '_settings', 'width',  $gene->param('image_width') );

## Will need to add bit here to configure which tracks to turn on and off!!
## Get the drawable_container
  my $mc = $gene->new_menu_container(
    'configname' => 'altsplice',
    'panel'      => 'altsplice',
    'leftmenus' => ['Features']
  );
## Now
  my $image  = $gene->new_image( $gene_slice, $wuc, [$gene->Obj->stable_id] );
  $image->introduction       = qq($extra\n<table style="width:100%">$rows</table>\n);
  $image->imagemap           = 'yes';
  $image->menu_container     = $mc;
  $image->set_extra( $gene );

  $panel->add_row( $label, $image->render, "$URL=off" );
}


# Gene Regulation View -------------------------------------
# Example: http://ensarc-1-14.internal.sanger.ac.uk:7033/Homo_sapiens/contigview?c=14:104257974.4;w=1093

sub regulation_factors {
 my($panel, $object) = @_;
  my $feature_objs = $object->features;
  return unless @$feature_objs;

  $panel->add_columns(
    {'key' =>'Location',   },
    {'key' =>'Length',  },
    {'key' =>'Sequence',},
    {'key' =>'Reg. factor',  },
    {'key' =>'Reg. feature', },
    {'key' =>'Feature analysis',},
  );

  $panel->add_option( 'triangular', 1 );
  my @sorted_features = sort { $a->factor->name cmp $b->factor->name } @$feature_objs;


  foreach my $feature_obj ( @sorted_features ) {
    my $row;
    my $factor_name = $feature_obj->factor->name;
    my $factor_link = $factor_name? qq(<a href="/@{[$object->species]}/featureview?id=$factor_name;type=RegulatoryFactor">$factor_name</a>) : "unknown";
    my $feature_name = $feature_obj->name;
    my $seq = $feature_obj->seq();
    $seq =~ s/([\.\w]{60})/$1<br \/>/g;
    my $seq_name = $feature_obj->slice->seq_region_name;
    my $position =  $object->thousandify( $feature_obj->start ). "-" .
      $object->thousandify( $feature_obj->end );
    $position = qq(<a href="/@{[$object->species]}/contigview?c=$seq_name:).$feature_obj->start.qq(;w=100">$seq_name:$position</a>);
    my $analysis = $feature_obj->analysis->description;
    $analysis =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;
    $row = {
      'Location'         => $position,
      'Reg. factor'      => $factor_link,
      'Reg. feature'     => "$feature_name",
      'Feature analysis' =>  $analysis,
      'Length'           => $object->thousandify( length($seq) ).' bp',
            'Sequence'         => qq(<font face="courier" color="black">$seq</font>),
     };

     $panel->add_row( $row );
  }
  return 1;
}

sub gene_structure {
  my( $panel, $object ) = @_;
  my $label    = 'Gene structure';
  my $object_slice = $object->Obj->feature_Slice;
     $object_slice = $object_slice->invert if $object_slice->strand < 1; ## Put back onto correct strand!
## Now we need to extend the slice!!
  my $start = $object->Obj->start;
  my $end   = $object->Obj->end;
  foreach my $grf ( @{ $object->Obj->get_all_regulatory_features(1)||[] } ) {
    $start = $grf->start if $grf->start < $start;    
    $end   = $grf->end   if $grf->end   > $end;
  } 
  my $gr_slice = $object_slice->expand( $object->Obj->start - $start, $end - $object->Obj->end ); 

  my $trans = $object->get_all_transcripts;
  my $gene_track_name =$trans->[0]->default_track_by_gene;

  my $wuc = $object->get_userconfig( 'geneview' );
     $wuc->{'geneid'} = $object->Obj->stable_id;
     $wuc->{'_draw_single_Gene'} = $object->Obj;
     $wuc->set( '_settings',          'width',       900);
     $wuc->set( '_settings',          'show_labels', 'yes');
     $wuc->set( 'ruler',              'str',         $object->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $gene_track_name,     'on',          'on');
     $wuc->set( 'regulatory_regions', 'on',          'on');
     $wuc->set( 'regulatory_search_regions', 'on',   'on');

  my $image    = $object->new_image( $gr_slice, $wuc, [] );
  $image->imagemap           = 'yes';
  $panel->print( $image->render );
}

sub factor {
  my( $panel, $object ) = @_;
  my $factors = $object->Obj->fetch_coded_for_regulatory_factors;
  return 1 unless @$factors;

  my $gene = $object->Obj->stable_id;
  my $html = "$gene codes for regulation factor: ";
  foreach my $factor (@$factors) {
    my $factor_name = $factor->name;
    $html .= qq(<a href="featureview?type=RegulatoryFactor;id=$factor_name">$factor_name</a><br />);
  }

  my $label = "Regulation factor: ";
  $panel->add_row( $label, $html );
  return 1;
}
#-------- end gene regulation view ---------------------


sub genespliceview_menu {  return gene_menu( @_, 'genesnpview_transcript',
   [qw( Features SNPContext ImageSize THExport )], ['GeneSpliceHelp'] ); }

sub genetreeview_menu {
    my($panel, $object, $configname, $left, $right ) =  
	(@_, 'genetreeview', [qw( ImageSize GTExport )], ['GeneTreeHelp'] );

    my $mc = $object->new_menu_container(
					 'configname'  => $configname,
					 'panel'       => 'image',
					 'object' => $object,
					 'configs'     => [ $object->user_config_hash( 'genetreeview' ) ],
					 'leftmenus'  => $left,
					 'rightmenus' => $right
					 );
    $panel->print( $mc->render_html );
    $panel->print( $mc->render_js );
    return 0;
}

sub nogenetree {
  my ($panel, $object) = @_;
  my $html = qq(
    <p>This gene has no orthologues in Ensembl Compara, so a gene tree cannot be built.</p>
  );
  $panel->print( $html );
  return 1;
} 


sub genesnpview_menu    {  return gene_menu( @_, 'genesnpview_transcript', 
   [qw( Features  Source SNPClasses SNPValid SNPTypes SNPContext ImageSize THExport)], ['SNPHelp'] ); }

sub gene_menu { 
  my($panel, $object, $configname, $left, $right ) = @_;
  my $mc = $object->new_menu_container(
    'configname'  => $configname,
    'panel'       => 'bottom',
    'configs'     => [ $object->user_config_hash( 'genesnpview_context' ) ],
    'leftmenus'  => $left,
    'rightmenus' => $right
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}

sub genespliceview {
  my( $panel, $object ) = @_;
  return genesnpview( $panel, $object, 1 );
}

sub genesnpview {
  my( $panel, $object, $no_snps, $do_not_render ) = @_;

  my $image_width  = $object->param( 'image_width' );
  my $context      = $object->param( 'context' );
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $uca           = $object->get_userconfig_adaptor();
  my $master_config = $uca->getUserConfig( "genesnpview_transcript" );
     $master_config->set( '_settings', 'width',  $image_width );


  # Padding-----------------------------------------------------------
  # Get 5 configs - and set width to width of context config
  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $Configs;
  my @confs = qw(context gene transcripts_top transcripts_bottom);
  push @confs, 'snps' unless $no_snps;

  foreach( @confs ) {
    $Configs->{$_} = $uca->getUserConfig( "genesnpview_$_" );
    $Configs->{$_}->set( '_settings', 'width',  $image_width );
  }
   $object->get_gene_slices( ## Written...
    $master_config,
    [ 'context',     'normal', '500%'  ],
    [ 'gene',        'normal', '133%'  ],
    [ 'transcripts', 'munged', $extent ]
  );

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];


  # Fake SNPs -----------------------------------------------------------
  # Grab the SNPs and map them to subslice co-ordinate 
  # $snps contains an array of array each sub-array contains [fake_start, fake_end, B:E:Variation object] # Stores in $object->__data->{'SNPS'} 
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $transcript_slice, $sub_slices  ); 
  my $start_difference =  $object->__data->{'slices'}{'transcripts'}[1]->start - $object->__data->{'slices'}{'gene'}[1]->start;
  
  my @fake_filtered_snps;
  map { push @fake_filtered_snps, 
     [ $_->[2]->start + $start_difference, 
       $_->[2]->end   + $start_difference, 
       $_->[2]] } @$snps;

  $Configs->{'gene'}->{'filtered_fake_snps'} = \@fake_filtered_snps unless $no_snps;


  # Make fake transcripts ----------------------------------------------
 $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}

  my @domain_logic_names = qw(Pfam scanprosite Prints pfscan PrositePatterns PrositeProfiles Tigrfam Superfamily Smart PIRSF);
  foreach( @domain_logic_names ) {
    $object->store_TransformedDomains( $_ );    ## Stores in $transcript_object->__data->{'transformed'}{'Pfam_hits'} 
  }
  $object->store_TransformedSNPS() unless $no_snps;      ## Stores in $transcript_object->__data->{'transformed'}{'snps'}


  ### This is where we do the configuration of containers....
  my @transcripts            = ();
  my @containers_and_configs = (); ## array of containers and configs

  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
## create config and store information on it...
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    my $CONFIG = $uca->getUserConfig( "genesnpview_transcript" );
    $CONFIG->{'geneid'}     = $object->stable_id;
    $CONFIG->{'snps'}       = $snps unless $no_snps;
    $CONFIG->{'subslices'}  = $sub_slices;
    $CONFIG->{'extent'}     = $extent;
      ## Store transcript information on config....
    my $TS = $trans_obj->__data->{'transformed'};
    $CONFIG->{'transcript'} = {
      'exons'        => $TS->{'exons'},
      'coding_start' => $TS->{'coding_start'},
      'coding_end'   => $TS->{'coding_end'},
      'transcript'   => $trans_obj->Obj,
      'gene'         => $object->Obj,
      $no_snps ? (): ('snps' => $TS->{'snps'})
    };
    foreach ( @domain_logic_names ) { 
      $CONFIG->{'transcript'}{lc($_).'_hits'} = $TS->{lc($_).'_hits'};
    }

    $CONFIG->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
    if( $object->seq_region_strand < 0 ) {
      push @containers_and_configs, $transcript_slice, $CONFIG;
    } else {
      ## If forward strand we have to draw these in reverse order (as forced on -ve strand)
      unshift @containers_and_configs, $transcript_slice, $CONFIG;
    }
    push @transcripts, { 'exons' => $TS->{'exons'} };
  }

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

## map snps to fake evenly spaced co-ordinates...
  my @snps2;
  unless( $no_snps ) {
    @snps2 = map {
      $fake_length+=$SNP_REL+1;
      [ $fake_length-$SNP_REL+1 ,$fake_length,$_->[2], $slice_trans->seq_region_name,
        $slice_trans->strand > 0 ?
          ( $slice_trans->start + $_->[2]->start - 1,
            $slice_trans->start + $_->[2]->end   - 1 ) :
          ( $slice_trans->end - $_->[2]->end     + 1,
            $slice_trans->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @{ $snps };
## Cache data so that it can be retrieved later...
    #$object->__data->{'gene_snps'} = \@snps2; fc1 - don't think is used
    foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
      $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
    }
  }

## -- Tweak the configurations for the five sub images ------------------ ##
## Gene context block;
  my $gene_stable_id = $object->stable_id;
  $Configs->{'context'}->{'geneid2'} = $gene_stable_id; ## Only skip background stripes...
  $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  $Configs->{'context'}->set('variation','on','off') if $no_snps;
  $Configs->{'context'}->set('snp_join','on','off') if $no_snps;
## Transcript block
  $Configs->{'gene'}->{'geneid'}      = $gene_stable_id;
  $Configs->{'gene'}->container_width( $object->__data->{'slices'}{'gene'}[1]->length() );
  $Configs->{'gene'}->set('snp_join','on','off') if $no_snps;
## Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->set('snp_join','on','off') if $no_snps;
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'geneid'}      = $gene_stable_id;
    $Configs->{$_}->{'transcripts'} = \@transcripts;
    $Configs->{$_}->{'snps'}        = $object->__data->{'SNPS'} unless $no_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
  }
  $Configs->{'transcripts_bottom'}->set('spacer','on','off') if $no_snps;
## SNP box track...
  unless( $no_snps ) {
    $Configs->{'snps'}->{'fakeslice'}   = 1;
    $Configs->{'snps'}->{'snps'}        = \@snps2;
    $Configs->{'snps'}->container_width(   $fake_length   );
    $Configs->{'snps'}->{'snp_counts'} = [$count_snps, scalar @$snps, $context_count];
  }
  return if $do_not_render;
## -- Render image ------------------------------------------------------ ##
  my $image    = $object->new_image([
    $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
    $object->__data->{'slices'}{'gene'}[1],        $Configs->{'gene'},
    $transcript_slice, $Configs->{'transcripts_top'},
    @containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
    $no_snps ? ():($transcript_slice, $Configs->{'snps'})
  ],
  [ $object->stable_id ]
  );
  #$image->set_extra( $object );

  $image->imagemap = 'yes';

  my $T = $image->render;
  $panel->print( $T );
  return 0;
}

sub genesnpview_legend {
  my( $panel, $object ) = @_;
  $panel->print( qq(
    <p>
      <img src="/img/help/genesnpview-key.gif" height="160" width="800" border="0" alt="" />
    </p>
  ) ); 
  return 0;
}

sub too_big {
  my( $panel, $object ) = @_;
  my $object_type = $panel->{'object_type'};
  $panel->print( qq(<p>Due to the length of this $object_type, this display is disabled as the rendering time is too long.</p>) );
  return 0;
}

sub genetreeview {
  my( $panel, $object ) = @_;

  my $databases       = $object->DBConnection->get_databases( 'core', 'compara' );
  my $comparaDBA      = $databases->{'compara'};

  my $id = $object->stable_id;
  my $clusterset_id = 0; ### WHAT IS IT ???

  my $treeDBA = $comparaDBA->get_ProteinTreeAdaptor;
  my $member = $comparaDBA->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $id);

 ( $panel->print( qq(<p style="text-align:center"><b>Could not find a tree for gene $id.</b></p>) ) and return 1) unless (defined $member);
  my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
									  $member->get_longest_peptide_Member->member_id,
									  $clusterset_id);
  (warn("Can't get aligned member") and return 0) unless (defined $aligned_member);

  my $node = $aligned_member->subroot;
  my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;

#  warn("Z-0:".localtime);
  my $label = "GeneTree";

  my $treeimage = create_genetree_image( $object, $tree);
#  warn("Y-0:".localtime);

  my $T = $treeimage->render;
  $panel->print( $T );
#  warn("X-0:".localtime);

  return 1;
}


sub external_links {
  my( $panel, $object ) = @_;

  my $databases       = $object->DBConnection->get_databases( 'core', 'compara' );
  my $comparaDBA      = $databases->{'compara'};

  my $id = $object->stable_id;
  my $clusterset_id = 0; 

  my $treeDBA = $comparaDBA->get_ProteinTreeAdaptor;
  my $member = $comparaDBA->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $id);
  return 0 unless (defined $member);
  my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
									  $member->get_longest_peptide_Member->member_id,
									  $clusterset_id);
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;
  my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  my $label = "External Links";

  my $FN        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file      = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN";
  $object->make_directory( $file );

  my $URL       = $object->species_defs->ENSEMBL_BASE_URL.$object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN";
  if( open NHX,   ">$file" ) {
      print NHX $tree->nhx_format('simple');
      close NHX;
#      warn "(written $file => $URL)";
  }

  my $alignio = Bio::AlignIO->newFh(
				    -fh     => IO::String->new(my $var),
				    -format => 'fasta'
				    );
      
  print $alignio $tree->get_SimpleAlign();
  my $FN2        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file2      = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN2";
  $object->make_directory( $file2 );
  my $URL2       = $object->species_defs->ENSEMBL_BASE_URL.$object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN2";
  if( open FASTA,   ">$file2" ) {
      print FASTA $var;
      close FASTA;
#      warn "(written FASTA $file2 => $URL2)";
  }

  my $jalview = qq{
    <applet archive=").$object->species_defs->ENSEMBL_BASE_URL.qq(/jalview/jalview.jar"
        code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">
      <param name="input" value="$URL2" />
      <param name="type" value="URL" />
      <param name=format value="FASTA" />
      <param name="fontsize" value="10" />
      <param name="Consensus" value="*" />
      <param name="srsServer" value="srs.sanger.ac.uk/srsbin/cgi-bin/" />
      <param name="database" value="ensemblpep" />
      <strong>Java must be enabled to view alignments</strong>
    </applet>
};


  my $html = qq{
<script type="text/javascript" src="/js/atv.js"></script>

<form>
    <input style="background-color:white;vertical-align:top; margin: 5px; border: 1; width:70px; height:23px" type=button value="ATV" onClick="openATV(\'}.
    $object->species_defs->ENSEMBL_BASE_URL.qq{\',\'$URL\' )">
    $jalview
</form>
};

  $panel->add_row( $label, $html );
  return 1;
}

sub create_genetree_image {
  my(  $object, $tree ) = @_;

  my $wuc        = $object->user_config_hash( 'genetreeview' ); 
  my $image_width  = $object->param( 'image_width' ) || 1200;
  $wuc->container_width($image_width);
  $wuc->set_width( $object->param('image_width') );
  $wuc->{_object} = $object;

  my $image  = $object->new_image( $tree, $wuc, [$object->stable_id] );
#  $image->cacheable   = 'yes';
  $image->image_name  = 'genetree-'.($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap           = 'yes';
  return $image;
}     

1;
