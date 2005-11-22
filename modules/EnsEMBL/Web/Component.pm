package EnsEMBL::Web::Component;

use strict;
use Data::Dumper;
$Data::Dumper::Indent = 3;
use EnsEMBL::Web::Form;

@EnsEMBL::Web::Component::ISA = qw(EnsEMBL::Web::Root);


sub format_das_panel {
  my( $panel, $object,$status, $URL ) = @_;
# Get parameters to be passed to dasconfview script

  my $params ='';
  my @cparams = qw ( db gene transcript peptide );

  my $hidden = '';

  foreach my $param (@cparams) {
    if( defined(my $v = $object->param($param)) ) {
      $hidden .= sprintf qq(<input type="hidden" name="%s" value="%s" />\n), $param, $v;
      $params .= ";$param=$v";
    }
  }

  my $script  = $object->script;
  my $species  = $object->species;
# The code below to be rewritten to use new Web::Form module

# Template for a checkbox that switches the source on/off
  my $checkbox_tmpl = qq{
    <input type="checkbox" name="DASselect_%s" value="1" %s onClick='javascript:document.dasForm.submit()' /> %s 
    <input type="hidden" name="DASselect" value="%s" />
};

  my @checks = ();
# Get the DAS configuration
  my $das_collection     = $object->get_DASCollection;

  my $das_attribute_data = $das_collection->get_DASAdaptor_attributes_by_method(qw(
    name authority description conftype active type
  ));

# Now display the annotation from the selected sources

  my $link_tmpl = qq(<a href="%s" target="%s">%s</a>);

# Template for annotations is :
# TYPE (TYPE ID) FEATURE (FEATURE ID) METHOD (METHOD ID) NOTE SCORE
#
# TYPE ID, FEATURE ID and METHOD ID appear only if present and different from
#
# TYPE, FEATURE and METHOD respectively
#
# NOTE and SCORE appear only if there are values present
 
  my $row_tmpl = qq(
  <tr valign="top">
    <td>%s %s</td>
    <td><strong>%s %s</strong></td>
    <td>%s %s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
  </tr>);

# For displaying the chromosome based features
  my %FLabels = (
    0 => 'Feature contained by gene', 
    1 => 'Feature overlaps gene',
    2 => 'Feature overlaps gene',
    3 => 'Feature contains gene',
    4 => 'Feature colocated with gene'
  );


  foreach my $source( @$das_attribute_data ){
    $source->{active} || next;
    my $source_nm = $source->{name};
    my $label = "<a name=$source_nm></a>$source_nm";

    my @rhs_rows = ();
# Check the source type, if it is 'ensembl_location' then we need to query the DAS source using the chromosome coordinates of the gene rather than its ID
    if( $source->{type} eq 'ensembl_location' ) { 
      my $slice = $object->get_Slice();
      my @features = $object->get_das_features_by_slice($source_nm, $slice);
      my $slice_length = $slice->end - $slice->start;
      
      my (%uhash) = (); # to filter out duplicates
      my (@filtered_features) = ();

# Filter out features that we are not interested in      
      foreach my $feature (grep { $_->das_type_id() !~ /^(contig|component|karyotype)$/i && $_->das_type_id() !~ /^(contig|component|karyotype):/i } @features) {
        my $id = $feature->das_feature_id;
        if( defined($uhash{$id}) ) {
          $uhash{$id}->{start}  = $feature->das_start if ($uhash{$id}->{start} > $feature->das_start);
          $uhash{$id}->{end}    = $feature->das_end   if ($uhash{$id}->{end} < $feature->das_end);
          $uhash{$id}->{merged} = 1;
        } else {
          $uhash{$id}->{start}  = $feature->das_start;
          $uhash{$id}->{end}    = $feature->das_end;
          $uhash{$id}->{type_label}  = $feature->das_type;
	  if ($feature->das_type ne $feature->das_type_id) {
	      $uhash{$id}->{type_id}     = $feature->das_type_id;
	  }
          $uhash{$id}->{method_label}  = $feature->das_method;
	  if ($feature->das_method ne $feature->das_method_id) {
	      $uhash{$id}->{method_id}     = $feature->das_method_id;
	  }
	  $uhash{$id}->{feature_label} = $feature->das_feature_label;
	  if ($feature->das_feature_id ne $feature->das_feature_label) {
	      $uhash{$id}->{feature_id}     = $feature->das_feature_id;
	  }

	  $uhash{$id}->{score}  = $feature->das_score;

          my $segment = $feature->das_segment->ref;

	  if (my $flink = $feature->das_link) {
	      my $href = $flink->{'href'};
	      $uhash{$id}->{label} = sprintf( $link_tmpl, $href, $segment, $feature->das_feature_label );
          } else {
            $uhash{$id}->{label} = $feature->das_feature_label;
          }

          if( my $note = $feature->das_note ){
            $note=~s|((\S+?):(http://\S+))|
              <a href="$3" target="$segment">[$2]</a>|ig;
            $note=~s|([^"])(http://\S+)([^"])|
              $1<a href="$2" target="$segment">$2</a>$3|ig;
            $note=~s|((\S+?):navigation://(\S+))|
              <a href="$script?gene=$3">[$2]</a>|ig;
            $uhash{$id}->{note} = $note;
          }
        }
      }
      foreach my $id ( sort { 
	  $uhash{$a}->{type_label} cmp $uhash{$b}->{type_label} || 
	  $uhash{$a}->{feature_label} cmp $uhash{$b}->{feature_label} 
      } keys(%uhash )) {
# Build up the type of feature location    : see FLabels hash few lines above for location types
        my $ftype = 0;
        if( $uhash{$id}->{start} == $slice->start ) {
          if( $uhash{$id}->{end} == $slice_length ) {
            # special case - feature fits the gene exactly
            $ftype = 4;
          }
        } else {
          if ($uhash{$id}->{start} < 0) {
            # feature starts before gene starts
            $ftype |= 2;
          }
          if ($uhash{$id}->{end} > $slice_length) {
            # feature ends after gene ends
            $ftype |= 1;
          }
        }
	my $score = ($uhash{$id}->{score} > 0) ? sprintf("%.02f", $uhash{$id}->{score}) : "&nbsp;"; 

        my $fnote = sprintf("%s%s", (defined($uhash{$id}->{merged})) ? "Merged " : "", $FLabels{$ftype});
        push( @rhs_rows, sprintf( $row_tmpl, 
          $uhash{$id}->{type_label}  || '&nbsp;',
	  $uhash{$id}->{type_id} ? qq{($uhash{$id}->{type_id})} : '&nbsp;',
          $uhash{$id}->{label} || "&nbsp",
	  $uhash{$id}->{feature_id} ? qq{($uhash{$id}->{feature_id})} : '&nbsp;',
	  $uhash{$id}->{method_label}  || '&nbsp;',
	  $uhash{$id}->{method_id} ? qq{($uhash{$id}->{method_id})} : '&nbsp;',
          $fnote               || "&nbsp",
          $uhash{$id}->{note}  ?  '<small>'.$uhash{$id}->{note}.'</small>' : '&nbsp;',
	  $score,

        ) );
      }
    } else {
	
      my @features = $object->get_das_features_by_name($source_nm);
      foreach my $feature( sort{ $a->das_type_id    cmp $b->das_type_id ||
                                 $a->das_feature_id cmp $b->das_feature_id ||
                                 $a->das_note cmp $b->das_note } @features ) {
        next if ($feature->das_type_id() =~ /^(contig|component|karyotype|INIT_MET)$/i ||
                 $feature->das_type_id() =~ /^(contig|component|karyotype|INIT_MET):/i);
        next if ($feature->start && $feature->end);
        my $segment = $feature->das_segment->ref;
	my $label = $feature->das_feature_label;
	if (my $flink = $feature->das_link) {
	    my $href = $flink->{'href'};
	    $label = sprintf( $link_tmpl, $href, $segment, $label );
	}

	my $score  = ($feature->das_score > 0) ? sprintf("%.02f",$feature->das_score) : '&nbsp;';
        my $note;
        if( $note = $feature->das_note ) {
          $note=~s|((\S+?):(http://\S+))|
            <a href="$3" target="$segment">[$2]</a>|ig;
          $note=~s|([^"])(http://\S+)([^"])|
            $1<a href="$2" target="$segment">$2</a>$3|ig;
          $note=~s|((\S+?):navigation://(\S+))|
            <a href="$script?gene=$3" >[$2]</a>|ig;
          $note=~s|([^:])//\s+|$1<br \/>|ig;
        }

        push( @rhs_rows, sprintf( $row_tmpl, 
          $feature->das_type || '&nbsp;',
          ($feature->das_type_id eq $feature->das_type) ? '&nbsp;' :
	      "(".$feature->das_type_id.")",
          $label                || '&nbsp;',
	  ($feature->das_feature_id eq $feature->das_feature_label) ? '&nbsp;':
	      "(".$feature->das_feature_id.")",
	  $feature->das_method,
	  ($feature->das_method_id eq $feature->das_method) ? '&nbsp;':
	      "(".$feature->das_method_id.")",
          $note              || '&nbsp;',
	  $score,
          '&nbsp;'
        ) );
      }  
    }

    if( scalar( @rhs_rows ) == 0 ){
      $panel->add_row( $label, qq(<p>No annotation</p>) );
    } else {
      $panel->add_row($label, qq(
<table class="hidden">
  @rhs_rows
</table>)
      );
    }
  }

  ###### Collapse/expand switch for the DAS sources panel 
  my $label = 'DAS Sources';
  if( ($object->param( $status ) || ' ' ) eq 'off' ) { 
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

  ###### Get the switched on sources
  my @T = ($object->param("DASselect"));
  my %selected_das = map {$_ => 1} $object->param("DASselect");
  foreach my $source ( grep { $_->{conftype} ne 'url' } @$das_attribute_data ) {
    my $name        = $source->{name} || ( warn "DAS source found with no name attribute" ) && next;
    my $selected    = $selected_das{$name} ? 'checked="checked"' : '';
    my $label       = $source->{authority} ? qq(<a href="$source->{authority}" target="_blank">$name</a>) : $name;
    $label         .= " ($source->{description})" if $source->{'description'};
    push @checks, sprintf( $checkbox_tmpl, $name, $selected, $label, $name);
  }
  my $html = qq( 
<form name="dasForm" id="dasForm" method="get" action="/@{[$species]}/@{[$script]}">
<dl>
  @{[ map { "<dt>$_</dt>\n" } @checks ]}
</dl>
$hidden
  <input type="button" value="Manage Sources" onClick="X=window.open('/@{[$species]}/dasconfview?conf_script=$script;$params','das_sources','left=10,top=10,resizable,scrollbars=yes');X.focus()" />
</form>);
  $panel->add_row( $label, $html, "$URL=off" );
  ###### End of the sources selector form
}


1;
