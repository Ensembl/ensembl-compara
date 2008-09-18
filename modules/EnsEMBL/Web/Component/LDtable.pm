package EnsEMBL::Web::Component::LDtable;

# Puts together chunks of XHTML for LD-based displays

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use POSIX qw(floor ceil);

use strict;
use warnings;
no warnings "uninitialized";

sub ld_values {

  ### Arg1      :  The data object
  ### Example     :  my $return = ld_values($object);
  ### Description : Array of pairwise values which can then be formatted to be a table
  ###               in text, html, excel format etc. Only the bottom left half of the 
  ###               in text, html, excel format etc. Only the bottom left half of the 
  ###               table''s values are filled in to avoid duplicating the data
  ###               displayed.
  ###               The last SNP column is not rendered as all pairwise data 
  ###               for this SNP is already displayed elsewhere in the table
  ###               The first SNP row is not displayed as this would just 
  ###               duplicated data
  ### Returns  hashref
  ### Return info : 
  ###     Keys are the type of LD data (r2, dprime)
  ###     For each $return{"r2"} there are two keys: data, and text
  ###     The text string is the title for the table
  ###     The data is an array ref with three array refs: start postitions, 
  ###     snpnames and the rest of the table data
  ###     Each value in the array is an arrayrefs with 
  ###       arrayref of SNP start positions in basepair (start order)
  ###       Arrayref of SNP names in start order
  ###       Arrayref 2 dimensional array of LD values

  my $object = shift;
  my %pops = %{ _get_pops_from_param($object) };

  unless (keys %pops) {
    warn "****** ERROR: No population defined";
    return;
  }

  # Header info -----------------------------------------------------------
  # Check there is data to display
  my $zoom = $object->param('w')|| 50000;
  my %return;
  my $display_zoom = $object->round_bp($zoom);

  foreach my $pop_name (sort keys %pops ) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    next unless $pop_obj;
    my $pop_id = $pop_obj->{$pop_name}{dbID};
    my $data = $object->ld_for_slice($pop_obj->{$pop_name}{'PopObject'}, $zoom);
    foreach my $ldtype ( "r2", "d_prime" ) {
      my $display = $ldtype eq 'r2' ? "r2" : "D'";
      my $nodata = "No $display linkage data in $display_zoom window for population $pop_name";
      unless (%$data && keys %$data) {
	$return{$ldtype}{$pop_name}{"text"} = $nodata;
	next;
      }

      my @snp_list = 
	sort { $a->[1]->start <=> $b->[1]->start }
	  map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
	    keys %{ $data->{'variationFeatures'} };

      unless (scalar @snp_list) {
	$return{$ldtype}{$pop_name}{"text"} = $nodata;
	next;
      }

      # Do each column starting from 1 because first col is empty---------
      my @table;
      my $flag = 0 ;
      for (my $xcounter=0; $xcounter < scalar @snp_list; $xcounter++) { 

	# Do from left side of table row across to current snp
	for (my $ycounter= 0; $ycounter < $xcounter; $ycounter++) {
	  my $ld_pair1 ="$snp_list[$xcounter]->[0]".-$snp_list[$ycounter]->[0];
	  my $ld_pair2 ="$snp_list[$ycounter]->[0]".-$snp_list[$xcounter]->[0];
	  my $cell;
	  if ( $data->{'ldContainer'}{$ld_pair1}) {
	    $cell = $data->{'ldContainer'}{$ld_pair1}{$pop_id}{$ldtype};
	  }
	  elsif ( $data->{'ldContainer'}{$ld_pair2}) {
	    $cell = $data->{'ldContainer'}{$ld_pair2}{$pop_id}{$ldtype};
	  }
	  $flag = $cell ? 1 : 0 unless $flag;
	  $table[$xcounter][$ycounter] = $cell;
	}
      }
      unless ($flag) {
	$return{$ldtype}{$pop_name}{"text"} = $nodata;
	next;
      }

      # Turn snp_list from an array of variation_feature IDs to SNP 'rs' names
      # Make current SNP bold
      my @snp_names;
      my @starts_list;
      my $snp = $object->param('snp') || "";
      foreach (@snp_list) {
	my $name = $_->[1]->variation_name;  #name
	if ($name eq $snp or $name eq "rs$snp") {
	  push (@snp_names, "*$name*");
	} else { 
	  push (@snp_names,  $name);     }

	my( $start, $end ) = ($_->[1]->start, $_->[1]->end ); #position
	my $pos =  $start;
	if($start > $end  ) {
	  $pos = "between $start & $end";
	}  elsif($start < $end ) {
	  $pos = "$start-"."$end";
      }
	push (@starts_list, $pos);
      }

      my $location = $object->seq_region_name .":".$object->seq_region_start.
	"-".$object->seq_region_end;
      $return{$ldtype}{$pop_name}{"text"}     = "Pairwise $display values for $location.  Population: $pop_name";
      $return{$ldtype}{$pop_name}{"data"} = [\@starts_list, \@snp_names, \@table];
    } # end foreach
  }
  return \%return;
}


###############################################################################


sub html_lddata { return output_lddata( @_ ); }
sub text_lddata { return output_lddata( @_ ); }
sub excel_lddata { return output_lddata( @_ ); }

sub output_lddata {

  ### The arguments are either a string with "No data" message or Arrayref
  ### Each value in the array is an arrayrefs with  arrayref of 
  ### SNP start positions in basepair (start order), 
  ### arrayref of SNP names in start order,
  ### Arrayref 2 dimensional array of LD values,
  ### Example : $self->excel_ldtable({$title, \@starts, \@snps, \@table});
  ### Description : prints excel formatted table for LD data

  my ($panel, $object ) = @_;
  my $return = ld_values($object);

  return 1 unless %$return;

  # Formatting
  my $renderer = $panel->renderer;
  my $table_renderer = $renderer->new_table_renderer();

  my @colour_gradient = @{ _get_colour_gradient($object) };

  my %populations = ();
  foreach my $ldtype (keys %$return) {
    foreach my $pop_name (keys %{$return->{$ldtype}}) {
      $populations{$pop_name}=1;
    }
  }
   
  foreach my $pop_name ( sort {$a cmp $b } keys %populations ) {
    my $flag = 1;
    foreach my $ldtype (keys %$return) {
      my $C = 0;
      unless ( $return->{$ldtype}{$pop_name}{"data"} ) {
  	next;
      }
      $C++;
      my ( $starts, $snps, $table_data ) = (@ {$return->{$ldtype}{$pop_name}{"data"} });
      (my $T = $pop_name ) =~ s/[^\w\s]/_/g;
      warn "SHEET NAME: $ldtype $T";
      if( $flag ) {
        $table_renderer->new_sheet( "$T" );  # Start a new sheet (and new table)
        $flag = 0;
      } else {
        $table_renderer->new_table();        # Start a new table!
      }
      $table_renderer->set_width( 2 + @$snps );
      $table_renderer->heading( $return->{$ldtype}{$pop_name}{"text"} );
      $table_renderer->new_row();

      $table_renderer->write_header_cell( "bp position" );
      $table_renderer->write_header_cell( "SNP"         );
      foreach( @$snps ) {
        $table_renderer->write_header_cell( $_ );
      }
      $table_renderer->new_row();
      unshift (@$table_data, []);
      
      foreach my $table_row (@$table_data) {
	next unless ref $table_row eq 'ARRAY';
	my $snp = shift @$snps;
	my $pos = shift @$starts;
	$table_renderer->write_header_cell( $pos );
	$table_renderer->write_header_cell( $snp );

	my $col =2;
	my @ld_values = ( map {  $_ ? sprintf("%.3f", $_ ): '-' } @$table_row );

	foreach my $value (@ld_values) {
          my $format = $table_renderer->new_format({
            'align'   => 'center',
            'bgcolor' => $value eq '-' ? 'ffffff' : $colour_gradient[floor($value*40)]
          });
	  $table_renderer->write_cell( $value, $format );
	}
        $table_renderer->write_header_cell( $snp );
	$table_renderer->new_row;
      }
    }
  }
  $table_renderer->clean_up;
}


sub text_haploview {

  ### Format: olumns of family, individual, father, mother, gender, affected status and genotypes

  my ($panel, $object) = @_;
  my %pops = _get_pops_from_param($object);
  return unless keys %pops;
  my $snps = $object->get_variation_features;
  my %ind_data = %{ $object->individual_table };
  unless (%ind_data) {
    $panel->print("No individual genotypes for this SNP");
    return 1;
  }
}


sub _get_pops_from_param {
  
  ### Arg1 : Proxy object
  ### Gets population names from 'bottom' CGI parameter and puts them
  ### into a hash with population names as keys
  ### Returns hashref

  my ($object) = @_;
  my %pops = ();
  my @bottom = $object->param('bottom');

  foreach my $tmp ( @bottom  ) {
    foreach (split /\|/, $tmp) {
      next unless $_ =~ /opt_pop_(.*):(\w*)/;
      $pops{$1} = 1 if $2 eq 'on';
    }
  }
  return \%pops;
}


sub _get_colour_gradient {
  my ($object) = @_;
  my $image_config = $object->image_config_hash( 'ldview' );
  my @colour_gradient = ('ffffff', $image_config->colourmap->build_linear_gradient( 41,'mistyrose', 'pink', 'indianred2', 'red' ));
  return \@colour_gradient || [];
}

#--------------------------------------------------------------------

sub haploview_dump {
  my( $panel, $object ) = @_;
  my $FN        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my ($PATH,$FILE) = $object->make_directory( $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN" );
  my $ped_file  = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN.ped";
  my $info_file = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN.txt";
  my $ped_url   = $object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN.ped";
  my $info_url  = $object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN.txt";
  my $both_url  = $object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN.tar.gz";

  haploview_files( $ped_file, $info_file,  $object );

  system( "cd $PATH; tar cf - $FILE.ped $FILE.txt | gzip -9 > $FILE.tar.gz" );
  $panel->print(qq (<p>
    Your export has been processed successfully. You can download
    the exported data by following the links below.
  </p>
  <ul>
    <li><strong>Genotype file:</strong> <a target="_blank" href="$ped_url">genotypes.ped</a> [Genotypes in linkage format]</li>
    <li><strong>Locus information:</strong> <a target="_blank" href="$info_url">marker_info.txt</a> [Locus information file]</li>
  </ul>
  <p><strong>OR</strong>
  <ul>
    <li><strong>Combined file:</strong> <a href="$both_url">haploview_files.tar.gz</a></li>
  </ul>

  <p>These files can be uploaded into the  <a href="http://www.broad.mit.edu/mpg/haploview/index.php">Haploview</a> software for further haplotype analysis.  The linkage file name must end in ".ped" and 
the marker one in ".txt".</p>
  )
  );
  return 1;
}


sub haploview_files {
  my( $PED, $INFO, $object ) = @_;
  open PED,  ">$PED"; 
  open INFO, ">$INFO"; 

  my %ind_genotypes;
  my %individuals;
  my @snps;
  #gets all genotypes in the Slice as a hash. where key is region_name-region_start
  my $slice_genotypes = $object->get_all_genotypes();
  
  foreach my $vf ( @{ $object->get_variation_features } ) {
    my ($genotypes, $ind_data) =  $object->individual_genotypes($vf,$slice_genotypes);
    next unless %$genotypes;

    my $name = $vf->variation_name;
    print INFO join " ", $name, $vf->start."\n";
    push @snps, $name;

    #ind_genotypes{individual}{snp} = genotype
    map { $ind_genotypes{$_}{$name} = $genotypes->{$_} } (keys %$genotypes);
    map { $individuals{$_} = $ind_data->{$_} } (keys %$ind_data);
  }

  my $family;

  foreach my $individual (keys %ind_genotypes) {
    my $output = join "\t", ("FAM".$family++, 
			    $individual, 
			    $individuals{$individual}{father}, 
			    $individuals{$individual}{mother}, 
			    $individuals{$individual}{gender}, 
			    "0\t");

    foreach my $snp (@snps) {
      my $genotype = $ind_genotypes{$individual}{$snp} || "00";
      $genotype =~ tr/ACGTN/12340/;
      $output .= join " ", (split //, $genotype);
      $output .= "\t";
    }
    print PED "$output\n";
  }
  close PED;
  close INFO;
}

1;

