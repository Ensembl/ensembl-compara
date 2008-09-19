package EnsEMBL::Web::Component::Variation;

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

CONTACT Fiona Cunningham <webmaster@sanger.ac.uk>

=cut

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";
use POSIX qw(floor ceil);
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);

#use Data::Dumper;
#$Data::Dumper::Indent = 3;

# Notes:
# Variation object: has all the data (flanks, alleles) but no position
# VariationFeature: has position (but also short cut calls to allele etc.) 
#                   for contigview

# TEST SNPs  gives and ERROR 1065427
# 3858116 has TSC sources, 557122 hapmap (works), 2259958 (senza-hit), 625 multi-hit, lots of LD 2733052, 2422821, 12345
# Problem snp  	1800704 has no upstream, downstream seq
# Tagged snps: rs8, rs46,  rs1467672
# slow one: 431235


# General info table #########################################################

sub name {

  ### General_table_info
  ### Arg1        : panel
  ### Arg2        : data object
  ### Example     : $panel1->add_rows(qw(name   EnsEMBL::Web::Component::SNP::name) );
  ### Description : adds a label and the variation name, source to the panel
  ### Returns  1

  my($panel, $object) = @_;
  my $label  = 'SNP';
  my $name   = $object->name;
  my $source = $object->source;
  $name      = $object->get_ExtURL_link($name, 'SNP', $name) if $source eq 'dbSNP';
  my $html  = "<b>$name</b> ($source". $object->source_version.")";
  $panel->add_row( $label, $html );
  return 1;
}



sub synonyms {

  ### General_table_info
  ### Arg1        : panel
  ### Arg2        : data object
  ### Example     : $panel1->add_rows(qw(synonyms   EnsEMBL::Web::Component::SNP::synonyms) );
  ### Description : adds a label and the variation synonyms to the panel
  ### Returns  1

  my($panel, $object) = @_;
  my $label = 'Synonyms';
  my %synonyms = %{$object->dblinks};
  my $info;

  foreach my $db (keys %synonyms) {
    my @ids =  @{ $synonyms{$db} } ;
    my @urls;

    if ($db =~ /dbsnp rs/i) {  # Glovar stuff
      @urls  = map {  $object->get_ExtURL_link( $_, 'SNP', $_)  } @ids;
    }
    elsif ($db =~ /dbsnp/i) { 
      foreach (@ids) {
	next if $_ =~/^ss/; # don't display SSIDs - these are useless
	push @urls , $object->get_ExtURL_link( $_, 'DBSNPSS', $_ );
      }
      next unless @urls;
    }
    #elsif ($db =~ /hgvbase/i) {
    #  @urls  = map {  $object->get_ExtURL_link( $_, 'HGVBASE', $_) } @ids;
    #} 
    #elsif ($db =~ /tsc/i) {
    #  @urls  = map {  $object->get_ExtURL_link( $_, 'TSC', $_)  } @ids;
    #}
    #elsif ($db =~ /Sanger/i) {  # don't link to this as it gives no extra info
    #  @urls = map {  $object->get_ExtURL_link( $_, 'SNPVIEW', {source=>$db, ID=>$_} ) } @ids;
    #}
    else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front = splice (@urls, 0, $counter);
      $front[-1] .= "</tr><tr><td></td>";
      @urls = (@front, @urls);
    }

    $info .= "<b>$db</b> ". (join ", ", @urls ). "<br />";
  }

  $info ||= "None currently in the database";
  $panel->add_row( $label, $info );
  return 1;
}



sub status {

  ### General_table_info
  ### Arg1        : panel
  ### Arg2        : data object
  ### Example     : $panel1->add_rows("status EnsEMBL::Web::Component::SNP::status");
  ### Description : adds a label and string for the variation validation status to the panel
  ### Returns  1

  my ( $panel, $object ) = @_;
  my $label = 'Validation status';
  my @status = @{$object->status};
  unless ( @status ) {
    $panel->add_row($label, "Unknown");
    return 1;
  }

  my $snp_name = $object->name;
  my (@status_list, $hapmap_html);
  foreach my $status (@status) {
    if ($status eq 'hapmap') {
      $hapmap_html = "<b>HapMap SNP</b>", $object->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
    } 
    elsif ($status eq 'failed') {
      my $description = $object->vari->failed_description;
      $panel->add_row($label, "<font color='red'>$description.  <br />This SNP will be removed from Ensembl from release 44.</font>");
      return $status;
    }
    else {
      $status = "frequency" if $status eq 'freq';
      push @status_list, $status;
    }
  }

  my $html = join(", ", @status_list);
  if ($html) {
    if ($html eq 'observed' or $html eq 'non-polymorphic') {
      $html = '<b>'.ucfirst($html).'</b> ';
    } else {
      $html = "Proven by <b>$html</b> ";
    }
    $html .= ' (<i>SNP tested and validated by a non-computational method</i>).<br /> ';
  }
  $html .= $hapmap_html;

  $panel->add_row($label, $html||"Undefined");
  return 1;
}




sub alleles {

  ### General_table_info
  ### Arg1        : panel
  ### Arg2        : data object
  ### Example     : $panel1->add_rows(qw(alleles EnsEMBL::Web::Component::SNP::alleles) );
  ### Description : adds a label and html for the Variations alleles
  ###              adds a line describing the ancestor allele if this exists
  ### Returns  1

   my ( $panel, $object ) = @_;
   my $label = 'Alleles';
   my $alleles = $object->alleles;
   my $vari_class = $object->vari_class || "Unknown";
   my $html;

   if ($vari_class ne 'snp') {
     $html = qq(<b>$alleles</b> (Type: <b><font color="red">$vari_class</font></b>));
   }
   else {
     my $ambig_code = $object->vari->ambig_code;
     $html = qq(<b>$alleles</b> (ambiguity code: <b><font color="red">$ambig_code</font></b>));
   }
   my $ancestor  = $object->ancestor;
   $html .= qq(<br /><em>Ancestral allele</em>: $ancestor) if $ancestor;
   $panel->add_row($label, $html);
   return 1;
 }



sub moltype {

  ### General_table_info
  ### Arg1        : panel
  ### Arg2        : data object
  ### Description : adds a label and its value to the panel:
  ### which describes the molecular type e.g. 'Genomic'
  ### Returns  1

  my ( $panel, $object ) = @_;
  my $label = 'Molecular type';
  my $snp_data  = $object->moltype;
  return 1 unless $snp_data;
  $panel->add_row($label,  $snp_data );
  return 1;
}



sub ld_data {

### General_table_info
 ### Arg1        : panel
 ### Arg2        : data object
 ### Example     : $panel1->add_rows(qw(ld_data EnsEMBL::Web::Component::SNP::ld_data) );
 ### Description : adds a label and its value to the panel:
 ###              Get all the populations with LD data within 100kb of this SNP
 ###                Make links from these populations to LDView
 ### Returns  1

  my ( $panel, $object ) = @_;
  my $label = "Linkage disequilibrium <br />data";
  unless ($object->species_defs->VARIATION_LD) {
    $panel->add_row($label, "<h5>No linkage data available for this species</h5>");
    return;
  }
  my %pop_names = %{_ld_populations($object) ||{} };
  my %tag_data  = %{$object->tagged_snp ||{} };

  my %ld = (%pop_names, %tag_data);
  unless (keys %ld) {
    $panel->add_row($label, "<h5>No linkage data for this SNP</h5>");
    return 1;
  }

  $panel->add_row($label, link_to_ldview($panel, $object, \%ld) );
  return 1;
}





sub seq_region {

### General_table_info
 ### Arg1        : panel
 ### Arg2        : data object
 ### Example     : $panel1->add_rows(qw(seq_region EnsEMBL::Web::Component::SNP::seq_region) );
 ### Description : adds a label and html to the panel
 ###              the variations sequence region in two_col_table format
 ### Returns  1
  my ( $panel, $object ) = @_;
  my $label = 'Flanking sequence';
  my $status   = 'status_ambig_sequence';
  my $URL = _flip_URL( $object, $status );
  if( $object->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

  my $ambig_code = $object->vari->ambig_code;
  unless ($ambig_code) {
    $ambig_code = "[".$object->alleles."]";
  }
  my $downstream = $object->flanking_seq("down");

#  my $ambiguity_seq = $object->ambiguity_flank;
  # genomic context with ambiguities

  # Make the flanking sequence and wrap it
  my $html = uc( $object->flanking_seq("up") ) .lc( $ambig_code ).uc( $downstream );
  $html =~ s/(.{60})/$1\n/g;
  $html =~ s/(([a-z]|-|\[|\])+)/'<font color="red">'.uc("$1").'<\/font>'/eg;
  $html =~ s/\n/\n/g;
  $html .= "     <i>(Variation Feature highlighted)</i>";
  $panel->add_row($label, "<pre>$html</pre>");
  return 1;
}



# Population genotype table and Allele Frequency Table ######################

sub all_freqs {

  ### Population_genotype_alleles
  ### Arg1        : panel
  ### Arg2        : data object
  ### Example     : $allele_panel->add_components( qw(all_freqs EnsEMBL::Web::Component::SNP::lal_freqs) );
  ### Description : prints a table of allele and genotype frequencies for the variation per population
  ### Returns  1

  my ( $panel, $object ) = @_;
  my $freq_data = $object->freqs;
  return [] unless %$freq_data;

  format_frequencies($panel, $object, $freq_data);
  return 1;
}


sub format_frequencies {

  ### Population_genotype_alleles
  ### Arg1        : panel
  ### Arg2        : data object 
  ### Arg3        : frequency data
  ### Example     : format_frequencies($panel, $object, $freq_data);
  ### Description : prints a table of allele or genotype frequencies for the variation
  ### Returns  1

  my ( $panel, $object, $freq_data ) = @_;
  my %freq_data = %{ $freq_data };
  my %columns;

  foreach my $pop_id (sort { $freq_data{$a}{pop_info}{Name} cmp $freq_data{$b}{pop_info}{Name}} keys %freq_data) {
    my %pop_row;

    # Freqs alleles ---------------------------------------------
    my @allele_freq = @{ $freq_data{$pop_id}{AlleleFrequency} };
    foreach my $gt (  @{ $freq_data{$pop_id}{Alleles} } ) {
      my $freq = _format_number(shift @allele_freq);
      $pop_row{"Alleles&nbsp;<br />$gt"} = $freq;
    }

    # Freqs genotypes ---------------------------------------------
    my @genotype_freq = @{ $freq_data{$pop_id}{GenotypeFrequency} || [] };
    foreach my $gt ( @{ $freq_data{$pop_id}{Genotypes} } ) {
      my $freq = _format_number(shift @genotype_freq);
      $pop_row{"Genotypes&nbsp;<br />$gt"} = $freq;
    }

    # Add a name, size and description if it exists ---------------------------
    $pop_row{pop}= _pop_url( $object, $freq_data{$pop_id}{pop_info}{Name}, $freq_data{$pop_id}{pop_info}{PopLink})."&nbsp;";
    $pop_row{Size} = $freq_data{$pop_id}{pop_info}{Size};

    # Descriptions too long. Only display first sentence
    (my $description = $freq_data{$pop_id}{pop_info}{Description}) =~ s/International HapMap project.*/International HapMap project\.\.\./;
    $description =~ s/<.*?>//g;
    if (length $description > 220) {
      $description = substr($description, 0, 220) ."...";
    }
    $pop_row{Description} = "<small>". ($description ||"-") ."</small>";

    # Super and sub populations ----------------------------------------------
    my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Super-Population"});
    $pop_row{"Super-Population"} =  $super_string;

    my $sub_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Sub-Population"});
    $pop_row{"Sub-Population"} =  $sub_string;

    $panel->add_row(\%pop_row); 
    map {  $columns{$_} = 1 if $pop_row{$_};  } (keys %pop_row);
  }

  # Format table columns ------------------------------------------------------
  my @header_row;
  foreach my $col (sort {$b cmp $a} keys %columns) {
    next if $col eq 'pop';
    if ($col !~ /Population|Description/) {
      unshift (@header_row, {key  =>$col,  'align'=>'left',
 			     title => $col });
    }
    else {
      push (@header_row, {key  =>$col, 'align'=>'left', title => "&nbsp;$col&nbsp;"  });
    }
  }
  unshift (@header_row,  {key  =>"pop",'align'=>'left',  title =>"Population"} );

  $panel->add_columns(@header_row);
  return 1;
}


sub _format_number {

  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my $number = shift;
  if ($number) {
    return sprintf("%.3f", $number );
  }
  return  "unknown";
}

# Variation feature mapping table #############################################


sub mappings {

 ### Mapping_table
 ### Arg1        : panel
 ### Arg2        : data object 
 ### Arg3        : the view name (i.e. "snpview" or "ldview")
 ### Example     :  $mapping_panel->add_components( qw(mappings EnsEMBL::Web::Component::SNP::mappings) );
 ### Description : table showing Variation feature mappings to genomic locations
 ### Returns  1

  my ( $panel, $object, $view ) = @_;
  $view ||= "snpview";
  my %mappings = %{ $object->variation_feature_mapping };

  return [] unless keys %mappings;

  my $source = $object->source;

  my @table_header;
  my $flag_multi_hits = keys %mappings >1 ? 1: 0;
  my $tsv_species =  ($object->species_defs->VARIATION_STRAIN &&  $object->species_defs->get_db eq 'core') ? 1 : 0;

  my $gene_adaptor = $object->database('core')->get_GeneAdaptor();
  foreach my $varif_id (keys %mappings) {
    my %chr_info;
    my $region = $mappings{$varif_id}{Chr};
    my $start  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $link   = "/@{[$object->species]}/contigview?l=$region:" .($start - 10) ."-" . ($end+10);
    my $strand = $mappings{$varif_id}{strand};
    $strand = " ($strand)&nbsp;" if $strand;
    if ($region) {
      $chr_info{chr} = qq(<span style="white-space: nowrap"><a href="$link">$region: $start-$end</a>$strand</span>);
    } else {
      $chr_info{chr} = "unknown";
    }

    if ($flag_multi_hits) {
      my $vari = $object->name;
      my $link = "SNP maps several times:<br /><a href='$view?snp=$vari;c=$region:$start'>Choose this location</a>";
      my $display = $object->param('c') eq "$region:$start" ?
	"Current location" : $link;
      $chr_info{location} = $display;
    }

    my @transcript_variation_data = @{ $mappings{$varif_id}{transcript_vari} };
    unless( scalar @transcript_variation_data ) {
      last unless $flag_multi_hits;
      $panel->add_row(\%chr_info);
      next;
    }
    foreach my $transcript_data (@transcript_variation_data ) {
      my $gene = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{transcriptname});
      my $gene_name = $gene->stable_id if $gene;

      my $gene_link = qq(<a href='geneview?gene=$gene_name'>$gene_name</a>);
      my $transcript_link = qq(<a href='transview?transcript=$transcript_data->{transcriptname}'>$transcript_data->{transcriptname}</a>);
      my $genesnpview = qq(<a href="genesnpview?transcript=$transcript_data->{transcriptname}">SNPs in gene context</a>);
      my $protein_link = qq(<a href='protview?transcript=$transcript_data->{transcriptname}'>$transcript_data->{proteinname}</a>);

      my $transcript_coords = _sort_start_end(
                     $transcript_data->{cdna_start}, $transcript_data->{cdna_end});
      my $translation_coords = _sort_start_end(
                     $transcript_data->{translation_start}, $transcript_data->{translation_end});

      my %trans_info = (
			"conseq"     => $transcript_data->{conseq},
			"transcript" => "$transcript_link:$transcript_coords",
		       );
      $trans_info{'genesnpview'} = $genesnpview;
      $trans_info{'geneview'} = $gene_link if $gene_link;

      if ($transcript_data->{'proteinname'}) {
	$trans_info{'translation'} = "$protein_link:$translation_coords";
	$trans_info{'pepallele'} = "$transcript_data->{pepallele}";
      }


      my $tsv_link;  # TSV link -----------------------------------
      if ($tsv_species) {
	my $strain = $object->species_defs->translate( "strain" )."s";
	$tsv_link = qq(<a href='transcriptsnpview?transcript=$transcript_data->{transcriptname}'>Comapre SNP across $strain</a>);
	$trans_info{'transcriptsnpview'} = "$tsv_link";
      }

      $panel->add_row({ %chr_info, %trans_info});

      unless (@table_header) {
	push (@table_header, {key => 'geneview', title => 'Gene'}, ) if $gene_link;
	push (@table_header, {key => 'transcript', title => 'Transcript<br />relative SNP position'}, );
	push @table_header, {key => 'translation', title => 'Translation<br />relative SNP position'} if $transcript_data->{'proteinname'} ;
	push @table_header, {key => 'pepallele',   title =>'AA'} if $transcript_data->{'pepallele'} ;
	push (@table_header, {key => 'conseq', title =>'Type'});
        push (@table_header, {key => 'genesnpview', title => 'GeneSNPView'},) ;
        push (@table_header, {key => 'transcriptsnpview', title => 'TranscriptSNPView link&nbsp;'},)  if $tsv_species;
      }
      %chr_info = ();
    }
  }
  unshift (@table_header,{key =>'location', title => 'Location'}) if $flag_multi_hits;
  unshift (@table_header, {key =>'chr',title => 'Genomic location (strand)'});

  $panel->add_columns(@table_header);
  return 1;
}



sub _sort_start_end {

 ### Mapping_table
 ### Arg1     : start and end coordinate
 ### Example  : $coord = _sort_star_end($start, $end)_
 ### Description : Returns $start-$end if they are defined, else 'n/a'
 ### Returns  string

  my ( $start, $end ) = @_;
  if ($start or $end){
    return " $start-$end&nbsp;";
  }
  else {return " n/a&nbsp;"};
}

# Location info ###############################################################


sub snpview_image_menu {

  ### Image
  ### Arg1     : panel
  ### Arg2     : data object 
  ### Example  : $image_panel->add_components(qw(
  ###     menu  EnsEMBL::Web::Component::SNP::snpview_image_menu
  ###     image EnsEMBL::Web::Component::SNP::snpview_image
  ###   ));
  ### Description : Creates a menu container for snpview and adds it to the panel
  ### Returns  0

  my($panel, $object ) = @_;
  my $image_config = $object->image_config_hash( 'snpview' );
  my $params =  {
		 'h'          => $object->highlights_string || '',
		 'source'     => $object->source || "dbSNP",
		 'snp'        => $object->name || '',
		 'c'          => $object->param('c') || '',
		 'pop'        => $object->get_default_pop_name || '',
		};
  $image_config->set( '_settings', 'URL', "/".$object->species."/snpview?".
    join(";", map { "$_=".CGI::escapeHTML($params->{$_}) } keys %$params ).
      ";snpview=%7Cbump_", 1);
  $image_config->{'_ld_population'} = $object->get_default_pop_name;
  return 0;
}


sub snpview_image {

### Image
 ### Arg1     : panel
 ### Arg2     : data object
 ### Arg[3]   : width (optional)
 ### Example  : $image_panel->add_components(qw(
 ###     menu  EnsEMBL::Web::Component::SNP::snpview_image_menu
 ###     image EnsEMBL::Web::Component::SNP::snpview_image
 ###   ));
 ### Description : Creates a drawable container for snpview and adds it to the panel
 ### Returns  0

  my($panel, $object) = @_;
  my $width = $object->param('w') || "30000";
  my ($seq_region, $start, $seq_type ) = $object->seq_region_data;
  return [] unless $seq_region;

  my $end   = $start + ($width/2);
  $start -= ($width/2);
  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );

  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $slice, $object->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();
  my ($genotyped_count, $genotyped_snps) = $sliceObj->get_genotyped_VariationFeatures();

  my $wuc = $object->image_config_hash( 'snpview' );
  $wuc->set( '_settings', 'width', $object->param('image_width') );
  $wuc->{'snps'}           = $filtered_snps;
  $wuc->{'genotyped_snps'} = $genotyped_snps;
  $wuc->{'snp_counts'}     = [$count_snps+$genotyped_count, scalar @$filtered_snps+scalar @$genotyped_snps];

  ## If you want to resize this image
  my $image    = $object->new_image( $slice, $wuc, [$object->name] );
  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );
  return 0;
}


sub snpview_noimage {

  ### Image
  ### Arg1     : panel
  ### Arg2     : data object
  ### Example  :  $image_panel->add_components(qw(
  ###      no_image EnsEMBL::Web::Component::SNP::snpview_noimage
  ### ));
  ### Description : Adds an HTML string to the panel if the SNP cannot be mapped uniquely
  ### Returns  1

  my ($panel, $object) = @_;
  $panel->print("<p>Unable to draw SNP neighbourhood as we cannot uniquely determine the SNP's location</p>");
  return 1;
}


# Individual table ############################################################


sub individual {

### Individual_table
 ### Arg1        : panel
 ### Arg2        : data object
 ### Example     : $object->outputIndGenotypeTable
 ### Description : adds a table of Individual genotypes, their refSNP ssids, allele, sex etc. in spreadsheet format to the panel
 ### Returns  1

  my ( $panel, $object) = @_;
  my %ind_data = %{ $object->individual_table };
  unless (%ind_data) {
    $panel->print("<p>No individual genotypes for this SNP</p>");
    return 1;
  }
  # Create header row for output table ---------------------------------------
  my @rows;
  my %columns;
  my $flag_children = 0;

  foreach my $ind_id (sort { $ind_data{$a}{Name} cmp $ind_data{$b}{Name}} keys %ind_data) {
    my %ind_row;
    my $genotype = $ind_data{$ind_id}{Genotypes}; 
    next if $genotype eq '(indeterminate)';

    # Parents -----------------------------------------------------------------
    my $father = _format_parent($object, $ind_data{$ind_id}{Father} );
    my $mother = _format_parent($object, $ind_data{$ind_id}{Mother} );


    # Name, Gender, Desc ------------------------------------------------------
    my $description = uc($ind_data{$ind_id}{Description});
    my @populations = map {_pop_url( $object, $_->{Name}, $_->{Link} ) } @{ $ind_data{$ind_id}{Population} };

    my $pop_string = join ", ", @populations;
    my %tmp_row =  (
		  Individual => "<small>".$ind_data{$ind_id}{Name}."<br />(".
		    $ind_data{$ind_id}{Gender}.")</small>",
		  Genotype   => "<small>$genotype</small>",
		  Description=> "<small>".($description ||"-") ."</small>", 
                  Populations=> "<small>".($pop_string ||"-") ."</small>",
		  Father     => "<small>".($father||"-") ."</small>",
		  Mother     => "<small>".($mother ||"-") ."</small>",
		  );


    #  Children  -------------------------------------------------------------
    my $children =  $ind_data{$ind_id}{Children};
    $tmp_row{Children} = "-";

    my @children = map {"<small>$_: ".$children->{$_}[0]."</small>"} (keys %$children);

    if (@children) {
      $tmp_row{Children} = join "<br />", @children;
      $flag_children = 1;
    }
    $panel->add_row(\%tmp_row);
  }


  my @header_row = ({key =>"Individual", title =>"Individual<br />(gender)"} );
  push (@header_row, 
	{key  =>"Genotype",    title => "Genotype<br />(forward strand)"},
	{key  =>"Description", title => "Description"},
	{key  =>"Populations", title => "Populations", width=>"250"}, 
	{key  =>"Father",      title => "Father"},
	{key  =>"Mother",      title => "Mother"} );

  push (@header_row, {key =>"Children", title =>"Children"}) if $flag_children;

  $panel->add_columns(@header_row);
  return 1;
}



#               INTERNAL CALLS
# Internal: Population table #################################################

sub _sort_extra_pops {

    ### Population_table
    ### Arg1      : data object
    ### Arg2      : hashref with population data
    ### Example   :     my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Super-Population"});
    ### Description : returns string with Population name (size)<br> description
    ### Returns  string

  my ( $object, $extra_pop ) = @_;

  my @pops;
  foreach my $pop_id (keys %$extra_pop  ) {
    my $display_pop = _pop_url( $object, $extra_pop->{$pop_id}{Name}, 
 				       $extra_pop->{$pop_id}{PopLink});
    my $size = $extra_pop->{$pop_id}{Size};
    $size = " (Size: $size)" if $size;
    my $string = "$display_pop $size";
       $string .= "<br /><small>".$extra_pop->{$pop_id}{Description}."</small>" if $extra_pop->{$pop_id}{Description};
  }
  return  (join "<br />", @pops);
}

sub _pop_url {

   ### Arg1        : data object
   ### Arg2        : Population name (to be displayed)
   ### Arg3        : dbSNP population ID (variable to be linked to)
   ### Example     : _pop_url($object, $pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP',$pop_dbSNP->[0] );
}


sub _format_parent {

  ### Internal_individual_table
  ### Arg1        : data object
  ### Arg2        : parent data 
  ### Example     : format_parent(
  ###                $object->parent($object, $ind_genotype,"father") );
  ### Description : Formats output 
  ### Returns  string

  my $object        = shift;
  my $parent_data = shift;
  return "-" unless $parent_data;

  my $string = $parent_data->{Name};
  return $string;
}


# Internal: LD related calls #################################################

sub link_to_ldview {
  
  ### LD
  ### Arg1        : panel
  ### Arg2        : object
  ### Arg3        : hash ref of population data
  ### Example     : link_to_ldview($panel, $object, \%pop_data);
  ### Description : Make links from these populations to LDView
  ### Returns  Table of HTML links to LDView

  my ($panel, $object, $pops ) = @_;
  my $output = "<table width='100%' class='hidden' border=0><tr>";
  $output .="<td> <b>Links to LDview per population:</b></td></tr><tr>";
  my $count = 0;
  for my $pop_name (sort {$a cmp $b} keys %$pops) {
    my $tag = $pops->{$pop_name} eq 1 ? "" : " (Tag SNP)";
    $count++;
    $output .= "<td><a href='ldview?snp=". $object->name;
    $output .=  ";c=".$object->param('c') if $object->param('c');
    $output .=  ";w=".($object->param('w') || "20000");
    $output .=	";bottom=opt_pop_$pop_name:on'>$pop_name</a>$tag</td>";
    if ($count ==3) {
      $count = 0;
      $output .= "</tr><tr>";
    }
  }
  $output .= "</tr></table>";
  return  $output;
}


sub _ld_populations {

  ### LD
  ### Arg1        : object
  ### Example     : ld_populations()
  ### Description : data structure with population id and name of pops 
  ### with LD info for this SNP
  ### Returns  hashref

  my $object = shift;
  my $pop_ids = $object->ld_pops_for_snp;
  return {} unless @$pop_ids;

  my %pops;
  foreach (@$pop_ids) {
    my $pop_obj = $object->pop_obj_from_id($_);
    $pops{ $pop_obj->{$_}{Name} } = 1;
  }
  return \%pops;
}


sub _flip_URL {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?snp=%s;db=%s;%s', $object->species, $object->script, $object->name, $object->param('source'), $code;
}

1;

