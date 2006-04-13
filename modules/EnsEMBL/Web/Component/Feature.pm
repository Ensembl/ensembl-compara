package EnsEMBL::Web::Component::Feature;

#------------------------------------------------------------------
# outputs chunks of XHTML for displays of miscellaneous features
# - karyotypes, spreadsheets of data, etc.
#-------------------------------------------------------------------

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Chromosome;
use Data::Dumper;
use Bio::EnsEMBL::GlyphSet::Videogram;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

our %pointer_defaults = ( 
            'Gene'      => ['blue', 'lharrow'],
            'AffyProbe' => ['red', 'rharrow'],
            'Disease'   => ['red', 'rhbox'],
  );


#---------------------------------------------------------------------------

sub fv_select      { _wrap_form($_[0], $_[1], 'fv_select'); }
sub fv_layout      { _wrap_form($_[0], $_[1], 'fv_layout'); }

sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub spreadsheet_featureTable {
  my( $panel, $object ) = @_;

  # get feature data
  my( $data, $extra_columns, $initial_columns, $options ) = $object->retrieve_features;
  my @data = [];
  my $data_type = $object->param('type');
warn $data;
  # spreadsheet headers
  # columns common to all features
  $panel->add_option( 'triangular', 1 );
  my $C = 0;
  for( @{$initial_columns||[]} ) {
    $panel->add_columns( {'key' => "initial$C", 'title' => $_, 'width' => '10%', 'align' => 'center' } );
    $C++;
  }

  $panel->add_columns(
    {'key' => 'loc', 'title' => 'Location', 'width' => '25%', 'align' => 'left' },
  ) unless $data_type eq 'Disease';
  if ($data_type eq 'Gene') {
    $panel->add_columns(
      {'key' => 'extname', 'title' => 'External names', 'width' => '25%', 'align' => 'left' },
    );
  } 
  elsif ($data_type eq 'Disease') {
    $panel->add_columns(
      {'key' => 'extname', 'title' => 'OMIM ID', 'width' => '25%', 'align' => 'left' },
    );
  } else {
    $panel->add_columns(
      {'key' => 'length', 'title' => 'Length', 'width' => '10%', 'align' => 'center' },
    );
  }
  $panel->add_columns(
    {'key' => 'names', 'title' => 'Name(s)', 'width' => '25%', 'align' => 'left' },
  );
  # add extra columns
  $C = 0;
  for( @{$extra_columns||[]} ) {
    $panel->add_columns({'key' => "extra$C", 'title' => $_, 'width' => '10%', 'align' => 'center'} );
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
    $contig_link = sprintf('<a href="/%s/contigview?c=%s:%d;w=%d;h=%s">%s:%d-%d(%d)</a>',
      $object->species, $row->{'region'}, int( ($row->{'start'} + $row->{'end'} )/2 ), 
      $row->{'length'} + 1000, join( '|',split(/\s+/,$row->{'label'}),$row->{'extname'}), $row->{'region'}, $row->{'start'}, $row->{'end'}, $row->{'strand'} 
    ) if $row->{'region'};
    if ($data_type eq 'Gene') {
        $names = sprintf('<a href="/%s/geneview?gene=%s">%s</a>',
            $object->species, $row->{'label'}, $row->{'label'}) if $row->{'label'};
        $extname = $row->{'extname'}, 
        $desc =  $row->{'extra'}[0];
        $data_row = { 'loc' => $contig_link, 'extname' => $extname, 'names' => $names, };
    } 
    elsif ($data_type eq 'Disease') {
        $names = sprintf('<a href="http://www.ncbi.nlm.nih.gov/entrez/dispomim.cgi?id=%s">%s</a>',
          $row->{'label'}, $row->{'label'}) if $row->{'label'};
        $extname = $row->{'extname'}, 
        $desc =  $row->{'extra'}[0];
        $data_row = { 'loc' => $contig_link, 'extname' => $extname, 'names' => $names, };
    } 
    else {
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

sub unmapped {
  my( $panel, $object ) = @_;
  my( $data, $extra_columns, $initial_columns, $options ) = $object->retrieve_features;

  my $label = 'Location';
  my $name = $object->species_defs->SPECIES_COMMON_NAME;
  my $analysis = $$data[0]{'analysis'};
  my $html = qq(<p>This feature has not been mapped to the $name genome.</p><p>$analysis</p>);

  $panel->add_row($label, $html);
  return 1; 
}

sub unmapped_id {
  my( $panel, $object ) = @_;

  my $label = 'Feature ID';
  my $html = '<p>'.$object->feature_id.'</p>';

  $panel->add_row($label, $html);
  return 1; 
}

sub unmapped_reason {
  my( $panel, $object ) = @_;
  my( $data, $extra_columns, $initial_columns, $options ) = $object->retrieve_features;

  my $label   = 'Reason';
  my $reason  = $$data[0]{'reason'};
  my $score   = $$data[0]{'score'};
  my $html    = "<p>$reason (Target score $score%)</p>";

  $panel->add_row($label, $html);
  return 1; 
}

sub unmapped_details {
  my( $panel, $object ) = @_;

  my $label = '';
  my $html = '';

  #$panel->add_row($label, $html);
  return 1; 
}

#-----------------------------------------------------------------------------

sub key_to_pointers {
  my( $panel, $object ) = @_;
  # sanity check - does this species have chromosomes?
  my $SD = EnsEMBL::Web::SpeciesDefs->new();
  my $species = $object->species;
  my @chr = @{ $SD->get_config($species, 'ENSEMBL_CHROMOSOMES') || [] };

  if (@chr) { 
    my $html = "<h4>Key to data pointers</h4>\n<table>";
    my $i = 0;

    # configure pointer dimensions
    my $start = 1;
    my $end = 100;
    my $wid = 12;
    my $h_offset = 3;
    my $padding = 6;
    my $bpperpx = 1;
    my $zmenu = 'off';

    # draw each pointer and label it
    foreach my $ftype (keys %{$object->Obj}) {
        $html .= "<tr><td>";

        # image of pointer
        my $colour = $object->param("col_$i") || $pointer_defaults{$ftype}[0]; 
        my $style = $object->param("style_$i") || $pointer_defaults{$ftype}[1];
        my $details = {
                        'col'       => $colour, 
                        'style'     => $style,
                        'start'     => $start,
                        'end'       => $end,
                        'mid'       => ($start+$end)/2,
                        'h_offset'  => $h_offset,
                        'wid'       => $wid,
                        'padding'   => $padding,
                        'padding2'  => $padding * $bpperpx * sqrt(3)/2,
                        'zmenu'     => $zmenu,
        };
        my $wuc = $object->user_config_hash("key_$i", 'highlight');
        $wuc->container_width(25);
        my $image    = $object->new_image($details, $wuc);
        $image->cacheable  = 'no';
        $image->image_name = "pointer-$ftype";
        $html .= $image->render;

        $html .= "</td><td>$ftype</td></tr>\n";
        $i++;
    }
    $html .= "</table>\n\n";
    $panel->print($html);
  }
  return 1;

}

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
    
  #my $wuc = $object->get_userconfig( 'Vkaryotype' );
  my $image    = $object->new_karyotype_image();
  $image->cacheable  = 'no';
  $image->image_name = "feature-$species";
  $image->imagemap = 'yes';
    
  # configure the JS popup menus (aka 'zmenus')
  my $zmenu = $object->param('zmenu') || 'on';
  my $zmenu_config;
  my $data_type = $object->param('type');# eq 'Gene' ? 'gene' : 'feature';
  if ($zmenu eq 'on') {
    # simple zmenu configuration - add_pointers (see below) now does 
    # all the messy output :)
    if ($data_type eq 'Gene') {
        $zmenu_config = {
            'caption' => 'Genes',
            'entries' => ['label', 'contigview', 'geneview'],
        };
    }
    elsif ($data_type eq 'RegulatoryFactor' ){
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
  my @pointers = ();
  my $i = 0;
  foreach my $ftype (keys %{$object->Obj}) {
    my $pointer_ref = $image->add_pointers(
                            $object, 
                            {'config_name'  => 'Vkaryotype', 
                             'zmenu_config' => $zmenu_config,
                             'feature_type' => $ftype,
                             'color'        => $object->param("col_$i") 
                                            || $pointer_defaults{$ftype}[0],
                             'style'        => $object->param("style_$i") 
                                            || $pointer_defaults{$ftype}[1]}
    );
    push(@pointers, $pointer_ref);
    $i++;
  }
  $image->karyotype( $object, \@pointers, 'Vkaryotype' );

  return $image;
}     

sub genes {
  my( $panel, $object ) = @_;
  my $species = $object->species;
  $panel->add_columns( 
      {'key' => "id",   'title' => 'Ensembl ID', 'width' => '20%', 'align' => 'left' },
      {'key' => "name", 'title' => 'External name', 'width' => '20%', 'align' => 'left' },
      {'key' => "desc", 'title' => 'Description', 'width' => '60%', 'align' => 'left' },
  );

  my @genearray = $object->retrieve_features('Gene');
  my @genes = @{$genearray[0]};
  foreach my $gene (@genes) {
    my $stable_id = $gene->{'label'};
    my $id_link = qq(<a href="/$species/geneview?gene=$stable_id">$stable_id</a>);
    my $extname = $gene->{'extname'} || '-';
    my $desc = ${$gene->{'extra'}}[0] || '-';
    $panel->add_row(
      {'id'=>$id_link, 'name'=>$extname, 'desc'=>$desc}
    );
  }
}


sub regulatory_factor {
  my( $panel, $object ) = @_;
  my @features =  @{ $object->Obj->{'RegulatoryFactor'} };
  my %factors;

  foreach my $feature ( @features ) {  # unique-ify
    my $gene = $feature->{'coding_gene'} ? $feature->{'coding_gene'}->stable_id : "unknown";
    $factors{ $gene } = $feature->{'factor_name'};
  }

  foreach my $gene (keys %factors) {
    my $factor = $factors{$gene};
    my $gene_link = $gene;

    if ( $gene ne 'unknown') {
      $gene_link =  qq(<a href="geneview?gene=$gene">$gene</a>);
    }
    $gene_link .= " ($factor)" if (keys %factors) > 1;
    $panel->add_row("Product of gene", "$gene_link");
  }

  $panel->print("<p>The karyotype shows where this regulatory factor binds. The table below lists the regulatory features to which it binds.</p>");
  return 1;
}


1;
                                                 
__END__

=head1 Component::Feature

=head2 SYNOPSIS

This object is called from a Configuration object
                                                                                
    use EnsEMBL::Web::Component::Feature;

For each component to be displayed, you need to create an appropriate panel object and then add the component. The description of each component indicates the usual Panel subtype, e.g. Panel::Image.

    my $panel = new EnsEMBL::Web::Document::Panel::SpreadSheet(
        'code'    => "info$self->{flag}",
        'caption' => '',
        'object'  => $self->{object},
    );
    $panel->add_components( qw(features
      EnsEMBL::Web::Component::Feature::spreadsheet_featureTable));

=head2 DESCRIPTION

This class consists of methods for displaying miscellaneous feature data as XHTML. Current components include a karyotype with pointers indicating feature location, a spreadsheet with information about each feature, and a user input form to control the data being displayed.

=head2 METHODS

=head3 B<select_feature>

Description:    Wraps the select_feature_form (see below) in a DIV and passes the HTML back to the Panel::Image object for rendering

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        true

=head3 B<select_feature_form>

Description:    Creates a Form object and populates it with widgets for selecting data and configuring the karyotype image

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        Form object

=head3 B<spreadsheet_featureTable>

Description:    Adds columns and rows of feature data to a Panel::Spreadsheet object

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        true

=head3 B<key_to_pointers>

Description:    Creates a simple table of pointers and the feature type each one refers to, then passes the XHTML back to the parent Panel::Image for rendering

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        true

=head3 B<show_karyotype>

Description:    Checks if the chosen species has chromosomes, and if so, calls the create_karyotype method and passes it back to the parent Panel::Image for rendering

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        true

=head3 B<create_karyotype>

Description:    Creates and renders a karyotype image with location pointers

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        Document::Image

=head3 B<genes>

Description:     Adds columns and rows of gene data to a Panel::Spreadsheet object (make sure your Configuration module checks for the existence of Gene objects before calling this method!)

Arguments:      Document::Panel object, Proxy::Object (data)

Returns:        true


= head3 B<regulatory_factor>

Description:    Adds text describing the information on the page.  Adds Panel::Information for the gene that encodes this regulatory factor

=head2 BUGS AND LIMITATIONS

None known at present.                                                                               

=head2 AUTHOR

Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT

See http://www.ensembl.org/info/about/code_licence.html

=cut

