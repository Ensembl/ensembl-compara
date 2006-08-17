package EnsEMBL::Web::Configuration::Alignment;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Document::Panel::Information;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub alignview {
  my $self   = shift;
  my $class  = $self->{object}->class;
  my $fn  = "alignview_$class";
  if( $self->can( $fn ) ) {
    $self->$fn;
  }
}

sub _formats { return qw(FASTA MSF ClustalW Selex Pfam Mega Nexus Phylip PSI); } 

sub alignview_Family {
  my $self = shift;
  my $object = $self->{object};

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => qq(Alignments for Ensembl family @{[CGI::escapeHTML($object->param('family_stable_id'))]}),
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_Family
    ));
    $self->add_panel( $panel1 );
  }
  $self->add_block( "family", 'bulleted', $object->param('family_stable_id') );
  $self->add_entry(
    "family",
    'text' => 'Family Info',
    'href' => "/@{[$object->species]}/familyview?family=".$object->param('family_stable_id')
  );
  my $HREF = "/@{[$object->species]}/alignview?class=Family;family=".$object->param('family_stable_id');
  $self->add_entry(
    "family",
    'text' => 'Family Alignments',
    'href' => $HREF,
    'options' => [ map { {
      'href' => "$HREF;format=$_",
      'text' => "Export as $_ format"
    }} $self->_formats ]
  );
}


=head2 alignviewExternal

 Arg[1]      : none
 Example     : $self->alignviewExternal
 Description : Creates Information Panel for viewing alignments of supporting evidence
 Return type : Nothing

=cut

sub alignview_External {
	my $self   = shift;
	my $obj = $self->{'object'};
	my $data = $obj->__data;
	#get transcript W::P::O added in the Alignment Factory
	my $trans = $data->{'transcript'}->[0];

	$self->set_title("Alignment with external sequence");
	foreach my $detail ( $obj->Obj ) {
        my $panel = new EnsEMBL::Web::Document::Panel::Information(
									  'code'    => "info$self->{flag}",
			  						  'caption' => 'Alignments of exon and transcript with an external sequence',
									  'object'  => $trans,
								      'params'  => @{$detail},
									);
		$panel->add_components(qw(
								  stable_id       EnsEMBL::Web::Component::Gene::stable_id
								  information     EnsEMBL::Web::Component::Transcript::information
								  exon_info       EnsEMBL::Web::Component::Alignment::exon_information
								  external_info   EnsEMBL::Web::Component::Alignment::external_information
								  exon_alignment  EnsEMBL::Web::Component::Alignment::output_External_exon_al
								  trans_alignment EnsEMBL::Web::Component::Alignment::output_External_trans_al
								 ));
		$self->add_panel( $panel );
	}
}


sub alignview_Homology {
  my $self = shift;
  my $object = $self->{object};

  my $second_gene = $object->param('g1');
  my $caption = $second_gene ?
    qq(Homology for genes @{[CGI::escapeHTML($object->param('gene'))]} and @{[CGI::escapeHTML($second_gene)]}) :
    qq(Homologies for gene @{[CGI::escapeHTML($object->param('gene'))]});

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => $caption
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_Homology
    ));
    $self->add_panel( $panel1 );
  }
}


sub alignview_GeneTree {
  my $self = shift;
  my $object = $self->{object};

  my $caption =  qq(GeneTree for gene @{[CGI::escapeHTML($object->param('gene'))]});

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => $caption
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_GeneTree
    ));
    $self->add_panel( $panel1 );
  }
}


sub alignview_AlignSlice {
    my $self = shift;
    my $object = $self->{object};

    my $caption = sprintf("Alignment of Genomic location %s:%s:%ld-%ld", 
			  $ENV{ENSEMBL_SPECIES}, 
			  $object->param('chr'),
			  $object->param('bp_start'),
			  $object->param('bp_end'));

    if( my $panel1 = $self->new_panel( '',
				       'code'    => "info",
				       'caption' => $caption
				       )) {


	$self->add_form( $panel1,
			 qw(format EnsEMBL::Web::Component::Alignment::format_form)
			 );
	$panel1->add_components(qw(
				   format EnsEMBL::Web::Component::Alignment::format
				   output EnsEMBL::Web::Component::Alignment::output_AlignSlice
				   ));
	$self->add_panel( $panel1 );
    }
}

sub alignview_DnaDnaAlignFeature {
  my $self = shift;
  my $object = $self->{object};

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => qq(Dna-Dna alignment)
  )) {
    $panel1->add_components(qw(
      output EnsEMBL::Web::Component::Alignment::output_DnaDnaAlignFeature
    ));
    $self->add_panel( $panel1 );
  }
  my $align = $object->Obj->[0];
  my $context = 20e3;
  if( $align ) {
    my $sr = $align->seqname;
    my $cs = $align->slice->coord_system_name;
    my $rexp = "^$cs";
    (my $species = $align->species ) =~ s/ /_/g;
    my $label = sprintf "<em>%s</em> %s: %s - %s", $align->species,
      ( $sr =~ /$rexp/ ? $sr : ucfirst("$cs $sr") ), $object->thousandify( $align->start), $object->thousandify( $align->end );
    my $url   = sprintf "/%s/contigview?l=%s:%s-%s", $species, $sr, $align->start - $context, $align->end + $context;
    $self->add_block( 'primary', 'bulleted', $label, 'raw'=>1 );
    $self->add_entry( 'primary', 'text' => 'Graphical view', 'href' => $url );
    $url =~s/contigview/cytoview/g;
    $self->add_entry( 'primary', 'text' => 'Graphical overview', 'href' => $url );
    
    $sr =  $align->hseqname;
    $cs = $align->hslice->coord_system_name;
    (my $hspecies = $align->hspecies ) =~ s/ /_/g;
    $rexp = "^$cs";
    $label = sprintf "<em>%s</em> %s: %s - %s", $align->hspecies,
      ( $sr =~ /$rexp/ ? $sr : ucfirst("$cs $sr") ), $object->thousandify( $align->hstart), $object->thousandify( $align->hend );
    $url   = sprintf "/%s/contigview?l=%s:%s-%s", $hspecies, $sr, $align->hstart - $context, $align->hend + $context;
    $self->add_block( 'secondary', 'bulleted', $label,'raw'=>1 );
    $self->add_entry( 'secondary', 'text' => 'Graphical view', 'href' => $url );
    $url =~s/contigview/cytoview/g;
    $self->add_entry( 'secondary', 'text' => 'Graphical overview', 'href' => $url );
  }
}


=head2 context_Menu

 Arg[1]      : none
 Example     : $self->context_menu
 Description : Creates Context Menu for AlignView (external alignments only at present)
 Return type : Nothing

=cut

sub context_menu {
  my $self = shift;
  my $obj      = $self->{'object'};
  my $data = $obj->__data;
  my $trans;
  #only proceed for external alignment view
  return unless ($trans = $data->{'transcript'}->[0]);



  my $species  = $obj->species;
  my $script_name = $self->{page}->script_name; 
  my $script = lc($script_name);
  my $q_string_g = $trans->gene ? sprintf( "db=%s;gene=%s", $trans->get_db, $trans->gene->stable_id ) : undef;
  my $q_string   = sprintf( "db=%s;transcript=%s" , $trans->get_db , $trans->stable_id );

  my $flag     = "gene$self->{flag}";
  $self->add_block( $flag, 'bulleted', $trans->stable_id );

  #get other params needed for 'Jump to Vega alignview'
  my $data = $obj->__data;
  my @o =  $obj->Obj;
  my ($detail) = @{pop @o};
  my $exon_id = $detail->{'exon_id'};
  my $external_id = $detail->{'external_id'};
  my $trans_id = $trans->stable_id;

  if( $trans->get_db eq 'vega' ) {
    $self->add_entry( $flag,
      'code'  => 'vega_link',
      'text'  => "Jump to Vega",
      'icon'  => '/img/vegaicon.gif',
      'title' => 'Vega - Information about transcript '.$trans->stable_id." in Vega exonview",
      'href'  => "http://vega.sanger.ac.uk/$species/alignview?transcript=$trans_id;exon=$exon_id;sequence=$external_id;seq_type=N" );
  }

  $self->add_entry( $flag,
    'code' => 'gene_info',
    'text' => "Gene information",
    'href' => "/$species/geneview?$q_string_g"
  ) if $q_string_g;

  $self->add_entry( $flag,
    'code' => 'genomic_seq',
    'text' => "Genomic sequence",
    'href' => "/$species/geneseqview?$q_string_g"
  ) if $q_string_g;

  $self->add_entry( $flag,
    'code' => 'trans_info',
    'text' => "Transcript information",
    'href' => "/$species/transview?$q_string"
  );

  $self->add_entry( $flag,
    'code' => 'exon_info',
    'text' => "Exon information",
    'href' => "/$species/exonview?$q_string"
  );

  $self->add_entry( $flag,
    'code' => 'pep_info',
    'text' => 'Protein information',
    'href' => "/$species/protview?$q_string"
  ) if $trans->translation_object;

  $self->add_entry( $flag,
    'code' => 'exp_data',
    'text' => "Export transcript data",
    'href' => "/$species/exportview?type1=transcript;anchor1=@{[$trans->stable_id]}"
  );
}


1;
