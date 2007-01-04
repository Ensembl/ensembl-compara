package EnsEMBL::Web::Component::LDtable;

# Puts together chunks of XHTML for LD-based displays

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use POSIX qw(floor ceil);

use strict;
use warnings;
no warnings "uninitialized";

use Spreadsheet::WriteExcel;


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
      $return{$ldtype}{$pop_name}{"text"} = "Pairwise $display values for $location.  Population: $pop_name";
      $return{$ldtype}{$pop_name}{"data"} = [\@starts_list, \@snp_names, \@table];
    } # end foreach
  }
  return \%return;
}


###############################################################################


sub html_lddata {

  ###  Args      : panel, object
  ### It first calls ld_values function which returns the data in 
  ### text format.  It formats this data into HTML and 
  ### prints a title and the LD values in an HTML table to the panel.
  ### Returns 1

  my ($panel, $object) = @_;
  my $return = ld_values($object);
  return 1 unless defined $return && %$return;

  foreach my $ldtype (keys %$return) {
    foreach my $pop_name ( sort {$a cmp $b } keys %{ $return->{$ldtype} } ) {
      $panel->print("<h4>", $return->{$ldtype}{$pop_name}{"text"}, "</h4>");
      unless ( $return->{$ldtype}{$pop_name}{"data"} ) {
        next;
      }

      my ( $starts, $snps, $table_data ) = (@ {$return->{$ldtype}{$pop_name}{"data"} });
      if (!$starts) { # there is no data for this area
	return 1;
      }
      my $start      = shift @$starts;
      my $first_snp  = shift @$snps;
      my $url =  qq(<a href="snpview?snp=%s">%s</a>);
      my $first_snp_link = sprintf($url, $first_snp, $first_snp).": $start";
      my $footer_row = qq(<th>SNPs: bp position</th><td>$first_snp_link</td>);
      my $header_row = qq(<th>SNPs: bp position</th>
                         <td class="bg2">$first_snp_link</td>);

      # Fill rest of table ----------------------------------------------------
      my @colour_gradient = @{ _get_colour_gradient($object) };
      my $table_rows;
      foreach my $row (@$table_data) {
	next unless ref $row eq 'ARRAY';
	my $snp = shift @$snps;
	my $pos = shift @$starts;
	my $snp_string = $snp =~/^\*/ ? "<strong>". sprintf($url, $snp, $snp).": $pos</strong>" : sprintf($url, $snp, $snp).": $pos";
	$table_rows .= qq(
  <tr style="vertical-align: middle"  class="small">
    <td class="bg2">$snp_string</td>).
      join( '', map { 
	sprintf qq(\n    <td class="center" style="background-color:#%s">%s</td>),
	  $colour_gradient[floor($_*40)],
	    $_ ? sprintf("%.3f", $_ ): '-' } @$row );

	$table_rows .= qq(
    <td class="bg2">$snp_string</td>
  </tr>) if scalar @$snps;
	next if $row == $table_data->[-1];
	$footer_row .= qq(
    <td>$snp_string</td>);
      }
      $panel->print(qq(
                     <table width="100%">  
                        <tr class="bg2 small">
                           $header_row
                        </tr>$table_rows
                        <tr class="bg2 small">
                           $footer_row
                      </tr>
                      </table>));
    }
  }
  return 1;
}


###############################################################################


sub text_lddata {

  ### Args:  Either a string with "No data" message or Arrayref 
  ### Each value in the array is an arrayrefs with arrayref of 
  ### SNP start positions in basepair (start order)
  ### Arrayref of SNP names in start order
  ### Arrayref 2 dimensional array of LD values
  ### Example : $self->text_ldtable({$title, \@starts, \@snps, \@table});
  ### Description : prints text formatted table for LD data
  ### Returns text (string)

  my ($panel, $object) = @_;
  my $return = ld_values($object);
  return 1 unless %$return;

  foreach my $ldtype (keys %$return) {
   foreach my $pop_name ( sort {$a cmp $b } keys %{ $return->{$ldtype} } ) {
     $panel->print($return->{$ldtype}{$pop_name}{"text"}."\n");
     unless ( $return->{$ldtype}{$pop_name}{"data"} ) {
       next;
     }

     my ( $starts, $snps, $table_data ) = (@ {$return->{$ldtype}{$pop_name}{"data"} });
     my $output = "\nbp position\tSNP\t". (join "\t", @$snps);
     unshift (@$table_data, [""]);

     foreach my $row (@$table_data) {
       next unless ref $row eq 'ARRAY';
       my $snp = shift @$snps;
       my $pos = shift @$starts;

       $output .= "\n$pos\t$snp\t";
       $output .= join "\t", (map {  $_ ? sprintf("%.3f", $_ ): '-' } @$row );
     }
     $output .="\n\n";
     $panel->print("$output");
   }
 }
  return 1;
}

################################################################################

sub excel_lddata {

  ### The arguments are either a string with "No data" message or Arrayref
  ### Each value in the array is an arrayrefs with  arrayref of 
  ### SNP start positions in basepair (start order), 
  ### arrayref of SNP names in start order,
  ### Arrayref 2 dimensional array of LD values,
  ### Example : $self->excel_ldtable({$title, \@starts, \@snps, \@table});
  ### Description : prints excel formatted table for LD data

  my ($panel, $object) = @_;
  my $return = ld_values($object);
  return 1 unless %$return;

  # Formatting
  my $bold_center = $panel->new_format;
  $panel->bold($bold_center, 1);
  $panel->align($bold_center, "center" );

  my $italic_bold = $panel->new_format;
  $panel->italic($italic_bold, 1);
  $panel->bold($italic_bold, 1);

  my @colour_gradient = @{ _get_colour_gradient($object) };
  my $excel_row = 0;
  foreach my $ldtype (keys %$return) {
    foreach my $pop_name ( sort {$a cmp $b } keys %{ $return->{$ldtype} } ) {
      $panel->print($return->{$ldtype}{$pop_name}{"text"});
      unless ( $return->{$ldtype}{$pop_name}{"data"} ) {
 	next;
      }

      my ( $starts, $snps, $table_data ) = (@ {$return->{$ldtype}{$pop_name}{"data"} });

      $panel->write_cell( "bp position", $bold_center);
      $panel->write_cell( "SNP", $bold_center);
      $panel->write_cell( $snps, $bold_center);
      $panel->next_row();
      unshift (@$table_data, [""]);
      
      foreach my $table_row (@$table_data) {
	next unless ref $table_row eq 'ARRAY';
	my $snp = shift @$snps;
	my $pos = shift @$starts;
	$panel->write_cell( $pos, $bold_center);
	$panel->write_cell( $snp, $bold_center);

	my $col =2;
	my @ld_values = ( map {  $_ ? sprintf("%.3f", $_ ): '-' } @$table_row );

	foreach my $value (@ld_values) {
	  my $center = $panel->new_format;
	  $panel->align($center, "center");

	  if ( $value eq '-' ) {
	    $panel->bg_color($center, 9);
	  }
	  else {
	    my $index = $panel->custom_color( "#".$colour_gradient[floor($value*40)] );
	    $panel->bg_color($center, $index);
         }
	  $panel->write_cell( $value, $center);
	}
	$panel->next_row;
      }
      $panel->next_row;
      $panel->next_row;
    }
 #   $panel->close_sheet;
  }
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
  my $user_config = $object->user_config_hash( 'ldview' );
  my @colour_gradient = ('ffffff', $user_config->colourmap->build_linear_gradient( 41,'mistyrose', 'pink', 'indianred2', 'red' ));
  return \@colour_gradient || [];
}

1;

