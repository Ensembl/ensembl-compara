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
  my %pops;
  my @bottom = $object->param('bottom');

  foreach my $tmp ( @bottom  ) {
    foreach (split /\|/, $tmp) {
      next unless $_ =~ /opt_pop_(.*):(\w*)/;
      $pops{$1} = 1 if $2 eq 'on';
    }
  }

  unless (keys %pops) {
    warn "****** ERROR: No population defined";
    return;
  }

  # Header info -----------------------------------------------------------
  # Check there is data to display
  my $zoom = $object->param('w')|| 50000;
  my %return;

  foreach my $pop_name ( keys %pops ) {
    my $pop_obj = $object->pop_obj_from_name($pop_name);
    my $pop_id = $pop_obj->{$pop_name}{dbID};
    my $data = $object->ld_for_slice($pop_id);
    foreach my $ldtype ( "r2", "d_prime" ) {
      my $display = $ldtype eq 'r2' ? "r2" : "D'";
      my $nodata = "No $display linkage data in $zoom kb window for population $pop_name";
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
  ###  Description : Calls ld_values function which returns the data in text format
  ###              This function formats the data into HTML
  ###               It prints a title and the LD values in an HTML table to the panel.
  ###  Returns 1

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
      my $header_row = qq(
    <th>SNPs: bp position</th>
    <td>@{[ shift @$snps ]}: $start</td>);

      # Fill rest of table ----------------------------------------------------
      my $user_config = $object->user_config_hash( 'ldview' );
      my @colour_gradient = ('ffffff', $user_config->colourmap->build_linear_gradient( 41,'mistyrose', 'pink', 'indianred2', 'red' ));
      
      my $table_rows;
      foreach my $row (@$table_data) {
	next unless ref $row eq 'ARRAY';
	my $snp = shift @$snps;
	my $pos = shift @$starts;
	my $snp_string = $snp =~/^\*/ ? qq(<strong>$snp: $pos</strong>) : "$snp: $pos";

	$table_rows .= qq(
  <tr style="vertical-align: middle"  class="small">
    <td class="bg2">$snp_string</td>).
      join( '', map { 
	sprintf qq(\n    <td class="center" style="background-color:#%s">%s</td>),
	  $colour_gradient[floor($_*40)],
	    $_ ? sprintf("%.3f", $_ ): '-' } @$row );

	$table_rows .= qq(
    <td class="bg2">$snp_string</td>
  </tr>);
	next if $row == $table_data->[-1];
	$header_row .= qq(
    <td>$snp_string</td>);
      }
      $panel->print(qq(
                     <table width="100%">  
                        <tr class="bg2 small">
                           $header_row
                        </tr>$table_rows
                        <tr class="bg2 small">
                           $header_row
                      </tr>
                      </table>));
    }
  }
  return 1;
}


###############################################################################


sub text_lddata {

  ### Args      :  Either a string with "No data" message or Arrayref 
  ###               Each value in the array is an arrayrefs with 
  ###                    arrayref of SNP start positions in basepair (start order)
  ###                    Arrayref of SNP names in start order
  ###                    Arrayref 2 dimensional array of LD values
  ### Example     : $self->text_ldtable({$title, \@starts, \@snps, \@table});
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

}

1;


